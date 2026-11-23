import 'dart:io';

import 'package:fit_track_360/features/progress/domain/progress_photo_meta.dart';
import 'package:fit_track_360/features/progress/domain/progress_photos_repository.dart';

/// Doble en memoria de [ProgressPhotosRepository] para pruebas de VM y vista.
class FakeProgressPhotosRepository implements ProgressPhotosRepository {
  FakeProgressPhotosRepository({this.uploadError, this.deleteError});

  Object? uploadError;
  Object? deleteError;
  final List<File> uploaded = [];
  final List<String?> uploadedMetricIds = [];
  final List<String> deleted = [];

  @override
  Future<ProgressPhotoMeta> upload(
    File file, {
    String? metricId,
    String? mealId,
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    uploaded.add(file);
    uploadedMetricIds.add(metricId);
    final n = uploaded.length;
    return ProgressPhotoMeta(
      id: 'ph-$n',
      mimeType: 'image/jpeg',
      sizeBytes: 12,
      width: 1,
      height: 1,
      metricId: metricId,
      mealId: mealId,
      createdAt: DateTime.utc(2026, 11, 19, 12, n),
    );
  }

  @override
  Future<void> delete(String photoId) async {
    final error = deleteError;
    if (error != null) throw error;
    deleted.add(photoId);
  }
}
