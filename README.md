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
- Flutter; al iniciar pide elegir entre dispositivos físicos, emuladores encendidos y Chrome (web)
- PostgreSQL en Docker (puerto `5432`)
- Migraciones de Prisma (`migrate deploy`)
- API NestJS en Docker; la imagen se reconstruye en cada arranque

Teclas: flechas para moverte, Space para iniciar o detener, `R` para recargar estados y Esc para salir.

Con `W` el menú busca dispositivos por Wi-Fi usando `adb mdns`. Si el teléfono ya está vinculado, se conecta solo; si no, pide el código de 6 dígitos que muestra Depuración inalámbrica en el teléfono.

Al iniciar Flutter, el menú define `API_BASE_URL` con `adb reverse` para dispositivos Android o con `localhost` para Chrome. Si ejecutas `flutter run` a mano, pasa `--dart-define=API_BASE_URL=http://<host>:<puerto>`; el valor por defecto del código (`10.0.2.2:3000`) solo sirve para el emulador con la API en el puerto 3000.

Con `P` se abre Prisma Studio en `http://localhost:5555`, en su propia ventana, para editar tablas y registros desde el navegador. Requiere `fit_track_api/.env`.

El menú administra solo dispositivos Android mediante `adb`. Los dispositivos iOS requieren macOS y Xcode, así que no aparecen en el panel.

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
| P1 | Cámara/galería para foto de progreso o comida; compresión y subida a la nube con acceso restringido al dueño. | Pendiente de asignar |
| P2 | Ubicación en primer plano al cerrar un entrenamiento; alternativa de zona manual si el GPS está apagado. | Pendiente de asignar |
| P3 | Recordatorio local de entrenamiento o comida, con interruptor en Ajustes. | Pendiente de asignar |
| O1 | Desbloqueo con biometría o confirmación de acciones sensibles, con contraseña como alternativa. | Pendiente de asignar |
| O5 | Conteo de pasos del día en el resumen del Home. | Pendiente de asignar |
| O7+O10 | Contacto del sistema y hoja de compartir para enviar progreso o resumen. | Pendiente de asignar |

Se confirma en reunion de equipo.
