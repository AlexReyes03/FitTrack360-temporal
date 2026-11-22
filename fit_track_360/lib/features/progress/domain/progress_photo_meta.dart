/// Metadata que devuelve `POST /api/v1/photos` (sin bytes).
class ProgressPhotoMeta {
  const ProgressPhotoMeta({
    required this.id,
    required this.mimeType,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.createdAt,
    this.mealId,
    this.metricId,
  });

  final String id;
  final String mimeType;
  final int sizeBytes;
  final int width;
  final int height;
  final DateTime createdAt;
  final String? mealId;
  final String? metricId;

  factory ProgressPhotoMeta.fromJson(Map<String, dynamic> json) {
    return ProgressPhotoMeta(
      id: json['id'] as String,
      mimeType: json['mimeType'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      mealId: json['mealId'] as String?,
      metricId: json['metricId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
