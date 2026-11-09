# Estado del proyecto — FitTrack360

> **Última actualización:** 2026-11-06 · **Actualizó:** Daniela Carrate (W8-08, W8-09, W8-10 y W9-01)
> Actualiza la fecha y tu nombre cada vez que edites. Describe solo lo que está en `main` o en un PR abierto; no adelantes avance.

## Qué hay

Integrado en `main`:

- Monorepo con pnpm, Husky (`pre-commit`, `commit-msg`, `pre-push`) y menú `pnpm dev`. La opción de levantar el API con Docker falla hoy (ver Blockers).
- API NestJS (`fit_track_api`): Prisma con usuarios y tokens, servicio Postgres en `docker-compose.yml`, `Dockerfile`, endpoints `POST /api/v1/auth/register` y `POST /api/v1/auth/login`.
- App Flutter (`fit_track_360`): pantallas de login y registro, `SessionStorage` con `flutter_secure_storage`, tokens de color del design system.
- Árbol de carpetas `core/` y `features/*` (W8-21).
- `AsyncState<T>` sealed con sus pruebas (W8-22). Todavía no lo usa ninguna pantalla.
- Banner offline con Reintentar (W8-23). Conectado al shell autenticado en el PR #76 (W9-09).
- Borrador de `docs/permisos.md` y plantillas de `docs/ia/bitacora.md` y este archivo (W8-24 y W8-25).

En PR abierto: ver la lista de PRs del repositorio (incluye esta actualización de Nube / hosting cuando se abra).

En PRs abiertos y apilados (W8-08 → W8-09 → W8-10 → W9-01), verificados en ejecución el 2026-11-06 con Postgres real, el API nativo y en Docker, el navegador y el emulador Android:

- W8-08 (#9): `configureApp` en `fit_track_api/src/app.setup.ts` concentra prefijo `/api/v1`, `ValidationPipe` global y Swagger en `/api/docs`; `main.ts` y las pruebas usan la misma configuración.
- W8-09 (#10): `GET /api/v1/health` responde `{ "status": "ok", "db": "up" | "down" }` y sigue en 200 con la base caída. Toda respuesta lleva `x-request-id` (`src/gateway/`).
- W8-10 (#11): media de ejercicios en `/static/exercises/images/*` y `/static/exercises/videos/*` con `@nestjs/serve-static`, sin listar directorios ni exponer `NOTICE.md`. El `Dockerfile` ya copia `public/` en la imagen.
- W9-01 (#47): puerto único 3000 para nativo, Docker (`-p PORT:PORT`) y emulador (`10.0.2.2:3000`). Un `PORT` inválido detiene el arranque con un mensaje. **El blocker de puertos 3000 vs 3001 queda resuelto:** se quitó de la tabla en #77 y W9-01 lo verificó registrando desde el host y desde el emulador contra el mismo proceso Nest, nativo y en Docker.

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

### Actualización W9 — Verificación H2

> **Corte:** 2026-11-06. **Origen:** inspección estática de `main` (`bb32faf`) y ejecución local de las pruebas automatizadas en la rama `docs/w9-11-checklist-h2`. **Responsable de la actualización:** Por asignar (no confirmado).
>
> **Alcance:** H2 es la demostración académica de F1 y P1 ante el docente de UTEZ. No es una certificación de producción ni una prueba de carga; el objetivo es mostrar los flujos funcionando en un dispositivo y contra el API.

Esta actualización conserva intacto el registro W8 anterior (corte 2026-11-03) y no reescribe las demás secciones de `docs/estado.md`. La evidencia W8 sobre P1 quedó superada por W9-16 (PR #89, commit `0354c0d`); se mantiene como historial.

Regla aplicada en W9: una casilla solo se marca cuando existe evidencia funcional reproducible (prueba automatizada en verde o ejecución verificada en dispositivo). Código presente, issue cerrada o PR fusionado **no** bastan para marcar `hecho`.

| Bloque | Requisitos | Hechos | En progreso | Pendientes |
| --- | ---: | ---: | ---: | ---: |
| F1 — Autenticación y sesión | 6 | 0 | 6 | 0 |
| P1 — Fotografía y almacenamiento | 3 | 0 | 3 | 0 |
| **Total** | **9** | **0** | **9** | **0** |

**Cambio respecto de W8:** F1 pasa de 5 a 6 requisitos porque Refresh se verifica como ítem independiente y no como parte de Restore. P1 pasa de 2 pendientes a 3 en progreso porque ya existen selector de cámara/galería, compresión en cliente y subida autenticada. Ningún requisito alcanza `hecho`: sigue faltando la validación de extremo a extremo.

#### F1 — Autenticación y sesión (verificación W9)

- [ ] **Registro remoto** — Estado: `en progreso`.
  - Evidencia: `register_page.dart` envía `POST /api/v1/auth/register` mediante `register()` en `auth_api.dart`; `AuthController.register` delega en `AuthService.register`, que valida duplicados, hashea con Argon2, guarda `privacyConsentAt`/`privacyNoticeVersion` y emite tokens (`auth.service.ts`). `pnpm --dir fit_track_api run test` ejecutó 9 pruebas en verde, incluidas 4 de registro (correo duplicado, usuario duplicado, contraseña hasheada y consentimiento).
  - Reporte manual: una integrante reportó un registro exitoso en un Motorola durante una prueba manual. Es un indicio de funcionamiento en dispositivo, pero no quedó documentado en este corte con fecha, pasos, cuenta ni captura; por eso no se contabiliza como prueba E2E ni cambia el estado.
  - Falta demostrar: documentar formalmente esa prueba manual (fecha, dispositivo, cuenta y resultado) y ejecutar el flujo completo desde la app contra API y PostgreSQL, incluido el rechazo de un correo ya existente. No hay prueba E2E documentada.

- [ ] **Login** — Estado: `en progreso`.
  - Evidencia: `login_page.dart` llama `login()` y guarda los tokens con `flutter_secure_storage` (`session_storage.dart`). `AuthService.login` verifica Argon2 y emite JWT; las pruebas cubren credenciales válidas, contraseña incorrecta, correo inexistente sin enumeración y almacenamiento del hash del refresh.
  - Falta demostrar: inicio de sesión desde la app contra el API real, rechazo visible con contraseña incorrecta y acceso al shell autenticado con `GET /users/me`.

- [ ] **Refresh de tokens** — Estado: `en progreso`.
  - Evidencia: `POST /api/v1/auth/refresh` (`auth.controller.ts`) valida la firma del refresh con `JWT_REFRESH_SECRET`, busca el token por hash, comprueba que no esté revocado ni vencido, verifica que pertenezca al mismo `userId`, revoca el token usado y emite un par nuevo (`auth.service.ts`). En Flutter, `ApiClient._send` y `uploadFile` intentan un único refresh ante 401 y reintentan una vez; `refreshTokens()` en `auth_api.dart` consume el endpoint y `SessionStorage` reemplaza ambos tokens.
  - Falta demostrar: prueba automatizada de `refresh` (token válido, revocado, vencido y de otro usuario) y verificación en ejecución de que un refresh revocado ya no renueva. No hay prueba E2E ni de integración.

- [ ] **Logout** — Estado: `en progreso`.
  - Evidencia: `home_shell_page.dart` revoca el refresh con `logout()` y limpia `SessionStorage` en `finally`; `AuthService.logout` marca el token como revocado. **La prueba `cerrar sesion sin red limpia la sesion y va a login` falla** en este corte: busca el texto `Cerrar sesion` y la UI usa `Cerrar sesión` (con acento). Resultado de `flutter test`: 17 pruebas en verde y 1 en rojo.
  - Falta demostrar: corregir la sincronía texto UI/prueba, ejecutar logout con y sin red, y comprobar que el refresh revocado ya no permite renovar.

- [ ] **Restauración de sesión al reabrir** — Estado: `en progreso`.
  - Evidencia: `splash_page.dart` lee el access token y navega a `/app`; `router.dart` redirige según la presencia del token; `ApiClient` intenta un refresh único ante 401 y limpia la sesión si falla (`api_client.dart`). No existe prueba de `SplashPage` ni de restauración.
  - Falta demostrar: cerrar y reabrir la app con sesión válida, con access vencido pero refresh vigente y con refresh revocado. La restauración actual solo comprueba la presencia del token, no su vigencia.

- [ ] **Forgot/reset de contraseña** — Estado: `en progreso`.
  - Evidencia: `forgot_password_page.dart` y `reset_password_page.dart` consumen `POST /api/v1/auth/password/forgot` y `/password/reset`; el API genera un código de 6 dígitos, lo guarda hasheado con TTL de 15 minutos, responde igual si el correo no existe, invalida refresh tokens y marca el código como usado (`auth.service.ts`). `MailService` envía por SMTP y, sin `SMTP_HOST`, responde 200 sin enviar.
  - Falta demostrar: recepción real del código. `docker-compose.yml` no incluye Mailpit, no hay prueba automatizada de forgot/reset y no se verificó el flujo completo correo → código → nueva contraseña → login.

#### P1 — Fotografía y almacenamiento (verificación W9)

- [ ] **Capturar o elegir una fotografía** — Estado: `en progreso`.
  - Evidencia: `progress_photo_page.dart` usa `image_picker` con cámara y galería, solicita `Permission.camera` y ofrece continuar sin foto; la ruta `/app/foto` está registrada en `router.dart` y se abre desde `home_shell_page.dart`. `pubspec.yaml` incluye `image_picker` y `permission_handler`.
  - Falta demostrar: ejecución en el moto g52 con los tres estados de permiso (concedido, denegado y denegado permanente), cámara real y selector de fotos de Android 13. No hay prueba de widget ni de dispositivo.

- [ ] **Comprimir la fotografía antes de subirla** — Estado: `en progreso`.
  - Evidencia: `_pickAndUpload` llama `pickImage` con `maxWidth: 1280` e `imageQuality: 70` antes de enviar el archivo; `ApiClient.uploadFile` envía el resultado por multipart.
  - Falta demostrar: medir el peso antes y después con una foto real y confirmar que el servidor no recibe EXIF/GPS. El backend no re-codifica (no usa `sharp`); la compresión depende solo del cliente.

- [ ] **Subir la imagen con acceso restringido a su propietario** — Estado: `en progreso`.
  - Evidencia: `ProgressPhotoPage` sube a `POST /api/v1/storage/files` con Bearer; `StorageController` protege `POST`, `GET` y `DELETE` con `JwtAuthGuard`; `StorageService` escribe en `UPLOAD_DIR/<userId>/` y responde 404 si el `userId` no coincide. Hay integración real entre la pantalla y el endpoint.
  - Falta demostrar: subida y descarga desde el dispositivo, prueba entre dos cuentas (404 y no 403) y asociación de la foto a un registro de progreso o comida. **El almacenamiento es disco local**, no nube, y no hay ACL de proveedor: esto cubre el mínimo de P1, no el requisito completo.

#### Diferencia entre P1 mínimo y P1 completo

El avance W9 demuestra el **mínimo de P1**: elegir o capturar una foto, reducirla en el cliente y subirla autenticada a un almacenamiento separado por `userId`. El requisito completo de P1 exige además **almacenamiento en la nube con acceso restringido del proveedor** (HTTPS público, objeto privado, URL firmada o ACL, borrado al eliminar el registro o la cuenta y eliminación de EXIF en servidor). Nada de eso está implementado ni verificado; el destino de nube sigue sin decidirse.

#### Bloqueos que impiden cerrar H2

- No hay prueba E2E de F1 contra API y PostgreSQL reales; las pruebas del API usan dobles en memoria y las de Flutter usan `MockClient`.
- `flutter test` no está en verde: falla `cerrar sesion sin red limpia la sesion y va a login` por desfase entre el texto de la UI (`Cerrar sesión`) y el de la prueba (`Cerrar sesion`).
- Mailpit no está en `docker-compose.yml`; sin SMTP no se puede demostrar la recepción del código de recuperación.
- No existe prueba de `SplashPage` ni de restauración de sesión con token vencido.
- P1 no tiene prueba automatizada ni evidencia en dispositivo físico de los tres estados de permiso.
- El destino de nube y la ACL del proveedor siguen pendientes; el almacenamiento actual es local.
- La demostración depende de levantar API y base de datos; el panel `pnpm dev` requiere Docker y `docker-compose.yml` mantiene credenciales distintas a `.env`.

#### Evidencia ejecutada en este corte

| Comando | Resultado |
| --- | --- |
| `pnpm --dir fit_track_api run test` | 2 suites, 9 pruebas en verde (registro y login). Requirió `prisma generate` porque el cliente no estaba generado tras la instalación. |
| `flutter test` | 18 pruebas: 17 en verde, 1 en rojo (`cerrar sesion sin red limpia la sesion y va a login`). |
| Revisión de código | `auth/`, `storage/`, `mail/`, `progress/`, `router.dart`, `api_client.dart`, `session_storage.dart`, `home_shell_page.dart`, `splash_page.dart`. |

**Criterio de cierre de H2:** marcar una casilla solo cuando la demostración se haya ejecutado en el dispositivo y contra el API real, con el resultado registrado aquí. Hasta entonces, F1 y P1 permanecen `en progreso`.

## Blockers

| Blocker | Impacto | Responsable | Desde |
| --- | --- | --- | --- |
| Destino en la nube sin decidir (ver sección Nube / hosting) | Bloquea uploads de P1 con acceso del dueño y el despliegue | Equipo / Alex (W8-15) | 27 oct 2026 |
| Modelo `Exercise` y `prisma/seed.ts` no están en `main`: #42–#45 se fusionaron en ramas intermedias, no en `main`, y #3–#6 ya están cerradas. Lo más reciente está en `feat/w8-04-exercise-seed` | Falta el seed de ejercicios; `main` tampoco tiene los otros cambios de esos PRs | Jafet / Alex | 2 nov 2026 |
| `docker-compose.yml` no tiene el servicio `api` (se espera en W8-07). El panel `pnpm dev` ya no lo usa: levanta el API con `docker run` | `docker compose up api` falla con `no such service: api`; desde el panel no aplica | Miguel (W8-07) | 2 nov 2026 |
| El panel `pnpm dev` toma como su Postgres cualquier contenedor con 5432 interno (por ejemplo `5441->5432`) y Space le aplica `docker stop` | Puede apagar la base de otro proyecto del integrante e informa «Iniciado» sin que haya nada en el puerto 5432 | Alex | 4 nov 2026 |
| Credenciales de Postgres distintas: compose usa `fittrack_db` y otra contraseña por defecto; `.env.example` y `pnpm dev` usan base y contraseña `fittrack` | Con una base nueva creada por compose, el `DATABASE_URL` de ejemplo no debería conectar (por configuración; sin probar) | Por asignar | 2 nov 2026 |

## Próximos pasos

| Paso | Responsable | Issue |
| --- | --- | --- |
| Llevar a `main` lo de #42–#45 con un PR desde `feat/w8-04-exercise-seed` | Jafet / Alex | #3–#6 |
| Recuperar el servicio `api` en compose y agregar Mailpit | Miguel | #8 |
| Unificar credenciales de Postgres entre compose y `.env.example` | Por asignar | Sin issue |
| Corregir la detección de Postgres del panel `pnpm dev` | Alex | Sin issue |
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
