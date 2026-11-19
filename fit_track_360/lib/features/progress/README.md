# progress

Métricas corporales y fotos de progreso (data/domain/presentation).

## Estado W12-11 (#130) — entrega parcial

### Desbloqueado (este PR)

- Ruta `/app/progreso` → `ProgressShellPage` + `ProgressPage` (UI Liquid Glass).
- Fotos vía `POST/GET/DELETE /api/v1/photos` (`ProgressPhotosApi`).
- Upload de `ProgressPhotoPage` migrado desde `/storage/files` a `/photos`.
- 404 de foto ajena/inexistente → `ProgressPhotoUnavailableException` ("Foto no disponible"), sin 403.
- Comparación: solo con fotos subidas en la sesión actual (no hay listado en el API).

### Bloqueado por #122 (CRUD métricas Nest)

- Check-in de peso / `BodyMetric` persistido.
- Historial con diff vs semana previa.
- Gráfica real y filtro 7d–1y con serie de métricas.
- `metricId` opcional en upload (listo en cliente; sin IDs de métrica hasta #122).

### Gap adicional de fotos

- No existe `GET /api/v1/photos` (list). La comparación inicial vs actual no puede armarse desde el servidor sin IDs previos o listado.
