# Planeación de la semana W8

> **Issue:** #2–#31, W8-01 a W8-30 | **Épica:** E1, E2, E3, E4, E10, E13 | **Corte:** 2026-11-10
>
> **Base de inspección:** `main` en `7a46147` | **Rama de cierre:** `main`
>
> **Fuentes:** `docs/task-planning/tasks-w8.md`; issues, assignees y estado consultados en GitHub el 2026-11-10; historial de Git de `main`; `docs/estado.md`; `README.md`.

Este documento ordena el lote W8 (#2–#31) y deja constancia de que las 30 tareas están completadas y las issues cerradas. No reescribe el plan maestro ni el README raíz.

## A. Objetivo de W8

W8 fue el arranque de la Fase 0 y la base de recuperación de H2. Tuvo cuatro frentes:

**Infraestructura y API.** Levantar PostgreSQL con Docker Compose, inicializar Prisma, aplicar la migración inicial de usuarios y tokens, cargar un seed mínimo de ejercicios, construir la imagen multi-stage del API y extender el mismo compose con `api` y Mailpit.

**Autenticación base.** Definir contratos de Auth, implementar register y login con Argon2 y JWT, guardar la sesión en almacenamiento seguro de Flutter y construir las pantallas iniciales de Login y Registro.

**Design system y estructura móvil.** Portar los tokens Liquid Glass a Dart, crear `GlassSurface`, `PrimaryButton`, templates de scaffold y formulario, configurar el tema dark-only con Splash/Home, definir el árbol `core` y `features`, `AsyncState` y el banner offline.

**Documentación y evidencia.** Documentar criterios de nube, permisos, bitácora IA, estado del proyecto, responsables por capacidad, planeación, aviso de privacidad, strings de auth y checklist de recuperación H2.

Las 30 issues del lote están cerradas.

## B. Tareas y responsables

Responsables tomados del campo **Assignees** de cada issue en GitHub al 2026-11-10.

Criterio de estado:

- `Completado`: la issue está cerrada y el entregable tiene evidencia en `main` o en la documentación versionada.

| Issue | Tarea / Entregable | Responsable | Dependencia | Estado |
| --- | --- | --- | --- | --- |
| #2 | Servicio Postgres en `docker-compose.yml` | `@Jafetvu` | - | Completado (issue cerrada) |
| #3 | Inicializar Prisma en el API | `@Jafetvu` | W8-01 | Completado (issue cerrada) |
| #4 | Migration inicial de `User`, `RefreshToken` y `PasswordResetCode` | `@Jafetvu` | W8-02 | Completado (issue cerrada) |
| #5 | Seed de muestra de ejercicios (3 a 5) | `@Jafetvu` | W8-02 | Completado (issue cerrada) |
| #6 | Base de `.env.example` con `DATABASE_URL` | `@Jafetvu` | W8-01 | Completado (issue cerrada) |
| #7 | Dockerfile multi-stage del API | `@MiguelSP040` | - | Completado (issue cerrada) |
| #8 | Extender compose con API y Mailpit | `@MiguelSP040` | W8-01; W8-06 | Completado (issue cerrada) |
| #9 | `ConfigModule`, `ValidationPipe` y Swagger | `@danielita05` | W8-06 | Completado (issue cerrada) |
| #10 | Prefijo `/api/v1`, request-id y health | `@danielita05` | W8-08 | Completado (issue cerrada) |
| #11 | Servir media estática de ejercicios | `@danielita05` | W8-06; W8-07 | Completado (issue cerrada) |
| #12 | Contratos Auth y regla 404 | `@AlexReyes03` | W8-08 | Completado (issue cerrada) |
| #13 | Auth Nest con register, login, Argon2 y JWT | `@AlexReyes03` | W8-03; W8-09; W8-11 | Completado (issue cerrada) |
| #14 | `SessionStorage` con `flutter_secure_storage` | `@AlexReyes03` | W8-12 | Completado (issue cerrada) |
| #15 | Pantallas Login y Registro | `@AlexReyes03` | W8-16; W8-29 | Completado (issue cerrada) |
| #16 | Criterios de nube en `docs/estado.md` | `@AlexReyes03` | W8-25 | Completado (issue cerrada) |
| #17 | Tokens del design system en Dart | `@M4ltin12` | - | Completado (issue cerrada) |
| #18 | `GlassSurface` y `PrimaryButton` | `@M4ltin12` | W8-16 | Completado (issue cerrada) |
| #19 | Templates `AppScaffold` y `FormPage` | `@M4ltin12` | W8-17 | Completado (issue cerrada) |
| #20 | Tema dark-only y Splash/Home | `@M4ltin12` | W8-16; W8-18 | Completado (issue cerrada) |
| #21 | `env/example.json` para Flutter | `@M4ltin12` | - | Completado (issue cerrada) |
| #22 | Árbol de `core` y `features` | `@danielita05` | - | Completado (issue cerrada) |
| #23 | `AsyncState` sealed con Loading, Data, Error y Empty | `@danielita05` | W8-21 | Completado (issue cerrada) |
| #24 | Banner offline reutilizable | `@danielita05` | W8-21 | Completado (issue cerrada) |
| #25 | Borrador de `docs/permisos.md` | `@danielita05` | - | Completado (issue cerrada) |
| #26 | Plantillas de bitácora IA y `estado.md` | `@danielita05` | - | Completado (issue cerrada) |
| #27 | Tabla de responsables en el README | `@Loreley100` | - | Completado (issue cerrada) |
| #28 | Plantilla de `docs/planeacion/` | `@Loreley100` | - | Completado (issue cerrada) |
| #29 | Copy del aviso de privacidad | `@Loreley100` | - | Completado (issue cerrada) |
| #30 | Strings en español para auth | `@Loreley100` | - | Completado (issue cerrada) |
| #31 | Checklist de recuperación H2 | `@Loreley100` | - | Completado (issue cerrada) |

**Nota sobre responsables.** Las issues #9, #10 y #11 aparecen asignadas a `@danielita05` en GitHub, aunque el plan original las atribuía a `@MiguelSP040`. La asignación vigente es la que muestra GitHub al 2026-11-10.

**Evidencia de integración**

| Issue | Evidencia verificable en `main` |
| --- | --- |
| #2 | PR #41 (`0cba322`); `fit_track_api/docker-compose.yml` define `postgres:16-alpine`, volumen `pgdata` y healthcheck con `pg_isready`. |
| #3 | PR #43 (`fe134ad`); `PrismaService` y `PrismaModule` integrados en el API. |
| #4 | PR #44 (`f50eb45`); modelos `User`, `RefreshToken` y `PasswordResetCode` en `fit_track_api/prisma/schema.prisma`. |
| #5 | PR #45 (`d64cf9a`); modelo `Exercise` y seed de muestra en `fit_track_api/prisma/seed.ts`. |
| #6 | PR #42 (`9c9d190`); `fit_track_api/.env.example` contiene `DATABASE_URL` y variables de desarrollo. |
| #7 | PR #103 (`e0a4866`); `fit_track_api/Dockerfile` multi-stage con la media de ejercicios. |
| #8 | PR #104 (`bc99319`); el compose incluye `api` y `mailpit` en la misma red, con puertos documentados. |
| #9 | PR #99 (`beb5548`); configuración global, `ValidationPipe` y Swagger en `/api/docs`. |
| #10 | PR #100 (`e8d9d0d`) y recuperación PR #107 (`54cc648`); prefijo `/api/v1`, `x-request-id` y health con sonda de DB. |
| #11 | PR #101 (`2e911ce`) y recuperación PR #107 (`54cc648`); media servida bajo `/static/exercises/`. |
| #12 | DTOs en `fit_track_api/src/auth/dto/` y regla 404 documentada en `fit_track_api/src/auth/README.md`; issue cerrada. |
| #13 | `AuthService` y `AuthController` con register, login, Argon2 y JWT; issue cerrada. |
| #14 | `fit_track_360/lib/core/session_storage.dart` usa `FlutterSecureStorage` y no `SharedPreferences`. |
| #15 | `login_page.dart` y `register_page.dart` en `fit_track_360/lib/features/auth/presentation/`; la UX se refinó después en PR #74. |
| #16 | PR #68 (`2cc1191`); `docs/estado.md` contiene la sección Nube / hosting con opciones, criterios y fecha límite. |
| #17 | PR #83 (`2b506c1`); tokens en `fit_track_360/lib/design_system/tokens/`. |
| #18 | PR #84 (`eaca962`); `glass_surface.dart` y `primary_button.dart` en `design_system/components/`. |
| #19 | PR #86 (`0cca202`); `app_scaffold_template.dart` y `form_page_template.dart` en `design_system/templates/`. |
| #20 | PR #87 (`fe3c54c`); tema dark-only y Splash con el look del design system. |
| #21 | PR #88 (`43ead8f`); `fit_track_360/env/example.json` versionado. |
| #22 | PR #36 (`32042f5`); árbol `core/` y `features/*/{data,domain,presentation}/`. |
| #23 | PR #37 (`8a51fb2`); `AsyncState` sealed con las cuatro variantes. |
| #24 | PR #38 (`857eecb`); banner offline con callback de reintento. |
| #25 | PR #39 (`a07ac6d`); `docs/permisos.md` con P1, P2, P3, O1, O5, O7 y O10. |
| #26 | PR #40 (`425d97a`); `docs/ia/bitacora.md` y `docs/estado.md` iniciales. |
| #27 | PR #73 (`c23a578`); tabla de responsables por capacidad en el README raíz. |
| #28 | PR #65 (`21875a5`); índice y secciones iniciales de `docs/planeacion/`. |
| #29 | PR #66 (`3ecf91f`); `docs/copy/aviso-privacidad.md` con el disclaimer no médico. |
| #30 | PR #67 (`9f46d7a`); `docs/copy/auth-strings.md` para Login, Registro y recuperación. |
| #31 | PR #72 (`a289e81`); checklist H2 integrado como sección de `docs/estado.md`, actualizado después en PR #97. |

## C. Dependencias cubiertas

1. **PostgreSQL y Prisma:** W8-01 quedó antes de W8-02, W8-03 y W8-05; la migración de Auth quedó disponible para W8-12.
2. **Compose y API:** W8-06 y W8-07 integraron la imagen del API y Mailpit en el mismo compose; W8-10 pudo validar la media en contenedor.
3. **Gateway:** W8-08 habilitó prefijo, validación y Swagger; W8-09 agregó health y request-id antes de Auth.
4. **Auth API:** W8-11 definió contratos antes de W8-12; W8-13 y W8-15 consumieron los tokens y el contrato resultante.
5. **Design system:** W8-16 quedó antes de W8-17 y W8-18; W8-19 reutilizó templates y tokens.
6. **UI Auth:** W8-16 y W8-29 quedaron disponibles antes de W8-15.
7. **Estructura Flutter:** W8-21 quedó antes de W8-22 y W8-23.
8. **Documentación:** W8-25 creó `docs/estado.md` antes de W8-15; W8-27, W8-28, W8-29 y W8-30 completaron la evidencia documental.
9. **Seed:** W8-04 validó el pipeline con 3 a 5 ejercicios; el catálogo completo se movió a W9.

## D. Riesgos y estado final

| Riesgo | Situación al 2026-11-10 | Estado |
| --- | --- | --- |
| Integración tardía de Docker y API | W8-06, W8-07, W8-08, W8-09 y W8-10 cerraron entre el 9 y 10 de noviembre; se recuperaron con PR #99, #100, #101, #103, #104 y #107. | Resuelto. |
| Asignación distinta a la planeada | #9, #10 y #11 están asignadas a `@danielita05` en GitHub, no a `@MiguelSP040`. | Resuelto con la asignación vigente. |
| Seed incompleto | W8 solo cargó 3 a 5 ejercicios; el catálogo completo se implementó en W9 con PR #78. | Fuera del alcance W8; resuelto en W9. |
| Forgot-password, refresh y logout | W8 dejó la base de Auth y Mailpit; los flujos completos se integraron en W9 con el commit `813a656` y PR #104. | Fuera del alcance W8; resuelto en W9. |
| Checklist H2 sin archivo separado | W8-30 se integró como sección de `docs/estado.md`, no como `docs/task-planning/checklist-h2.md`. | Aceptado y actualizado en W9 con PR #97. |
| Destino de nube sin decidir | `docs/estado.md` documenta opciones y criterios; la elección final sigue pendiente del equipo. | Documentado; no bloqueó W8. |
| Almacenamiento de fotos en nube | W8 no implementó P1; el mínimo local llegó en W9 y la nube sigue fuera de alcance. | Fuera del alcance W8. |
| Desfase de textos en la suite Flutter | La prueba de `home_shell_page` busca `Cerrar sesion` y la UI usa `Cerrar sesión`. | Deuda posterior para W11; no bloquea W8. |
| Issues abiertas del lote | Las 30 issues #2–#31 están cerradas. | Resuelto. |

## E. Seguimiento

| Campo | Registro |
| --- | --- |
| Fecha de corte | 2026-11-10 |
| Base revisada | `main` en `7a46147` |
| Entregables esperados | Infraestructura PostgreSQL y API en Compose; Prisma y migración de Auth; Auth register/login con Argon2 y JWT; design system Liquid Glass; estructura Flutter; documentación de planeación y H2. |
| Completado con evidencia | #2–#31 cerradas; PR #36–#45, #65–#68, #72–#74, #83–#88, #99–#104 y #107 con los entregables del lote. |
| Pendientes o bloqueos | Ninguno del lote W8. El catálogo completo, refresh/logout, forgot-password, P1 en nube y la sincronización de pruebas pasan a W9 y W11. |

**Relación con H2.** H2 es el hito académico de UTEZ y exige demostrar F1 y P1 ante el docente. W8 dejó la base de infraestructura, Auth, design system y documentación; W9 completó la recuperación funcional de F1 y el mínimo de P1.

**Cierre del lote.** Las 30 issues de W8 están cerradas. No quedan issues abiertas de este lote.
