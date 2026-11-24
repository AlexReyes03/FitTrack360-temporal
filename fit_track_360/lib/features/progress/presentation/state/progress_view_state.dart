// Tipos de estado y valores de la pantalla de Progreso. Viven fuera de
// `widgets/` para que el ViewModel no dependa de la capa visual.

/// Estado visual de cada sección de la pantalla de progreso.
enum ProgressSectionStatus { loading, data, empty, error }

/// Tono del aviso del check-in: éxito, aviso parcial (p. ej. peso guardado
/// pero foto fallida) o error. La vista lo pinta distinto.
enum ProgressFeedbackTone { success, warning, error }

/// Rangos de tiempo disponibles para la vista de progreso biométrico.
enum ProgressRange {
  d7('7d', 'Últimos 7 días'),
  d30('30d', 'Últimos 30 días'),
  d90('90d', 'Últimos 90 días'),
  y1('1y', 'Último año');

  const ProgressRange(this.label, this.description);

  final String label;
  final String description;
}

/// Punto visual para la gráfica placeholder de evolución de peso.
class ProgressChartPoint {
  const ProgressChartPoint({required this.label, required this.weightKg});

  final String label;
  final double weightKg;
}

/// Datos de presentación para la tarjeta de gráfica de peso.
class ProgressChartData {
  const ProgressChartData({
    required this.currentWeightKg,
    required this.periodDeltaKg,
    required this.averageWeightKg,
    required this.points,
  });

  final double currentWeightKg;
  final double periodDeltaKg;
  final double averageWeightKg;
  final List<ProgressChartPoint> points;
}

/// Registro visual de historial biométrico con variación semanal.
class ProgressHistoryEntry {
  const ProgressHistoryEntry({
    required this.dateLabel,
    required this.weightKg,
    this.weeklyDiffKg,
    this.note,
  });

  final String dateLabel;
  final double weightKg;
  final double? weeklyDiffKg;
  final String? note;
}

/// Datos de presentación para cada panel de comparación de fotos (Inicial / Actual).
class ProgressPhotoPreviewSlot {
  const ProgressPhotoPreviewSlot({
    required this.label,
    required this.dateLabel,
    required this.weightLabel,
    this.caption,
  });

  final String label;
  final String dateLabel;
  final String weightLabel;
  final String? caption;
}

/// Check-in validado por el formulario: [weightKg] ya es finito y está en
/// rango (ver `validateBodyWeightKg`).
class ProgressCheckInDraft {
  const ProgressCheckInDraft({
    required this.weightKg,
    required this.notesText,
    required this.hasPhotoSelected,
    this.bodyFatPercent,
    this.waistCm,
  });

  final double weightKg;
  final String notesText;
  final bool hasPhotoSelected;
  final double? bodyFatPercent;
  final double? waistCm;
}
