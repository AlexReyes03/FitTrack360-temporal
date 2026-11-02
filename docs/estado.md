# Estado del proyecto — FitTrack360

> **Última actualización:** 2026-11-02 · **Actualizó:** Daniela Carrate
> Actualiza la fecha y tu nombre cada vez que edites. Describe solo lo que está en `main` o en un PR abierto; no adelantes avance.

## Qué hay

Integrado en `main`:

- Monorepo con pnpm, Husky (`pre-commit`, `commit-msg`, `pre-push`) y menú `pnpm dev`. La opción de levantar el API con Docker falla hoy (ver Blockers).
- API NestJS (`fit_track_api`): Prisma con usuarios y tokens, servicio Postgres en `docker-compose.yml`, `Dockerfile`, endpoints `POST /api/v1/auth/register` y `POST /api/v1/auth/login`.
- App Flutter (`fit_track_360`): pantallas de login y registro, `SessionStorage` con `flutter_secure_storage`, tokens de color del design system.
- Árbol de carpetas `core/` y `features/*` (W8-21).
- `AsyncState<T>` sealed con sus pruebas (W8-22). Todavía no lo usa ninguna pantalla.
- Banner offline con Reintentar (W8-23). Solo está conectado en el Home placeholder.
- Borrador de `docs/permisos.md` y plantillas de `docs/ia/bitacora.md` y este archivo (W8-24 y W8-25).

En PR abierto: esta actualización de documentos (#46).

## Qué falta

Según `docs/plans/plan-maestro-fittrack360.md`:

- [ ] F1 completo: logout, restaurar sesión, recuperar contraseña (y refresh de tokens en el API).
- [ ] Shell de la app: router, tema dark completo y conectar `AsyncState` (F6) y el banner offline (F7) a todas las pantallas que lo necesiten.
- [ ] F2 en adelante: workouts, meals, progreso, catálogo de ejercicios.
- [ ] Capacidades P1, P2, P3 y optativas O1, O5, O7, O10 (ver `docs/permisos.md`).
- [ ] Pruebas mínimas: 8 unitarias, 4 de widget y 1 de integración, con un solo comando.
- [ ] `docs/planeacion`, `docs/pruebas.md`, `docs/distribucion/`.

## Blockers

| Blocker | Impacto | Responsable | Desde |
| --- | --- | --- | --- |
| Destino en la nube sin decidir (ver sección Nube) | Bloquea uploads de P1 con acceso del dueño y el despliegue | Equipo / Alex (W8-15) | 27 oct 2026 |
| Modelo `Exercise` y `prisma/seed.ts` no están en `main`: #42–#45 se fusionaron en ramas intermedias, no en `main`, y #3–#6 ya están cerradas. Lo más reciente está en `feat/w8-04-exercise-seed` | Falta el seed de ejercicios; `main` tampoco tiene los otros cambios de esos PRs | Jafet / Alex | 2 nov 2026 |
| `docker-compose.yml` ya no tiene el servicio `api` (se quitó en #41; se espera en W8-07) y `pnpm dev` todavía ejecuta `docker compose up api`, que falla con `no such service: api` | No se puede levantar el API en Docker desde el menú ni con compose | Miguel (W8-07) | 2 nov 2026 |
| Credenciales de Postgres distintas: compose usa `fittrack_db` y otra contraseña por defecto; `.env.example` y `pnpm dev` usan base y contraseña `fittrack` | Con una base nueva creada por compose, el `DATABASE_URL` de ejemplo no debería conectar (por configuración; sin probar) | Por asignar | 2 nov 2026 |
| Puerto del API inconsistente: `src/main.ts` usa 3000 por defecto, el `Dockerfile` expone 3001 y la app apunta a `http://10.0.2.2:3000` | La app no conecta si el API corre en 3001 sin ajustar `API_BASE_URL` | Por asignar | 31 oct 2026 |
| Los tests de Jest del API no corren: error TS5011, falta `rootDir` en el `tsconfig` | Sin pruebas automáticas del API | Por asignar | 31 oct 2026 |

## Próximos pasos

| Paso | Responsable | Issue |
| --- | --- | --- |
| Llevar a `main` lo de #42–#45 con un PR desde `feat/w8-04-exercise-seed` | Jafet / Alex | #3–#6 |
| Recuperar el servicio `api` en compose y agregar Mailpit | Miguel | #8 |
| Unificar credenciales de Postgres y el puerto del API | Por asignar | Sin issue |
| Tokens, componentes base, theme y `env/example.json` | M4ltin | #17–#21 |
| Documentar criterios de nube | Alex | #16 |

## Nube (pendiente W8-15)

> Sección reservada para Alex (W8-15). No decidir proveedor aquí sin el acuerdo del equipo.

- **Proveedor elegido:** pendiente
- **Criterios (plan maestro):** HTTPS público, Postgres persistente, almacenamiento de fotos con acceso solo del dueño, costo cero o crédito estudiantil.
- **Opciones evaluadas:** pendiente
- **URL del API:** pendiente
- **Fecha de decisión:** pendiente
