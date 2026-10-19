# FitTrack360

Monorepo del proyecto FitTrack360: app Flutter (`fit_track_360`) y API NestJS (`fit_track_api`).

**Audiencia:** integrantes del equipo de desarrollo.  
**Alcance de este README:** arranque local, instalación con pnpm y uso de Husky (hooks de Git). No documenta el dominio de negocio ni el design system (ver `fit_track_360/docs/`).

## Requisitos

- Git
- Node.js
- [pnpm](https://pnpm.io/installation) (gestor de paquetes del monorepo; versión alineada con `packageManager` en el `package.json` raíz)
- Flutter / Dart (para trabajar en `fit_track_360`)

Si no tienes pnpm:

```bash
corepack enable
corepack prepare pnpm@12.3.4 --activate
```

O instálalo con el método que prefieras de la documentación oficial de pnpm.

## Arranque del monorepo

Desde la **raíz** del repositorio (`FitTrack360/`):

```bash
pnpm install
```

Con un solo comando en la raíz ocurre lo siguiente:

1. Instala dependencias Node del workspace (raíz + `fit_track_api`).
2. Ejecuta `postinstall` → `dart pub get -C fit_track_360` (dependencias Flutter).
3. Ejecuta `prepare` → activa los hooks de Husky en `.husky/`.

Flutter/Dart debe estar en el `PATH`. Si falta, el `postinstall` falla y el install no queda completo.

Si solo necesitas reintentar el frontend:

```bash
pnpm run install:app
```

### Cómo verificar que Husky quedó activo

1. Existe la carpeta `.husky/` con `pre-commit`, `commit-msg` y `pre-push`.
2. Tras `pnpm install` en la raíz, un commit de prueba en una rama de trabajo dispara los mensajes de Husky (no uses `main` para esa prueba).

Si alguien solo instala dentro de `fit_track_api`, el script `prepare` del API intenta inicializar Husky desde la raíz. Lo recomendado sigue siendo `pnpm install` en la raíz del monorepo.

Este proyecto usa **pnpm**, no npm. No generes ni subas `package-lock.json`.

## Flujo de trabajo con Git

1. Trabaja en una rama distinta de `main` / `master` (`feat/...`, `fix/...`, `chore/...`, etc.).
2. Haz commit desde esa rama.
3. Abre un Pull Request hacia `main`.
4. Integra el PR (recomendado: Squash and merge) y borra la rama remota si aplica.

Los hooks **bloquean commits y pushes directos** a `main` y `master`. El camino correcto es rama + PR.

### Formato obligatorio del mensaje de commit

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

| Hook | Cuándo | Qué hace |
| --- | --- | --- |
| `pre-commit` | Al hacer `git commit` | Rechaza commit en `main`/`master`. Si hay cambios en `fit_track_360/`, corre `dart format` (check) y `dart analyze` (errores y warnings fatales). Si hay cambios en `fit_track_api/`, corre Prettier check, Oxlint con `--deny-warnings` y `tsc --noEmit`. |
| `commit-msg` | Al hacer `git commit` | Exige `type(scope): mensaje` con los tipos listados arriba. |
| `pre-push` | Al hacer `git push` | Rechaza push directo a `main`/`master`. |

### Comandos útiles (ejecutar a mano)

Desde la raíz del monorepo:

```bash
pnpm run format:check
pnpm run format
pnpm run lint
pnpm run typecheck:api
```

## Prohibido omitir los hooks

Está **prohibido** usar `git commit --no-verify`, `git push --no-verify` u otras formas de saltarse los hooks de Husky.

Esas flags desactivan las validaciones de formato, lint, tipos, rama protegida y mensaje de commit. En este proyecto no son una vía válida de trabajo: si el hook falla, corrige el problema indicado en el mensaje de error y vuelve a intentar.

## Límites

- Este README no sustituye la documentación de Flutter ni de NestJS.
- El design system del frontend está en `fit_track_360/docs/design-system.md`.
- Los assets de ejercicios viven bajo `fit_track_api/public/exercises/` y el catálogo slim en `fit_track_api/seed/`.
