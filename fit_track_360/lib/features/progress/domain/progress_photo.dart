import 'progress_photo_meta.dart';

class ProgressPhotoRef {
  const ProgressPhotoRef({required this.id, this.takenAt});

  final String id;
  final DateTime? takenAt;
}

/// Las referencias las elige el historial; la vista no infiere inicial ni actual.
class PhotoComparison {
  const PhotoComparison({this.initial, this.current});

  final ProgressPhotoRef? initial;
  final ProgressPhotoRef? current;

  bool get isEmpty => initial == null && current == null;
}

/// Comparación con la foto más antigua (inicial) y la más reciente (actual).
/// Con una sola foto solo hay inicial; sin fotos devuelve `null`.
PhotoComparison? comparisonFromPhotos(Iterable<ProgressPhotoMeta> photos) {
  if (photos.isEmpty) return null;
  final sorted = [...photos]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final first = sorted.first;
  final last = sorted.last;
  return PhotoComparison(
    initial: ProgressPhotoRef(id: first.id, takenAt: first.createdAt),
    current: sorted.length < 2
        ? null
        : ProgressPhotoRef(id: last.id, takenAt: last.createdAt),
  );
}
