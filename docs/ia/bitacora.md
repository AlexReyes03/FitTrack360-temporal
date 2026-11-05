# Bitácora de uso de IA — FitTrack360

> **Nivel de uso de IA:** Nivel 4 — IA completa (enunciado del proyecto integrador).
> Cada integrante registra aquí los prompts relevantes y lo declara en cada entrega.
> Cada quien debe poder explicar y modificar en vivo el código que aparece a su nombre.

## Reglas

1. **Nunca** pegues credenciales, llaves, tokens, contraseñas, archivos `.env` ni datos personales reales en una herramienta de IA ni en esta bitácora.
2. Una fila por tarea o sesión relevante, no por cada mensaje.
3. Resume el prompt en una o dos líneas; no pegues conversaciones completas.
4. Anota lo que **sí** quedó en el repo (archivos, PR o commit) y lo que tuviste que corregir a mano.
5. Si la IA propuso algo que se descartó, regístralo también en «Resultado».

## Registro

| Fecha | Persona | Herramienta / modelo | Tarea o issue | Resumen del prompt | Archivos tocados | Resultado (aceptado / ajustado / descartado y por qué) | PR / commit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-10-31 | Daniela Carrate | Claude Code (Claude Opus 5.5) | Contexto (#22–#26) | Revisar las issues asignadas y mapear el repo para conocer reglas, arquitectura y deuda técnica antes de programar. | `.planning/codebase/` (solo local, no se versiona) | Aceptado como referencia. Se contrastó con el design system, el plan maestro, los hooks y el enunciado. | No aplica |
| 2026-10-31 | Daniela Carrate | Claude Code (Claude Opus 5.5) | #22 | Crear el árbol `core/` y `features/*` con `data/domain/presentation`, sin código de negocio. | `fit_track_360/lib/core/README.md`, `fit_track_360/lib/features/*` | Aceptado. Verificado con `flutter analyze`. | #36 / `32042f5` |
| 2026-10-31 | Daniela Carrate | Claude Code (Claude Opus 5.5) | #23 | Implementar `AsyncState<T>` sealed con cargando, datos, error y vacío, sin dependencias nuevas, y sus pruebas. | `fit_track_360/lib/core/async_state.dart`, `fit_track_360/test/core/async_state_test.dart` | Ajustado: la revisión detectó archivos de iOS generados incluidos por error y se quitaron antes del merge. 7 pruebas en verde. Aún sin cablear a pantallas. | #37 / `8a51fb2` |
| 2026-10-31 | Daniela Carrate | Claude Code (Claude Opus 5.5) | #24 | Crear un banner offline no bloqueante con Reintentar, siguiendo el design system, y probarlo en emulador con modo avión. | `fit_track_360/lib/core/network/connectivity_service.dart`, `fit_track_360/lib/core/widgets/offline_banner.dart`, `fit_track_360/lib/main.dart`, `fit_track_360/pubspec.yaml`, `fit_track_360/pubspec.lock`, `fit_track_360/test/core/widgets/offline_banner_test.dart` | Ajustado: los colores warning quedaron locales para no chocar con #17 y se dejaron fuera los archivos de iOS generados. 4 pruebas en verde y prueba en emulador Android. | #38 / `857eecb` |
| 2026-10-31 | Daniela Carrate | Claude Code (Claude Opus 5.5) | #25 | Redactar el borrador de permisos con las columnas de la sección 4.5 del enunciado para P1–P3 y O1, O5, O7, O10. | `docs/permisos.md` | Ajustado: se corrigió el permiso de cámara de P1 antes de abrir el PR. La retención de O5 quedó «por definir»; evidencia y versiones de paquetes, «pendiente». | #39 / `a07ac6d` |
| 2026-10-31 | Daniela Carrate | Claude Code (Claude Opus 5.5) | #26 | Crear plantillas de bitácora y de estado del proyecto, sin historial ni métricas inventadas. | `docs/ia/bitacora.md`, `docs/estado.md` | Aceptado. El blocker de puertos se comprobó en el código antes de anotarlo. | #40 / `425d97a` |
| 2026-10-31 | Daniela Carrate | Claude Code (Claude Opus 5.5) | Verificación (#36–#40) | Fusionar los 5 PRs en una rama temporal y probar registro, login, sesión y modo avión contra el API y Postgres. | Ninguno (rama temporal local) | Sin regresiones en esos flujos. La prueba es anterior a #41, así que no cubre el compose actual. Los tests de Jest del API ya fallaban en `main` (TS5011). | No aplica |
| 2026-11-02 | Daniela Carrate | Claude Code (Claude Opus 5.5) | Seguimiento W8-25 | Actualizar la bitácora y el estado con lo fusionado, revisando primero el código en `main`. | `docs/ia/bitacora.md`, `docs/estado.md` | Ajustado: la revisión encontró efectos de #41 y de #42–#45 en `main`, que se registraron como blockers. | #46 |
| 2026-11-04 | Daniela Carrate | Claude Code (Claude Opus 5.5) | #55 | Cablear `OfflineBanner` en el shell autenticado sin romper restaurar sesión ni logout, y probarlo en emulador. | `fit_track_360/lib/features/home/presentation/home_shell_page.dart`, `fit_track_360/test/features/home/home_shell_page_test.dart` | Ajustado: se agregó un candado contra cargas simultáneas de perfil y la recarga al reconectar. Código y pruebas se escribieron juntos, no test-first; se validó con 6 mutaciones, todas detectadas, y prueba en emulador con modo avión. | #76 |
| 2026-11-04 | Daniela Carrate | Claude Code (Claude Opus 5.5) | #56 | Escribir pruebas de `AuthService` primero, por reglas de negocio, sin base de datos real, y dejar funcionando el runner. | `fit_track_api/test/auth/auth.service.spec.ts`, `fit_track_api/test/app.controller.spec.ts`, `fit_track_api/jest.config.ts`, `fit_track_api/package.json`, `fit_track_api/tsconfig.spec.json` | Ajustado: la IA diagnosticó mal la causa dos veces; la real es que NestJS 12 solo publica ESM. Se descartó `@jest/globals` por un enlace roto en pnpm y se usaron fakes en memoria. El servicio ya existía: las pruebas lo caracterizan y se validaron con 7 mutaciones, todas detectadas. | #77 |
| 2026-11-04 | Daniela Carrate | Claude Code (Claude Opus 5.5) | Panel `pnpm dev` | Probar el panel a pedido de Alex, sin afectar contenedores de otros proyectos. | Ninguno | Hallazgo: el panel toma como propio cualquier contenedor con 5432 interno y Space lo detendría. Se comprobó con un `docker` falso que solo registra comandos. Postgres y API del panel quedaron sin probar en esa máquina. | No aplica |

## Plantilla para entradas largas (opcional)

Usa esta sección cuando una fila no alcanza (por ejemplo, una decisión de arquitectura apoyada en IA).

```markdown
### AAAA-MM-DD — Persona — Issue #00

- **Herramienta / modelo:**
- **Objetivo:**
- **Prompt (resumen):**
- **Archivos tocados:**
- **Qué se aceptó:**
- **Qué se corrigió a mano y por qué:**
- **Cómo se verificó:** (tests, analyze, prueba en emulador o dispositivo)
- **PR / commit:**
```
