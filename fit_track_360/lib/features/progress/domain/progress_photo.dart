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
