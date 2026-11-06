# Planeación de la semana W9

> **Issue:** #64 — W9-18 · **Épica:** E13 · **Corte:** 2026-11-06
>
> **Base de inspección:** `main` en `bb32faf` · **Rama de esta tarea:** `docs/w9-18-planeacion`
>
> **Fuentes:** issues y assignees consultados en GitHub el 2026-11-06; `docs/estado.md`; `docs/plans/plan-maestro-fittrack360.md`; historial de Git de `main`.

Este documento ordena el lote W9 (#47–#64) y deja explícito qué está integrado, qué sigue abierto y de qué depende cada entregable. No reescribe el plan maestro ni el README raíz, y no sustituye el checklist H2.

## A. Objetivo de W9

W9 tiene dos frentes:

**Cierre de F1 (autenticación y sesión).** Completar refresh de tokens, logout con revocación, restauración de sesión al reabrir, recuperación de contraseña y la validación funcional de esos flujos contra el API y PostgreSQL. El código de los flujos ya está en `main`; lo que falta es demostrar su comportamiento de extremo a extremo.

**Inicio de F2 (datos del usuario) y P1.** Poner la base del catálogo y de las entidades del usuario: modelo y seed de `Exercise`, CRUD de `WorkoutSession`, CRUD de `MealLog`, `StorageService` con aislamiento por dueño y la fotografía mínima de P1 (elegir o capturar, comprimir y subir).

## B. Tareas y responsables

Responsables tomados del campo **Assignees** de cada issue en GitHub. No se infieren a partir de autores de commits ni de roles generales.

Criterio de estado:

- `Integrado`: el cambio está en `main` con PR o commit verificable.
- `Integrado, issue abierta`: el cambio está en `main`, pero la issue sigue abierta.
- `En revisión`: la rama está publicada, sin merge a `main`.
- `En curso`: trabajo de esta misma tarea.

| Issue | Tarea / Entregable | Responsable | Dependencia | Estado |
| --- | --- | --- | --- | --- |
| #47 | Alinear `PORT` entre API, Flutter y Docker | `@MiguelSP040` | W8-07 / W8-08 | Implementado en `main`, issue abierta |
| #48 | Refresh y logout en NestJS | `@AlexReyes03` | Auth base (#12/#13) | Integrado |
| #49 | `JwtAuthGuard` y `GET /users/me` | `@AlexReyes03` | W9-02 | Integrado |
| #50 | Mail de forgot y reset de contraseña | `@AlexReyes03` | W8-07 (Mailpit) | Integrado; falta Mailpit |
| #51 | Restauración de sesión en splash | `@AlexReyes03` | #14 / #15 | Integrado |
| #52 | Logout y limpieza de tokens | `@AlexReyes03` | W9-05; W9-02 | Integrado |
| #53 | `go_router` auth vs app | `@AlexReyes03` | W9-05 | Integrado |
| #54 | Cliente HTTP con refresh | `@AlexReyes03` | W9-02; W9-05 | Integrado |
| #55 | Cablear `OfflineBanner` en el shell | `@danielita05` | #24 (W8-23) | Integrado (PR #76) |
| #56 | Pruebas unitarias de `AuthService` | `@danielita05` | Auth Nest estable | Integrado (PR #77) |
| #57 | Checklist H2 de F1 y P1 para W9 | `@Loreley100` | #31 (W8-30) | En revisión (PR #97) |
| #58 | Modelo `Exercise` y seed de muestra | `@Jafetvu` | PostgreSQL + Prisma | Integrado (PR #78) |
| #59 | CRUD `WorkoutSession` con ownership y 404 | `@Jafetvu` | W9-03; W9-12 recomendado | Integrado (PR #85) |
| #60 | CRUD `MealLog` con ownership y 404 | `@Jafetvu` | W9-03 | Integrado, issue abierta (PR #96) |
| #61 | `StorageService` local con ACL por dueño | `@AlexReyes03` | W9-03 | Integrado |
| #62 | P1: `image_picker` y subida mínima | `@M4ltin12` | W9-15; `docs/permisos.md` | Integrado (PR #89) |
| #63 | Lista y creación de `WorkoutSession` en Flutter | `@M4ltin12` | W9-07; W9-13 | Integrado (PR #90) |
| #64 | Planeación de la semana W9 | `@Loreley100` | #28 (W8-27) | En curso (esta tarea) |

**Nota sobre responsables.** Los responsables de #48, #49, #50 y #61 se tomaron del campo *Assignees* de GitHub. Las descripciones originales de esas issues mencionan otros handles, por lo que la asignación requiere confirmación del equipo.

**Evidencia de integración**

| Issue | Evidencia verificable en `main` |
| --- | --- |
| #47 | `fit_track_api/src/main.ts` usa `process.env.PORT ?? 3000`; `.env.example` fija `PORT=3000`; `Dockerfile` expone 3000; Flutter usa `http://10.0.2.2:3000` por defecto. |
| #48–#50 | Commit `813a656` (refresh, logout, guard y recuperación) es ancestro de `main`; módulos `auth`, `users` y `mail` presentes. |
| #51–#54 | Router, splash, `SessionStorage` y `ApiClient` con refresh único en `fit_track_360/lib`. |
| #55 | PR #76 fusionado; `home_shell_page.dart` y su prueba. |
| #56 | PR #77 fusionado; `test/auth/auth.service.spec.ts` con 9 pruebas en el runner. |
| #57 | PR #97 abierto sobre la rama `docs/w9-11-checklist-h2` (`e28b31a`); no es ancestro de `main`. |
| #58 | PR #78 fusionado (`8285b5a`); modelo y seed de ejercicios. |
| #59 | PR #85 fusionado (`4e446b1`); módulo `workouts`. |
| #60 | PR #96 fusionado (`bb32faf`); módulo `meals`. |
| #61 | Commit `bf9722b` es ancestro de `main`; `src/storage/` con aislamiento por `userId`. |
| #62 | PR #89 fusionado (`0354c0d`); `progress_photo_page.dart` con `image_picker`. |
| #63 | PR #90 fusionado (`04a79ff`); `features/workouts` en Flutter. |
| #64 | Este documento. |

## C. Dependencias

1. **API y PostgreSQL antes de validar F1.** #47, #48–#50 y #55–#56 solo se pueden demostrar con el API levantado y la base migrada. Sin eso, las pruebas quedan en dobles en memoria.
2. **Autenticación y ownership antes de los endpoints protegidos.** #49 habilita el filtrado por dueño que usan #59, #60 y #61. Un endpoint sin `JwtAuthGuard` no puede considerarse completo.
3. **Storage API antes de la integración de fotografías.** #61 debe existir para que #62 suba la imagen; la pantalla ya consume `POST /api/v1/storage/files`.
4. **Sesión y router antes del shell y de las pantallas.** #51 y #53 habilitan #55 y #63; sin restauración de sesión el shell no puede sostener la navegación.
5. **Catálogo antes de workouts con series.** #58 es recomendable antes de #59 si las series referencian `Exercise`; el CRUD de workouts ya está integrado.
6. **Mailpit antes de demostrar recuperación.** #50 responde 200 aunque no haya SMTP; la dependencia real es W8-07 (servicio Mailpit en Compose).
7. **Checklist H2 y planeación.** #57 depende de #31 (W8-30); #64 depende de #28 (W8-27), ya integrada mediante el PR #65.

## D. Riesgos

| Riesgo | Situación verificada al 2026-11-06 | Impacto | Seguimiento |
| --- | --- | --- | --- |
| SMTP / Mailpit | `fit_track_api/docker-compose.yml` solo define `postgres`; no hay Mailpit. Sin `SMTP_HOST`, `MailService` no envía y `forgot` responde 200. | No se puede demostrar la recepción del código ni el reset completo. | Vigente. Agregar Mailpit (W8-07) antes de la demo. |
| Puertos Flutter / NestJS | API en 3000 (`main.ts`, `.env.example`, `Dockerfile`) y Flutter en `10.0.2.2:3000`; el panel usa `adb reverse` en el mismo puerto. | Riesgo original de desalineación resuelto en código. | Resuelto en código; #47 sigue abierta y Compose aún no tiene servicio `api`. |
| Respuestas 404 para recursos ajenos | `workouts`, `meals` y `storage` resuelven por `userId` y responden 404; falta la prueba con dos cuentas. | Sin esa prueba no se puede afirmar que S4 está demostrado. | Vigente como validación pendiente. |
| Almacenamiento local vs nube | `StorageService` escribe en `UPLOAD_DIR/<userId>/`; no hay proveedor de objetos ni ACL del proveedor. | P1 mínimo avanza; el requisito completo de P1 sigue bloqueado. | Vigente. Depende de decidir el destino de nube, documentado en `docs/estado.md` y aún sin decisión. |
| Sobrecarga por trabajo de W8 | #8 (W8-07: servicio `api` y Mailpit en Compose) sigue abierto. La tarea de documentar criterios de nube (#16, W8-15) está cerrada, pero el destino no se ha decidido. | Varias tareas W9 no pueden cerrarse sin esos frentes. | Vigente. Revisar carga por integrante antes de asignar trabajo nuevo. |
| Configuración de PostgreSQL | `docker-compose.yml`, `.env.example` y el panel usan configuraciones de PostgreSQL diferentes. | Con una base nueva creada por Compose, el `DATABASE_URL` de ejemplo puede no coincidir. | Vigente. Unificar la configuración o usar el contenedor del panel. |
| Suite Flutter en rojo | `flutter test` falla en `cerrar sesion sin red limpia la sesion y va a login` porque la prueba busca `Cerrar sesion` y la UI usa `Cerrar sesión`. | El cierre de F1 no tiene una suite verde que lo respalde. | Vigente. Corregir la sincronía texto UI/prueba en una tarea aparte. |
| Issues abiertas con trabajo integrado | #47, #60 y #64 tienen cambios o entregables en curso, pero siguen abiertas; #57 tiene rama publicada sin merge. | El tablero no refleja el avance real. | Vigente. Actualizar estado al revisar cada PR. |

Riesgos que **ya no aplican** como bloqueo: falta de refresh/logout en el API, ausencia de `JwtAuthGuard`, ausencia de modelo `Exercise`, ausencia de CRUD de workouts y meals, y ausencia de selector de cámara/galería. Todos tienen implementación integrada en `main`.

## E. Seguimiento

| Campo | Registro |
| --- | --- |
| Fecha de corte | 2026-11-06 |
| Base revisada | `main` en `bb32faf` |
| Entregables esperados | F1 demostrable (registro, login, logout, restore, refresh, forgot/reset); base de F2 (`Exercise`, `WorkoutSession`, `MealLog`); `StorageService` y P1 mínimo. |
| Completado con evidencia | #48–#56, #58, #59, #61, #62 y #63 integrados en `main`; #60 integrado con issue abierta; #47 alineado en código. |
| Pendientes o bloqueos | Validación E2E de F1; Mailpit; servicio `api` en Compose; prueba de ownership con dos cuentas; nube y ACL para P1 completo; merge de #57; cierre de #47 y #60. |

**Relación con H2.** H2 es el hito académico de UTEZ y exige demostrar F1 y P1 ante el docente. W9 cubre la recuperación de ambos frentes, pero el corte sigue sin una ejecución E2E registrada: la evidencia disponible es código integrado, pruebas unitarias de `AuthService` y pruebas de widget parciales. El checklist de #57 es el documento que debe reflejar esa diferencia entre implementación y demostración.

**Confirmaciones pendientes del líder.** Falta confirmar si #47 y #60 deben cerrarse y si #57 se integra antes del corte de H2.
