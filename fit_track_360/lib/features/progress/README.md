# progress

Métricas corporales y fotos de progreso (data/domain/presentation).

## Estado W12-11 (#130) — entrega parcial

### Desbloqueado (este PR)

- Ruta `/app/progreso` → `ProgressShellPage` + `ProgressPage` (UI Liquid Glass).
- Fotos vía `POST/GET/DELETE /api/v1/photos` (`ProgressPhotosApi`, implementa `domain/ProgressPhotosRepository`; el VM depende solo de la interfaz).
- El multipart declara el formato real de la imagen (jpeg/png/webp por firma o extensión); el API rechaza `application/octet-stream`.
- Tipos de estado de la vista en `presentation/state/progress_view_state.dart` (sin depender de `widgets/`).
- Check-in: peso validado en el formulario (número finito, 20–500 kg, coma o punto); todavía no se persiste y la vista lo dice.
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

## UX-09 (#229) — fotos, refresco y check-in

- `data/ProgressPhotoSessionStore`: registro en memoria de las fotos subidas en la sesión, compartido por `/app/foto`, el check-in y la comparación. `ProgressViewModel` lo escucha, así que una foto subida en `/app/foto` aparece en Progreso sin reiniciar. Se limpia al expirar la sesión. Al cerrar la app se pierde hasta que exista `GET /api/v1/photos`.
- `comparisonFromPhotos` (dominio): con una foto la comparación lleva solo la inicial, así que «Ver detalle» nunca abre una pantalla vacía.
- `/app/foto`: botón «Volver», hoja Cámara/Galería (sin «Continuar sin foto»), `PermissionDeniedNotice` si se niega la cámara, «Foto guardada» sin ID interno y CTA «Ver comparación».
- Check-in: hoja Cámara/Galería (la cámara pide permiso), miniatura de la foto elegida y acción «Quitar». El aviso usa `ProgressFeedbackTone` (éxito, aviso o error) con `ProgressStatusBanner`, que es privado de la feature y está pendiente de migrar al `StatusBanner` del DS en #222.
- La gráfica expone un resumen con `Semantics`. Las etiquetas del eje X se colocan con la misma geometría que el trazo.
