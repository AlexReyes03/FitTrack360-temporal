# FitTrack360

Plataforma móvil para el seguimiento de entrenamiento físico, rutinas y catálogo de ejercicios. El monorepo integra la aplicación móvil y el backend; este README cubre el arranque local, los hooks de Git y el flujo de trabajo del equipo:

- `fit_track_360/`: aplicación móvil en Flutter. El sistema de diseño está documentado en `fit_track_360/docs/design-system.md`.
- `fit_track_api/`: API REST en NestJS con Prisma y PostgreSQL. Los assets de ejercicios se encuentran en `fit_track_api/public/exercises/` y el catálogo base en `fit_track_api/seed/`.

## Requisitos

- Git
- Node.js
- [pnpm](https://pnpm.io/installation) (la versión está fijada en el campo `packageManager` de `package.json`)
- Flutter y Dart en el `PATH`
- Docker (para levantar PostgreSQL y la API desde el menú de desarrollo)

Si utilizas Corepack, habilítalo para que use automáticamente la versión de pnpm fijada en `package.json`:

```bash
corepack enable
```

## Arranque

Desde la raíz del repositorio:

```bash
pnpm install
```

Este comando instala las dependencias de Node.js del workspace, descarga los paquetes de Flutter (`dart pub get` en `fit_track_360`) y activa los hooks de Git en `.husky/`.

Antes de levantar los servicios, copia `fit_track_api/.env.example` a `fit_track_api/.env`. El `DATABASE_URL` de ejemplo ya coincide con el contenedor de PostgreSQL que crea el menú. Sin ese archivo, el menú no aplica las migraciones de Prisma ni arranca la API.

Si necesitas reinstalar únicamente las dependencias de Flutter:

```bash
pnpm run install:app
```

## Desarrollo

Desde la raíz del repositorio:

```bash
pnpm dev
```

El comando ejecuta `pnpm install` y después abre un menú interactivo para iniciar o detener, en este orden:

- Dispositivos; lista primero los dispositivos físicos conectados por `adb` (USB o Wi-Fi) y después los AVD creados. Requiere el SDK de Android con `ANDROID_HOME` o `ANDROID_SDK_ROOT`
- iOS (solo en macOS); lista los simuladores de Xcode para encenderlos o apagarlos
- Flutter; al iniciar pide elegir entre dispositivos Android, simuladores iOS encendidos, iPhone conectados y Chrome (web)
- PostgreSQL en Docker (puerto `5432`)
- Migraciones de Prisma (`migrate deploy`)
- API NestJS en Docker; la imagen se reconstruye en cada arranque

Teclas: flechas para moverte, Space para iniciar o detener, `R` para recargar estados y Esc para salir.

Con `W` el menú busca dispositivos por Wi-Fi usando `adb mdns`. Si el teléfono ya está vinculado, se conecta solo; si no, pide el código de 6 dígitos que muestra Depuración inalámbrica en el teléfono.

Al iniciar Flutter, el menú define `API_BASE_URL` con `adb reverse` para dispositivos Android o con `localhost` para Chrome. Si ejecutas `flutter run` a mano, pasa `--dart-define=API_BASE_URL=http://<host>:<puerto>`; el valor por defecto del código (`10.0.2.2:3000`) solo sirve para el emulador con la API en el puerto 3000.

En dispositivos Android, el menú sube el tiempo de apagado de pantalla a 30 minutos mientras Flutter está activo y lo restaura al detenerlo o al salir. Sin eso, cuando el teléfono entra en reposo se pierde la conexión del servicio de Dart y `flutter run` termina con `Lost connection to device.`, aunque la app siga instalada.

Con `P` se abre Prisma Studio en `http://localhost:5555` para editar tablas y registros desde el navegador. Requiere `fit_track_api/.env`.

En Windows, Flutter y Prisma Studio se abren en Windows Terminal si está instalado: el primer proceso crea la ventana y los siguientes agregan una pestaña en esa misma ventana. Si no está instalado, se usa la consola clásica con una ventana por proceso.

En macOS, Flutter se abre en Terminal.app y Prisma Studio también.

### macOS e iOS

La fila `iOS` aparece solo en macOS. Si Xcode no está instalado muestra `Sin Xcode` y no abre el submenú. Dentro del submenú, Space enciende o apaga el simulador seleccionado y abre la app Simulator para que se vea la ventana; `R` recarga la lista y Esc vuelve al menú.

Al iniciar Flutter en iOS, el menú no usa `adb reverse` y define `API_BASE_URL` según el destino:

- Simulador iOS: `http://127.0.0.1:<puerto>`, porque comparte la red de la Mac.
- iPhone físico: `http://<IP LAN de la Mac>:<puerto>`, porque en el teléfono `127.0.0.1` es el propio teléfono. Antes de lanzar, el menú comprueba que el API responda en esa IP.

Para el iPhone físico, la Mac y el teléfono deben estar en la misma red Wi-Fi y el firewall de macOS debe permitir conexiones entrantes al puerto del API (Ajustes del Sistema > Red > Firewall). Si el registro falla solo en el teléfono, revisa eso primero.

Requisitos en la Mac para iOS:

- Xcode 15 o superior con sus Command Line Tools (`xcode-select --install`).
- CocoaPods (`brew install cocoapods`).
- En el iPhone, Modo Desarrollador activo y la Mac marcada como confiable.
- Un equipo de firma configurado en `fit_track_360/ios/Runner.xcworkspace` (Signing & Capabilities) para poder instalar en el iPhone.

## Flujo de trabajo con Git

1. Crea una rama a partir de `main` (`feat/...`, `fix/...`, `chore/...`).
2. Realiza tus commits en esa rama.
3. Abre un Pull Request hacia `main`.

### Formato del mensaje de commit

```text
<type>(<scope>): <mensaje>
```

Tipos permitidos: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

Ejemplos:

```text
feat(mobile): implementar pantalla de historial de rutinas
fix(api): validar campos requeridos en el endpoint de ejercicios
chore(repo): actualizar scripts de lint del monorepo
```

### Pull Requests

- El **título del PR** debe usar el mismo formato que los commits: `<type>(<scope>): <mensaje>`. Así, con squash and merge, el historial de `main` queda limpio y consistente.
- En la descripción del PR incluye siempre `Closes #<número_issue>` para que GitHub cierre el issue al mergear.

## Qué validan los hooks

No utilices `--no-verify` en `git commit` ni en `git push`; si un hook falla, corrige el error reportado antes de reintentar.

| Hook | Cuándo | Qué hace |
| --- | --- | --- |
| `pre-commit` | Al hacer `git commit` | Bloquea commits directos en `main`/`master`. Si hay cambios en `fit_track_360/`, ejecuta `dart format` (check) y `dart analyze --fatal-infos --fatal-warnings`. Si hay cambios en `fit_track_api/`, ejecuta Prettier (check), Oxlint (`--deny-warnings`) y `tsc --noEmit`. |
| `commit-msg` | Al hacer `git commit` | Valida el formato `<type>(<scope>): <mensaje>` con al menos 3 caracteres descriptivos. |
| `pre-push` | Al hacer `git push` | Bloquea pushes directos a `main`/`master`. |

### Comandos de verificación y formato

Desde la raíz del monorepo puedes ejecutar manualmente las mismas validaciones de los hooks:

```bash
# Todo el monorepo
pnpm run format:check
pnpm run format
pnpm run lint

# Solo Flutter (fit_track_360)
pnpm run format:check:app
pnpm run format:app
pnpm run lint:app

# Solo API (fit_track_api)
pnpm run format:check:api
pnpm run format:api
pnpm run lint:api
pnpm run typecheck:api
```

## Responsables por capacidad

| Capacidad | Descripción corta | Responsable |
| --- | --- | --- |
| P1 | Cámara/galería para foto de progreso o comida; compresión y subida a la nube con acceso restringido al dueño. | `@M4ltin12` |
| P2 | Ubicación en primer plano al cerrar un entrenamiento; alternativa de zona manual si el GPS está apagado. | `@MiguelSP040` |
| P3 | Recordatorio local de entrenamiento o comida, con interruptor en Ajustes. | `@danielita05` |
| O1 | Desbloqueo con biometría o confirmación de acciones sensibles, con contraseña como alternativa. | `@AlexReyes03` |
| O5 | Conteo de pasos del día en el resumen del Home. | `@M4ltin12` |
| O7+O10 | Contacto del sistema y hoja de compartir para enviar progreso o resumen. | `@Loreley100` |
