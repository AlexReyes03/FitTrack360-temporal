/// Medición biométrica tal como la devuelve `GET /api/v1/progress`.
class BodyMetric {
  const BodyMetric({
    required this.id,
    required this.userId,
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPercent,
    this.waistCm,
  });

  factory BodyMetric.fromJson(Map<String, dynamic> json) {
    return BodyMetric(
      id: json['id'] as String,
      userId: json['userId'] as String,
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      weightKg: _asDouble(json['weightKg']),
      bodyFatPercent: _asDouble(json['bodyFatPercent']),
      waistCm: _asDouble(json['waistCm']),
    );
  }

  final String id;
  final String userId;
  final DateTime measuredAt;

  /// El esquema de Prisma permite null, aunque `POST /progress` exige peso.
  final double? weightKg;
  final double? bodyFatPercent;
  final double? waistCm;
}

/// Punto de `GET /api/v1/progress/series` (orden ascendente por `measuredAt`).
class ProgressSeriesPoint {
  const ProgressSeriesPoint({
    required this.id,
    required this.date,
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPercent,
    this.waistCm,
  });

  factory ProgressSeriesPoint.fromJson(Map<String, dynamic> json) {
    final measuredAt = DateTime.parse(json['measuredAt'] as String);
    return ProgressSeriesPoint(
      id: json['id'] as String,
      date: json['date'] as String? ?? _dateOnly(measuredAt),
      measuredAt: measuredAt,
      weightKg: _asDouble(json['weightKg']),
      bodyFatPercent: _asDouble(json['bodyFatPercent']),
      waistCm: _asDouble(json['waistCm']),
    );
  }

  final String id;

  /// Fecha calendario UTC en formato `YYYY-MM-DD`.
  final String date;
  final DateTime measuredAt;
  final double? weightKg;
  final double? bodyFatPercent;
  final double? waistCm;
}

/// Respuesta completa de `GET /api/v1/progress/series`.
class ProgressSeries {
  const ProgressSeries({
    required this.from,
    required this.to,
    required this.count,
    required this.latest,
    required this.points,
  });

  factory ProgressSeries.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = rawPoints is List
        ? rawPoints
              .whereType<Map<String, dynamic>>()
              .map(ProgressSeriesPoint.fromJson)
              .toList(growable: false)
        : const <ProgressSeriesPoint>[];
    final rawLatest = json['latest'];
    return ProgressSeries(
      from: json['from'] as String?,
      to: json['to'] as String?,
      count: (json['count'] as num?)?.toInt() ?? points.length,
      latest: rawLatest is Map<String, dynamic>
          ? BodyMetric.fromJson(rawLatest)
          : null,
      points: points,
    );
  }

  final String? from;
  final String? to;
  final int count;
  final BodyMetric? latest;
  final List<ProgressSeriesPoint> points;
}

/// Cuerpo de `POST /api/v1/progress`.
///
/// Solo incluye los campos que `CreateBodyMetricDto` acepta con
/// `forbidNonWhitelisted: true`; en particular nunca envía `notes`.
class CreateBodyMetricInput {
  const CreateBodyMetricInput({
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPercent,
    this.waistCm,
  });

  final DateTime measuredAt;
  final double weightKg;
  final double? bodyFatPercent;
  final double? waistCm;

  Map<String, dynamic> toJson() => {
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    'weightKg': weightKg,
    if (bodyFatPercent != null) 'bodyFatPercent': bodyFatPercent,
    if (waistCm != null) 'waistCm': waistCm,
  };
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _dateOnly(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-$month-$day';
}
