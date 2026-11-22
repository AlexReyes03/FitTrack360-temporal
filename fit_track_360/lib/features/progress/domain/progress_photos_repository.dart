import 'dart:io';

import 'progress_photo_meta.dart';

/// Contrato de fotos de progreso (`/api/v1/photos`). Lo implementa la capa de
/// datos; el ViewModel depende solo de esta interfaz.
///
/// Errores: [ProgressPhotoUnavailableException] (404, sin filtrar existencia),
/// [ProgressPhotoValidationException], [ProgressPhotoUploadException] y
/// `SessionExpiredException`.
abstract interface class ProgressPhotosRepository {
  /// Sube una foto. [metricId] solo cuando exista el CRUD de métricas (#122).
  Future<ProgressPhotoMeta> upload(
    File file, {
    String? metricId,
    String? mealId,
  });

  Future<void> delete(String photoId);
}
