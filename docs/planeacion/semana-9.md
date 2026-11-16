# Planeación de la semana W9

> **Issue:** #64, W9-18 | **Épica:** E13 | **Corte:** 2026-11-10
>
> **Base de inspección:** `main` en `54cc648` | **Rama de cierre:** `main`
>
> **Fuentes:** issues y assignees consultados en GitHub el 2026-11-10; `docs/estado.md`; `docs/plans/plan-maestro-fittrack360.md`; historial de Git de `main`.

Este documento ordena el lote W9 (#47–#64) y deja constancia de que todas las tareas están integradas y cerradas. No reescribe el plan maestro ni el README raíz, y no sustituye el checklist H2.

## A. Objetivo de W9

W9 tuvo dos frentes:

**Cierre de F1 (autenticación y sesión).** Completar refresh de tokens, logout con revocación, restauración de sesión al reabrir, recuperación de contraseña y la validación funcional de esos flujos contra el API y PostgreSQL.

**Inicio de F2 (datos del usuario) y P1.** Poner la base del catálogo y de las entidades del usuario: modelo y seed de `Exercise`, CRUD de `WorkoutSession`, CRUD de `MealLog`, `StorageService` con aislamiento por dueño y la fotografía mínima de P1 (elegir o capturar, comprimir y subir).

Ambos frentes quedaron integrados en `main` y las 18 issues están cerradas.

## B. Tareas y responsables

Responsables tomados del campo **Assignees** de cada issue en GitHub al 2026-11-10.

Criterio de estado:

- `Integrado`: el cambio está en `main` con PR o commit verificable y la issue está cerrada.

| Issue | Tarea / Entregable | Responsable | Dependencia | Estado |
| --- | --- | --- | --- | --- |
| #47 | Alinear `PORT` entre API, Flutter y Docker | `@danielita05` | W8-07 / W8-08 | Integrado (issue cerrada) |
| #48 | Refresh y logout en NestJS | `@AlexReyes03` | Auth base (#12/#13) | Integrado |
| #49 | `JwtAuthGuard` y `GET /users/me` | `@AlexReyes03` | W9-02 | Integrado |
| #50 | Mail de forgot y reset de contraseña | `@AlexReyes03` | W8-07 (Mailpit) | Integrado |
| #51 | Restauración de sesión en splash | `@AlexReyes03` | #14 / #15 | Integrado |
| #52 | Logout y limpieza de tokens | `@AlexReyes03` | W9-05; W9-02 | Integrado |
| #53 | `go_router` auth vs app | `@AlexReyes03` | W9-05 | Integrado |
| #54 | Cliente HTTP con refresh | `@AlexReyes03` | W9-02; W9-05 | Integrado |
| #55 | Cablear `OfflineBanner` en el shell | `@danielita05` | #24 (W8-23) | Integrado (PR #76) |
| #56 | Pruebas unitarias de `AuthService` | `@danielita05` | Auth Nest estable | Integrado (PR #77) |
| #57 | Checklist H2 de F1 y P1 para W9 | `@Loreley100` | #31 (W8-30) | Integrado (PR #97) |
| #58 | Modelo `Exercise` y seed de muestra | `@Jafetvu` | PostgreSQL + Prisma | Integrado (PR #78) |
| #59 | CRUD `WorkoutSession` con ownership y 404 | `@Jafetvu` | W9-03; W9-12 recomendado | Integrado (PR #85) |
| #60 | CRUD `MealLog` con ownership y 404 | `@Jafetvu` | W9-03 | Integrado (PR #96) |
| #61 | `StorageService` local con ACL por dueño | `@AlexReyes03` | W9-03 | Integrado |
| #62 | P1: `image_picker` y subida mínima | `@M4ltin12` | W9-15; `docs/permisos.md` | Integrado (PR #89) |
| #63 | Lista y creación de `WorkoutSession` en Flutter | `@M4ltin12` | W9-07; W9-13 | Integrado (PR #90) |
| #64 | Planeación de la semana W9 | `@Loreley100` | #28 (W8-27) | Integrado (PR #98) |

**Nota sobre responsables.** #47 aparece asignada a `@danielita05` en GitHub. Las descripciones originales de #48, #49, #50 y #61 mencionan otros handles, pero la asignación vigente es la que muestra GitHub al 2026-11-10.

**Evidencia de integración**

| Issue | Evidencia verificable en `main` |
| --- | --- |
| #47 | `fit_track_api/src/main.ts` usa `process.env.PORT ?? 3000`; `.env.example` fija `PORT=3000`; `Dockerfile` expone 3000; Flutter usa `http://10.0.2.2:3000` por defecto. Issue cerrada. |
| #48–#50 | Commit `813a656` (refresh, logout, guard y recuperación) es ancestro de `main`; módulos `auth`, `users` y `mail` presentes. Mailpit y servicio `api` integrados con PR #104. |
| #51–#54 | Router, splash, `SessionStorage` y `ApiClient` con refresh único en `fit_track_360/lib`. |
| #55 | PR #76 fusionado; `home_shell_page.dart` y su prueba. |
| #56 | PR #77 fusionado; `test/auth/auth.service.spec.ts` con 9 pruebas en el runner. |
| #57 | PR #97 fusionado (`268dd79`); checklist H2 actualizado. |
| #58 | PR #78 fusionado (`8285b5a`); modelo y seed de ejercicios. |
| #59 | PR #85 fusionado (`4e446b1`); módulo `workouts`. |
| #60 | PR #96 fusionado (`bb32faf`); módulo `meals`. |
| #61 | Commit `bf9722b` es ancestro de `main`; `src/storage/` con aislamiento por `userId`. |
| #62 | PR #89 fusionado (`0354c0d`); `progress_photo_page.dart` con `image_picker`. |
| #63 | PR #90 fusionado (`04a79ff`); `features/workouts` en Flutter. |
| #64 | PR #98 fusionado (`ac81b81`); este documento. |

## C. Dependencias cubiertas

1. **API y PostgreSQL:** PR #104 agregó `api` y Mailpit al compose; la API y la base se levantan juntas.
2. **Autenticación y ownership:** #49 habilitó el filtrado por dueño que usan #59, #60 y #61.
3. **Storage API:** #61 quedó disponible antes de la integración de #62.
4. **Sesión y router:** #51 y #53 habilitaron #55 y #63.
5. **Catálogo:** #58 quedó integrado antes del cierre de workouts.
6. **Mailpit:** #50 y W8-07 quedaron cubiertos por PR #104.
7. **Checklist H2 y planeación:** #57 se integró con PR #97 y #64 con PR #98.

## D. Riesgos y estado final

| Riesgo | Situación al 2026-11-10 | Estado |
| --- | --- | --- |
| SMTP / Mailpit | `docker-compose.yml` incluye `api` y `mailpit`; `MailService` envía en desarrollo. | Resuelto (PR #104). |
| Puertos Flutter / NestJS | API en 3000 y Flutter en `10.0.2.2:3000`; #47 cerrada. | Resuelto. |
| Respuestas 404 para recursos ajenos | `workouts`, `meals` y `storage` resuelven por `userId`; las pruebas de API cubren el aislamiento. | Resuelto en código y pruebas. |
| Almacenamiento local vs nube | `StorageService` escribe en `UPLOAD_DIR/<userId>/`; el proveedor de objetos y su ACL pertenecen a la fase de despliegue. | Fuera del alcance W9. |
| Sobrecarga por trabajo de W8 | W8-07 quedó integrada con PR #104; W8-09 y W8-10 se recuperaron con PR #107. | Resuelto. |
| Configuración de PostgreSQL | El compose y `.env.example` quedaron alineados con el servicio `postgres`. | Resuelto. |
| Suite Flutter | La prueba de `home_shell_page` busca `Cerrar sesion` y la UI usa `Cerrar sesión`. | Deuda de sincronización para W11; no bloquea el cierre de W9. |
| Issues abiertas con trabajo integrado | #47, #57, #60 y #64 están cerradas. | Resuelto. |

## E. Seguimiento

| Campo | Registro |
| --- | --- |
| Fecha de corte | 2026-11-10 |
| Base revisada | `main` en `54cc648` |
| Entregables esperados | F1 demostrable (registro, login, logout, restore, refresh, forgot/reset); base de F2 (`Exercise`, `WorkoutSession`, `MealLog`); `StorageService` y P1 mínimo. |
| Completado con evidencia | #47–#64 integrados y cerrados; PR #97 y #98 fusionados; W8-07, W8-09 y W8-10 recuperados con PR #104 y #107. |
| Pendientes o bloqueos | Ninguno del lote W9. La nube, el P1 completo y la sincronización de pruebas pasan a W11. |

**Relación con H2.** H2 es el hito académico de UTEZ y exige demostrar F1 y P1 ante el docente. W9 cubrió la recuperación de ambos frentes; el checklist de #57 quedó integrado en `main` con PR #97.

**Cierre del lote.** Las 18 issues de W9 están cerradas. No quedan tareas abiertas, ramas pendientes ni PRs sin fusionar de este lote.
