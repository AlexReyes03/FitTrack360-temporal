# Estado del proyecto — FitTrack360

> **Última actualización:** 2026-10-31 · **Actualizó:** Daniela Carrate (plantilla inicial, W8-25)
> Actualiza la fecha y tu nombre cada vez que edites. Describe solo lo que está en `main` o en un PR abierto; no adelantes avance.

## Qué hay

Integrado en `main`:

- Monorepo con pnpm, Husky (`pre-commit`, `commit-msg`, `pre-push`) y menú `pnpm dev` para levantar servicios.
- API NestJS (`fit_track_api`): Prisma con usuarios y tokens, Postgres en `docker-compose.yml`, imagen Docker, endpoints `POST /auth/register` y `POST /auth/login`.
- App Flutter (`fit_track_360`): pantallas de login y registro, `SessionStorage` con `flutter_secure_storage`, tokens de color del design system.

En PR abierto (pendiente de revisión): ver la lista de PRs del repositorio.

## Qué falta

Según `docs/plans/plan-maestro-fittrack360.md`:

- [ ] F1 completo: logout, restaurar sesión, recuperar contraseña (y refresh de tokens en el API).
- [ ] Shell de la app: router, tema dark completo, `AsyncState` (F6) y banner offline (F7) cableados en las pantallas.
- [ ] F2 en adelante: workouts, meals, progreso, catálogo de ejercicios.
- [ ] Capacidades P1, P2, P3 y optativas O1, O5, O7, O10 (ver `docs/permisos.md`).
- [ ] Pruebas mínimas: 8 unitarias, 4 de widget y 1 de integración, con un solo comando.
- [ ] `docs/planeacion`, `docs/pruebas.md`, `docs/distribucion/`.

## Blockers

| Blocker | Impacto | Responsable | Desde |
| --- | --- | --- | --- |
| Destino en la nube sin decidir (ver sección Nube) | Bloquea uploads de P1 con acceso del dueño y el despliegue | Equipo / Alex (W8-15) | 27 oct 2026 |
| Puerto del API inconsistente: `src/main.ts` usa 3000 por defecto, Docker y compose usan 3001, la app apunta a `http://10.0.2.2:3000` | La app no conecta al API cuando corre en Docker sin ajustar la URL | Por asignar | 31 oct 2026 |

## Próximos pasos

| Paso | Responsable | Issue |
| --- | --- | --- |
| Revisar y aprobar los PRs de W8-21 a W8-25 | Equipo | #22–#26 |

## Nube (pendiente W8-15)

> Sección reservada para Alex (W8-15). No decidir proveedor aquí sin el acuerdo del equipo.

- **Proveedor elegido:** pendiente
- **Criterios (plan maestro):** HTTPS público, Postgres persistente, almacenamiento de fotos con acceso solo del dueño, costo cero o crédito estudiantil.
- **Opciones evaluadas:** pendiente
- **URL del API:** pendiente
- **Fecha de decisión:** pendiente
