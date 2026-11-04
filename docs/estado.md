# Estado del proyecto — FitTrack360

> **Última actualización:** 2026-11-03 · **Actualizó:** AlexReyes03 (W8-15 Nube / hosting; base previa Daniela Carrate)
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

En PR abierto: ver la lista de PRs del repositorio (incluye esta actualización de Nube / hosting cuando se abra).

## Qué falta

Según `docs/plans/plan-maestro-fittrack360.md`:

- [ ] F1 completo: logout, restaurar sesión, recuperar contraseña (y refresh de tokens en el API).
- [ ] Shell de la app: router, tema dark completo y conectar `AsyncState` (F6) y el banner offline (F7) a todas las pantallas que lo necesiten.
- [ ] F2 en adelante: workouts, meals, progreso, catálogo de ejercicios.
- [ ] Capacidades P1, P2, P3 y optativas O1, O5, O7, O10 (ver `docs/permisos.md`).
- [ ] Pruebas mínimas: 8 unitarias, 4 de widget y 1 de integración, con un solo comando.
- [ ] `docs/planeacion`, `docs/pruebas.md`, `docs/distribucion/`.

## Checklist H2 — F1 + P1

> **Corte:** 2026-11-03. **Origen:** inspección estática del repositorio, sin ejecución E2E de la app contra el API y la base de datos. Los estados son provisionales.
>
> **Alcance:** H2 es el hito académico de UTEZ; este checklist no es una demostración comercial ni un guion de presentación.

Este checklist no implementa F1 ni P1, no sustituye la demostración oral y no modifica `docs/permisos.md`.

Regla aplicada: `pendiente` = sin implementación o sin evidencia suficiente; `en progreso` = implementación parcial o trabajo comprobable, sin verificación de extremo a extremo; `hecho` = evidencia suficiente de funcionamiento conforme al requisito. Una pantalla, archivo o endpoint por sí solo no basta para marcar `hecho`.

| Bloque | Requisitos | Hechos | En progreso | Pendientes |
| --- | ---: | ---: | ---: | ---: |
| F1 — Autenticación y sesión | 5 | 0 | 5 | 0 |
| P1 — Fotografía y almacenamiento | 3 | 0 | 1 | 2 |
| **Total** | **8** | **0** | **6** | **2** |

### F1 — Autenticación y sesión

| Requisito | Estado | Observación y evidencia |
| --- | --- | --- |
| Registro remoto | `en progreso` | La app envía `POST /api/v1/auth/register` desde `register_page.dart` mediante `register()` en `auth_api.dart`; el API valida el DTO, guarda el usuario con Prisma, registra `privacyConsentAt` y `privacyNoticeVersion`, y emite tokens (`auth.controller.ts`, `auth.service.ts`). Falta una prueba de extremo a extremo con API y base de datos reales. |
| Login | `en progreso` | `login_page.dart` llama `login()` y guarda los tokens en `SessionStorage` con `flutter_secure_storage`. El API verifica la contraseña con Argon2 y emite JWT; `GET /users/me` alimenta el shell autenticado. Falta comprobar en ejecución el acceso con credenciales válidas y el rechazo con credenciales incorrectas. |
| Logout | `en progreso` | `home_shell_page.dart` revoca el refresh token con `POST /api/v1/auth/logout`, limpia `SessionStorage` en un bloque `finally` y navega a `/login`. El API marca el refresh como revocado. Falta comprobar en ejecución que el token revocado ya no permite renovar la sesión. |
| Restauración de sesión al reabrir | `en progreso` | `splash_page.dart` lee el access token y decide entre `/app` y `/login`; `router.dart` redirige según la presencia del token. `ApiClient` intenta refrescar una vez ante un 401 y limpia la sesión si el refresh falla. Falta probar cierre y reapertura con una sesión válida y con una sesión vencida. |
| Recuperación de contraseña | `en progreso` | `forgot_password_page.dart` y `reset_password_page.dart` consumen `POST /api/v1/auth/password/forgot` y `POST /api/v1/auth/password/reset`. El API genera un código de 6 dígitos, lo guarda hasheado con TTL de 15 minutos, invalida los refresh tokens y responde igual aunque el correo no exista. `MailService` envía por SMTP; si SMTP no está configurado, el flujo responde 200 sin enviar correo. Mailpit aún no está en `fit_track_api/docker-compose.yml` (W8-07), por lo que la recepción real del correo no está verificada. |

### P1 — Fotografía y almacenamiento protegido

| Requisito | Estado | Observación y evidencia |
| --- | --- | --- |
| Capturar o elegir una fotografía | `pendiente` | `fit_track_360/pubspec.yaml` no incluye `image_picker` ni otro selector de cámara o galería. `fit_track_360/lib/features/progress/` solo contiene `README.md` y carpetas vacías; no hay pantalla ni servicio de captura o selección de fotos. |
| Comprimir la fotografía antes de subirla | `pendiente` | No hay dependencia cliente de compresión de imágenes ni uso de `imageQuality` o redimensionado antes de subir. El backend tampoco incluye `sharp`; `storage.service.ts` escribe el buffer tal como llega. No existe compresión previa a la transmisión. |
| Subir la imagen a la nube con acceso restringido a su propietario | `en progreso` | `StorageController` expone `POST`, `GET` y `DELETE /api/v1/storage/files` protegidos con `JwtAuthGuard`. `StorageService` guarda en `UPLOAD_DIR/<userId>/` y solo resuelve lecturas para el mismo `userId`; un id ajeno responde 404. Es un avance parcial de subida y aislamiento, pero **no es nube**: usa disco local, no hay proveedor de objetos ni ACL del proveedor, y aún no está integrado con fotos de progreso o comidas. Tampoco hay prueba entre dos cuentas. |

### Evidencia consultada

- `docs/plans/plan-maestro-fittrack360.md`: criterios de F1 y P1, fases de recuperación H2 y trazabilidad (secciones 6.1 y 10).
- `docs/estado.md`: bloqueos conocidos de nube, API en Compose, SMTP/Mailpit y pruebas.
- `docs/permisos.md`: alcance de P1, compresión, almacenamiento con acceso del dueño y evidencia pendiente en dispositivo físico.
- `fit_track_360/lib/features/auth/`, `fit_track_360/lib/app/router.dart`, `fit_track_360/lib/core/network/api_client.dart` y `fit_track_360/lib/features/home/presentation/home_shell_page.dart`.
- `fit_track_api/src/auth/`, `fit_track_api/src/users/`, `fit_track_api/src/storage/` y `fit_track_api/src/mail/`.
- `fit_track_360/pubspec.yaml`, `fit_track_api/package.json`, `fit_track_api/.env.example` y `fit_track_api/docker-compose.yml`.

### Revisión de cierre de semana

| Campo | Registro |
| --- | --- |
| Fecha del corte | 2026-11-03 |
| Tipo de evidencia | Inspección estática; no se ejecutó la app contra el API ni una prueba E2E. |
| Responsable de actualizar estados | Por asignar |
| Próxima revisión | Cierre de semana, con evidencia de ejecución y bloqueos actualizados. |

**Bloqueos y riesgos confirmados**

- El destino de nube sigue sin decidir; esto bloquea el criterio de P1 de subir a la nube con acceso restringido al dueño.
- Mailpit no está en `fit_track_api/docker-compose.yml`; sin SMTP configurado, la recuperación responde 200 pero no envía el código.
- No hay pruebas automatizadas de autenticación ni de P1. Las pruebas existentes del API solo cubren el endpoint raíz y la app solo tiene pruebas de `AsyncState` y del banner offline.
- P1 no tiene selector de cámara/galería ni compresión cliente; no puede demostrarse todavía.
- El almacenamiento actual es local y no sustituye el requisito de nube ni una ACL del proveedor.
- La demostración depende de levantar API y base de datos; `docs/estado.md` registra que Compose no incluye el servicio `api` y que los tests de Jest del API no corrían por configuración de TypeScript.

**Nota de consistencia:** la sección «Qué falta» de este documento todavía enumera logout, restauración de sesión y recuperación de contraseña como pendientes, y «Qué hay» solo menciona los endpoints de registro e inicio de sesión. La inspección de este corte encontró implementación de esos flujos en `main`; no se reescriben esas secciones en esta tarea. La validación funcional de extremo a extremo sigue pendiente.

## Blockers

| Blocker | Impacto | Responsable | Desde |
| --- | --- | --- | --- |
| Destino en la nube sin decidir (ver sección Nube / hosting) | Bloquea uploads de P1 con acceso del dueño y el despliegue | Equipo / Alex (W8-15) | 27 oct 2026 |
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
| Votar destino de nube con los criterios de la sección Nube / hosting | Equipo | #16 (doc lista; decisión pendiente) |

## Nube / hosting

Estado: Pendiente de votacion del equipo.

Fecha limite: 27 oct 2026.

### Criterios minimos

1. HTTPS publico
2. Postgres persistente
3. Fotos con acceso solo del dueno
4. Costo cero o credito estudiantil
5. Esfuerzo de operacion del equipo

### Opciones

#### VPS + Compose + Caddy

- Pro: el mismo `docker-compose` del repo puede vivir en el servidor.
- Pro: Postgres y disco de fotos quedan en la misma maquina, con control del equipo.
- Pro: Caddy puede terminar HTTPS con un dominio.
- Contra: hay que operar sistema, backups y disco.
- Contra: una sola maquina es un punto de fallo.
- Contra: el credito estudiantil no siempre cubre un VPS.

#### PaaS + Postgres administrado + R2 o Cloudinary

- Pro: HTTPS y deploys los da la plataforma.
- Pro: Postgres administrado reduce backups manuales.
- Pro: las fotos pueden ir a un bucket con ACL por objeto o por prefijo de usuario.
- Contra: hay que vigilar que el plan gratis no se acabe a mitad del cuatrimestre.
- Contra: el equipo debe leer la doc de la PaaS concreta (aun no elegida).
- Contra: mas piezas (app, db, bucket) que un solo VPS.

#### Supabase

- Pro: Postgres y storage en un solo producto, con plan de entrada.
- Pro: HTTPS incluido en el proyecto hosted.
- Pro: el motor sigue siendo Postgres, el mismo que usa Prisma en local.
- Contra: el plan usa Nest + Prisma como API propia. Supabase no reemplaza ese API.
- Contra: hay que cuidar que las reglas de storage no queden publicas.
- Contra: el equipo aun no decide si el storage de Supabase sera el driver de fotos.

La eleccion final la cierra el equipo antes del 27 oct 2026. Este documento no provisiona nada.
