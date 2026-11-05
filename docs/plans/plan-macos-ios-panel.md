# Instrucciones para implementar el panel en macOS e iOS

## Para quién es este documento

Este documento es el brief de implementación para el agente de Claude que trabaja en la Mac de la integrante del equipo, y también la guía de prueba para ella. El repositorio ya está clonado en su equipo y el panel de Windows está terminado y probado. Falta que la versión de macOS quede igual y que se agregue el soporte de iOS.

El agente implementa. La integrante prueba el TUI y reporta resultados. El desarrollador de Windows no hará cambios adicionales al panel, así que todo lo necesario está aquí.

## Bootstrap del ejecutor

1. Lee este archivo completo antes de tocar código.
2. Abre [`scripts/dev-menu.mjs`](scripts/dev-menu.mjs) y ubica los símbolos por nombre. Los números de línea de este documento son pistas y pueden haberse movido.
3. Trabaja en una rama `feat/macos-ios-panel` y haz commits con el formato del repositorio. Los hooks bloquean commits y pushes a `main`; no uses `--no-verify`.
4. Después de cada cambio ejecuta `node --check scripts/dev-menu.mjs`.
5. No puedes probar el TUI de forma automática. Después de cada fase pide a la integrante que ejecute la lista de prueba de este documento y espera su reporte antes de seguir.

## Punto de partida

El panel es un solo archivo ESM sin dependencias externas, [`scripts/dev-menu.mjs`](scripts/dev-menu.mjs), que se abre con `pnpm dev`. `pnpm dev` ejecuta `pnpm install` y luego el menú interactivo.

Ya funciona en Windows y no debe romperse:

- Filas: `Dispositivos`, `Flutter`, `Postgres (Docker)`, `Prisma`, `API Nest (Docker)`.
- Teclas: flechas, Space para iniciar o detener, `R` para recargar, `W` para buscar dispositivos Android por Wi-Fi, `P` para abrir Prisma Studio, Esc para salir.
- Detección de Docker caído, mensajes de dependencia de Postgres y reconstrucción de la imagen de la API en cada arranque.
- Flutter recibe `API_BASE_URL` por `--dart-define`: con `adb reverse` en Android y `localhost` en Chrome. Esto es lo que hace que el registro y el login lleguen al API.
- Prisma Studio se abre con `P` en `http://localhost:5555`.

Ya está aplicado en el repositorio, no lo reimplementes:

- [`resolveSdk()`](scripts/dev-menu.mjs) busca `~/Library/Android/sdk` en macOS y `~/Android/Sdk` en Linux.
- [`openWindow()`](scripts/dev-menu.mjs) en macOS abre Terminal.app con `osascript` y ejecuta el comando en el directorio correcto.
- [`openUrl()`](scripts/dev-menu.mjs) usa `open` en macOS y `xdg-open` en Linux.
- [`prepareFlutterApiUrl()`](scripts/dev-menu.mjs) resuelve la URL del API para Android y Chrome.
- [`matchesFlutter()`](scripts/dev-menu.mjs) y [`FLUTTER_PS`](scripts/dev-menu.mjs) detectan sesiones de `flutter run` por `flutter_tools.snapshot run`.

## Reglas de trabajo para el agente

- Cambia solo [`scripts/dev-menu.mjs`](scripts/dev-menu.mjs) y el [`README.md`](README.md). No toques la app Flutter ni el API.
- No agregues dependencias de npm. Usa `node:child_process`, `node:fs`, `node:os` y lo que ya importa el archivo.
- Conserva el estilo actual: funciones pequeñas, `runArgs` y `runLine` para comandos, `setMessage` más `draw()` para avisos, `beginRow` y `startPoll` para estados con espera.
- No reescribas el TUI ni cambies el formato de las filas.
- No modifiques las ramas de Windows salvo que sea imprescindible. Si un cambio es compartido, revisa que `IS_WINDOWS` siga cubriendo su caso.
- No implementes emparejamiento por QR.
- No intentes portar `adb` a iOS.
- No cambies puertos ni la configuración de Docker.
- Sin guion largo ni punto medio en textos nuevos.

## Arquitectura actual que debes respetar

- [`ROWS`](scripts/dev-menu.mjs) define las filas del menú principal. Cada fila tiene `id`, `label` y `read`.
- [`stateMap`](scripts/dev-menu.mjs) guarda el último estado leído de cada fila.
- [`draw()`](scripts/dev-menu.mjs) dibuja según `mode`: `main`, `devices`, `pairing` o `flutter-target`.
- [`onKeypress()`](scripts/dev-menu.mjs) maneja las teclas y los modos.
- [`refreshAll()`](scripts/dev-menu.mjs) recorre `ROWS`; omite la fila `devices` mientras estás dentro de ese submenú y omite filas con un poll activo.
- [`startPoll()`](scripts/dev-menu.mjs) espera a que una condición se cumpla y actualiza la fila mientras tanto.
- [`loadDevices()`](scripts/dev-menu.mjs) devuelve `{ sdk, avds, running, physical }`.
- [`buildFlutterTargets()`](scripts/dev-menu.mjs) arma la lista de destinos de Flutter con `label` y `deviceId`.
- [`prepareFlutterApiUrl()`](scripts/dev-menu.mjs) recibe un destino y devuelve la URL del API o `null` si no puede prepararla.
- [`openWindow()`](scripts/dev-menu.mjs) abre una terminal nueva y ejecuta un comando. En macOS usa Terminal.app.

## Fase 1: verificar macOS con Android

No escribas código nuevo todavía. Primero confirma que lo que ya existe funciona en su Mac.

Pide a la integrante que ejecute:

```bash
node --version
pnpm --version
flutter --version
flutter doctor -v
adb devices
xcrun simctl list devices available
pnpm dev
```

Y que compruebe:

1. La fila `Dispositivos` lista los AVD de Android Studio.
2. Encender y apagar un AVD funciona.
3. `W` detecta un Android por Wi-Fi y lo vincula.
4. Flutter abre Terminal.app y la app alcanza el API: crear cuenta y luego iniciar sesión.
5. `P` abre Prisma Studio en el navegador.
6. `R` refresca sin reiniciar el menú.

Si algo falla, corrige solo ese punto y vuelve a pedir la prueba. Criterio de listo: los seis puntos pasan.

## Fase 2: fila iOS con simuladores

Objetivo: listar simuladores, encenderlos y apagarlos desde el panel.

Diseño cerrado:

- Nueva fila `iOS` en `ROWS`, solo cuando `process.platform === 'darwin'`.
- Submenú con el mismo patrón que `Dispositivos`: flechas, Space para encender o apagar, Esc para volver, `R` para recargar.
- Si `xcrun` no existe o Xcode no está instalado, la fila muestra `Sin Xcode` y no entra al submenú.
- El estado de cada simulador sale de `simctl`: `Booted` o `Shutdown`.
- Al encender, ejecuta `open -a Simulator` para que se vea la ventana.

Estado y lectura:

```js
let iosSimulators = [];
let iosSelected = 0;
```

```js
async function readIosSimulators() {
  const result = await runArgs('xcrun', ['simctl', 'list', 'devices', 'available', '--json'], {
    timeout: 20000,
  });
  if (result.code !== 0) {
    return [];
  }
  const parsed = JSON.parse(result.stdout);
  const simulators = [];
  for (const [runtime, list] of Object.entries(parsed.devices ?? {})) {
    if (!runtime.includes('iOS')) {
      continue;
    }
    for (const device of list) {
      simulators.push({
        runtime,
        name: device.name,
        udid: device.udid,
        state: device.state,
      });
    }
  }
  return simulators;
}
```

Resumen de la fila:

```js
async function readIosSummary() {
  if (!hasXcrun()) {
    return { level: 'warn', text: 'Sin Xcode' };
  }
  iosSimulators = await readIosSimulators();
  if (iosSimulators.some((simulator) => simulator.state === 'Booted')) {
    return { level: 'ok', text: 'Iniciado' };
  }
  if (iosSimulators.length === 0) {
    return { level: 'off', text: 'Sin simuladores' };
  }
  return { level: 'warn', text: 'Detenido' };
}
```

Usa `runArgs('xcrun', ['--find', 'simctl'])` una sola vez y cachea el resultado para `hasXcrun()`.

Encender y apagar:

```js
async function actIosRow() {
  const simulator = iosSimulators[iosSelected];
  if (!simulator) {
    return;
  }
  const booted = simulator.state === 'Booted';
  setMessage(`${booted ? 'Apagando' : 'Encendiendo'} ${simulator.name}...`);
  draw();
  const result = await runArgs(
    'xcrun',
    ['simctl', booted ? 'shutdown' : 'boot', simulator.udid],
    { timeout: 120000 },
  );
  if (result.code !== 0) {
    setMessage(firstLine(result.stderr) || firstLine(result.stdout) || 'Falló simctl.');
    draw();
    return;
  }
  if (!booted) {
    await runArgs('open', ['-a', 'Simulator']);
  }
  await waitIosState(simulator.udid, booted ? 'Shutdown' : 'Booted');
  await refreshIos();
}
```

`waitIosState` sondea `readIosSimulators()` cada segundo hasta 90 segundos y busca el estado esperado. `refreshIos()` vuelve a leer la lista y redibuja.

Integración en el menú:

- Agrega la fila condicional a `ROWS`:

```js
...(process.platform === 'darwin'
  ? [{ id: 'ios', label: 'iOS', read: readIosSummary }]
  : []),
```

- Agrega `ios: { ...PENDING }` a `stateMap` siempre. `ROWS` decide si la fila se dibuja en macOS.
- En `draw()`, agrega la rama `mode === 'ios'` con el mismo formato que `devices`.
- En `onKeypress()`, agrega el manejo del modo `ios` antes del bloque de `devices`.
- En `act()`, agrega el despacho `row.id === 'ios'` hacia `actIos()`.
- No agregues teclas nuevas al `FOOTER`.

Criterio de listo: la fila `iOS` aparece en la Mac, enciende y apaga simuladores, y `R` refresca la lista.

## Fase 3: destinos de Flutter para iOS

Objetivo: poder elegir un simulador encendido o un iPhone conectado al iniciar Flutter.

Detección de dispositivos iOS con `flutter devices --machine`, que devuelve JSON y no depende de la versión de Xcode:

```js
async function flutterDevices() {
  const result = await runArgs('flutter', ['devices', '--machine'], {
    timeout: 30000,
    cwd: FLUTTER_DIR,
  });
  if (result.code !== 0) {
    return [];
  }
  try {
    return JSON.parse(result.stdout);
  } catch {
    return [];
  }
}
```

En `buildFlutterTargets()`:

- Conserva los destinos Android actuales.
- Agrega los simuladores con `state === 'Booted'` como `{ label: '<nombre> (<udid>)', deviceId: udid, platform: 'ios', simulator: true }`.
- Agrega los iPhone físicos que devuelve `flutter devices --machine` cuyo `targetPlatform` empiece con `ios` y `emulator` sea `false`, como `{ label: '<nombre> (<id>)', deviceId: id, platform: 'ios', simulator: false }`.
- No dupliques un dispositivo que ya venga por `simctl`; compara por `udid` o `id`.

URL del API por plataforma en `prepareFlutterApiUrl()`:

- Chrome: `http://localhost:<puerto>`.
- Simulador iOS: `http://127.0.0.1:<puerto>`, porque comparte red con la Mac.
- iPhone físico: la IP LAN de la Mac, porque `127.0.0.1` en el teléfono es el teléfono.

Helper de IP LAN:

```js
function localIpv4() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const entries of Object.values(interfaces)) {
    for (const entry of entries ?? []) {
      if (entry.family === 'IPv4' && !entry.internal) {
        addresses.push(entry.address);
      }
    }
  }
  return addresses.find((address) => address.startsWith('192.168.'))
    ?? addresses.find((address) => address.startsWith('10.'))
    ?? addresses[0]
    ?? null;
}
```

Para iPhone físico, antes de lanzar, verifica que la URL sea alcanzable. Si `localIpv4()` devuelve `null`, muestra `No se encontró una IP LAN` y no lances Flutter.

En `launchFlutterTarget()`, si el destino es iOS, no ejecutes `adb reverse`. El comando queda:

```bash
flutter run -d <udid> --dart-define=API_BASE_URL=http://<host>:<puerto>
```

Requisitos previos que la integrante debe cumplir en la Mac:

- Xcode 15 o superior con Command Line Tools.
- CocoaPods instalado.
- iPhone con Modo Desarrollador activo y la Mac marcada como confiable.
- Equipo de firma configurado en el proyecto de Flutter para poder instalar en el iPhone.

Criterio de listo: Flutter arranca en un simulador y en el iPhone, y en ambos se puede crear cuenta e iniciar sesión contra el API.

## Fase 4: README

Agrega en [`README.md`](README.md), en la sección de Desarrollo:

- Que en macOS la fila `iOS` aparece solo si Xcode está instalado.
- Que el simulador usa `127.0.0.1` y el iPhone físico usa la IP LAN de la Mac.
- Que en iPhone físico la Mac y el teléfono deben estar en la misma red y el firewall debe permitir la entrada al puerto del API.
- Los requisitos de Xcode, CocoaPods, Modo Desarrollador y firma.

## Protocolo de prueba para la integrante

Después de cada fase, pide este reporte. Sin este reporte no avances.

1. Ejecuta `pnpm dev` y anota la versión de macOS, `node --version`, `flutter --version` y `xcodebuild -version`.
2. Recorre las filas del menú y anota el texto exacto que muestra cada una.
3. Prueba en este orden y reporta `esperado` contra `obtenido`:

| Prueba | Esperado |
| --- | --- |
| Abrir Dispositivos | Lista AVD y dispositivos Android conectados |
| Encender y apagar un AVD | Cambia de `Iniciando...` a `Iniciado` y vuelve a `No iniciado` |
| `W` con un Android por Wi-Fi | Se conecta y aparece en Dispositivos |
| `P` | Abre Prisma Studio en `http://localhost:5555` |
| Flutter en Android | Abre Terminal.app y el registro llega al API |
| Fila iOS | Aparece y muestra `Iniciado`, `Detenido` o `Sin Xcode` |
| Encender un simulador | Cambia a `Iniciado` y se abre la ventana del simulador |
| Flutter en simulador | Arranca la app y el registro llega al API |
| Flutter en iPhone | Arranca la app y el registro llega al API |
| `R` en cualquier modo | Refresca sin cerrar el panel |
| Esc | Cierra el panel sin apagar servicios ni simuladores |

1. Si algo falla, adjunta la salida del comando que falla y una captura del panel.

Formato de reporte sugerido:

```text
Fase: 2
macOS: 15.x
Resultado: 8 de 10 pruebas pasan
Falla 1: encender simulador
Esperado: Iniciado
Obtenido: Detenido después de 90 s
Comando: xcrun simctl boot <udid>
Salida: <texto>
```

## Criterio de paridad terminado

La implementación está completa cuando, en la Mac:

- Las cinco filas originales se comportan igual que en Windows.
- `Dispositivos`, `Flutter`, `Postgres`, `Prisma`, `API Nest`, `W`, `R` y `P` funcionan.
- La fila `iOS` lista, enciende y apaga simuladores.
- Flutter permite elegir Android, simulador iOS, iPhone físico y Chrome.
- El registro y el login funcionan en Android, simulador iOS e iPhone físico.
- El README describe el flujo de macOS e iOS.

## Riesgos y límites

- La firma y el aprovisionamiento del iPhone son la causa más común de fallos y no dependen del panel.
- `flutter devices --machine` tarda entre dos y cuatro segundos. Llámalo solo al abrir el selector de Flutter, nunca en un poll de cada segundo.
- El firewall de macOS puede bloquear el puerto del API para el iPhone. Si el registro falla solo en el teléfono, revisa eso primero.
- Las rutas con espacios ya están citadas en `openWindow()`; no las vuelvas a citar.
- No se puede validar macOS ni iOS desde Windows. Toda la verificación depende del reporte de la integrante.

## No hacer

- No implementar emparejamiento por QR.
- No agregar dependencias de npm.
- No cambiar la app Flutter ni el API.
- No reescribir el TUI ni cambiar el orden de las filas existentes.
- No tocar los scripts de Windows ni los hooks.
- No hacer commit a `main` ni usar `--no-verify`.
