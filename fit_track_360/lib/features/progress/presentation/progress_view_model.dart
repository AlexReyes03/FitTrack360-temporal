import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../domain/body_metric.dart';
import '../domain/progress_metric_errors.dart';
import '../domain/progress_metrics_repository.dart';
import '../domain/progress_photo.dart';
import '../domain/progress_photo_errors.dart';
import '../domain/progress_photo_meta.dart';
import '../domain/progress_photos_repository.dart';
import 'state/progress_view_state.dart';

/// Mensaje de degradación cuando no se inyecta [ProgressMetricsRepository].
/// La app real siempre lo inyecta desde `ProgressShellPage`; las pruebas de
/// widgets previas a la conexión real conservan este comportamiento.
const String kMetricsBlockedReason =
    'Tu peso aún no se guarda: las métricas se guardarán cuando el backend '
    'de métricas corporales esté disponible (#122).';

/// ViewModel de Progreso: fotos vía [ProgressPhotosRepository] y métricas
/// biométricas vía [ProgressMetricsRepository].
class ProgressViewModel extends ChangeNotifier {
  ProgressViewModel({
    required this._photos,
    this._metrics,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ProgressPhotosRepository _photos;
  final ProgressMetricsRepository? _metrics;
  final DateTime Function() _clock;

  bool _disposed = false;
  ProgressRange _range = ProgressRange.d30;
  int _metricsRequest = 0;

  ProgressSectionStatus chartStatus = ProgressSectionStatus.empty;
  ProgressSectionStatus historyStatus = ProgressSectionStatus.empty;
  ProgressSectionStatus checkInStatus = ProgressSectionStatus.data;
  ProgressSectionStatus comparisonStatus = ProgressSectionStatus.empty;

  Object? chartError;
  Object? historyError;

  ProgressChartData chartData = const ProgressChartData(
    currentWeightKg: 0,
    periodDeltaKg: 0,
    averageWeightKg: 0,
    points: [],
  );
  List<ProgressHistoryEntry> historyEntries = const [];

  String? selectedCheckInPhotoLabel;
  File? _pendingPhotoFile;
  bool isSubmittingCheckIn = false;
  String? checkInFeedback;

  /// Aumenta cada vez que una métrica del check-in queda guardada. El
  /// formulario lo observa para limpiarse sin depender del texto del aviso.
  int checkInSavedCount = 0;
  bool sessionExpired = false;

  /// Fotos subidas en esta sesión (no hay GET list en el API).
  final List<ProgressPhotoMeta> _sessionPhotos = [];

  /// Peso de la métrica vinculada a cada foto de la sesión.
  final Map<String, String> _photoWeightsById = {};

  /// Nota local del check-in asociada a la métrica (no se envía al API).
  final Map<String, String> _notesByMetricId = {};

  ProgressPhotoPreviewSlot? initialPhotoSlot;
  ProgressPhotoPreviewSlot? currentPhotoSlot;

  ProgressRange get range => _range;
  List<ProgressPhotoMeta> get sessionPhotos =>
      List.unmodifiable(_sessionPhotos);

  /// Comparación con las dos fotos más antiguas/recientes de la sesión.
  PhotoComparison? get sessionComparison {
    if (_sessionPhotos.length < 2) return null;
    final sorted = [..._sessionPhotos]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return PhotoComparison(
      initial: ProgressPhotoRef(
        id: sorted.first.id,
        takenAt: sorted.first.createdAt,
      ),
      current: ProgressPhotoRef(
        id: sorted.last.id,
        takenAt: sorted.last.createdAt,
      ),
    );
  }

  void setRange(ProgressRange range) {
    if (_range == range) return;
    _range = range;
    reloadMetrics();
  }

  /// Recarga gráfica e historial del rango actual (también usado por
  /// «Reintentar»). Sin repositorio de métricas quedan vacíos.
  Future<void> reloadMetrics() async {
    final metrics = _metrics;
    final request = ++_metricsRequest;

    if (metrics == null) {
      chartStatus = ProgressSectionStatus.empty;
      historyStatus = ProgressSectionStatus.empty;
      chartError = null;
      historyError = null;
      _notify();
      return;
    }

    sessionExpired = false;
    chartStatus = ProgressSectionStatus.loading;
    historyStatus = ProgressSectionStatus.loading;
    chartError = null;
    historyError = null;
    _notify();

    final range = _rangeFor(_range);
    try {
      final results = await Future.wait<Object>([
        metrics.getSeries(from: range.from, to: range.to),
        // Margen extra para que la entrada más antigua del rango también
        // tenga contra qué calcular su diferencia semanal.
        metrics.listHistory(from: range.historyFrom, to: range.to),
      ]);
      if (_disposed || request != _metricsRequest) return;
      _applySeries(results[0] as ProgressSeries);
      _applyHistory(
        results[1] as List<BodyMetric>,
        visibleFrom: range.fromDate,
      );
    } on SessionExpiredException catch (failure) {
      if (_disposed || request != _metricsRequest) return;
      sessionExpired = true;
      chartStatus = ProgressSectionStatus.error;
      historyStatus = ProgressSectionStatus.error;
      chartError = failure;
      historyError = failure;
    } catch (failure) {
      if (_disposed || request != _metricsRequest) return;
      chartStatus = ProgressSectionStatus.error;
      historyStatus = ProgressSectionStatus.error;
      chartError = failure;
      historyError = failure;
    }
    _notify();
  }

  /// Recalcula la comparación con las fotos de la sesión («Reintentar»).
  void refreshComparison() {
    _refreshComparisonSlots();
    _notify();
  }

  void selectPendingPhoto(File file, {required String label}) {
    _pendingPhotoFile = file;
    selectedCheckInPhotoLabel = label;
    checkInFeedback = null;
    _notify();
  }

  void clearPendingPhoto() {
    _pendingPhotoFile = null;
    selectedCheckInPhotoLabel = null;
    _notify();
  }

  /// Check-in: [draft] ya viene validado. Crea la métrica, sube la foto
  /// vinculada con `metricId`, guarda la nota local y recarga la vista.
  Future<void> submitCheckIn(ProgressCheckInDraft draft) async {
    if (isSubmittingCheckIn) return;
    sessionExpired = false;
    checkInFeedback = null;
    isSubmittingCheckIn = true;
    _notify();

    try {
      final metrics = _metrics;
      if (metrics == null) {
        await _submitLegacyCheckIn();
        return;
      }

      final created = await metrics.create(
        CreateBodyMetricInput(
          measuredAt: _clock(),
          weightKg: draft.weightKg,
          bodyFatPercent: draft.bodyFatPercent,
          waistCm: draft.waistCm,
        ),
      );
      if (_disposed) return;

      // La métrica ya existe: a partir de aquí el formulario se limpia y el
      // historial se recarga aunque la foto falle, para no duplicarla.
      checkInSavedCount++;
      final note = draft.notesText.trim();
      if (note.isNotEmpty) _notesByMetricId[created.id] = note;

      final photoFailure = await _uploadCheckInPhoto(
        created.id,
        created.weightKg ?? draft.weightKg,
      );
      if (_disposed) return;

      await reloadMetrics();
      if (_disposed) return;
      if (sessionExpired) {
        checkInFeedback = 'Sesión expirada.';
      } else if (photoFailure != null) {
        checkInFeedback =
            'Tu peso se guardó, pero la foto no se pudo subir '
            '($photoFailure). Puedes agregarla desde «Agregar foto».';
      } else {
        checkInFeedback = 'Check-in registrado correctamente.';
      }
    } on SessionExpiredException {
      sessionExpired = true;
      checkInFeedback = 'Sesión expirada.';
    } on ProgressMetricException catch (error) {
      checkInFeedback = error.message;
    } on ProgressPhotoUnavailableException {
      checkInFeedback = 'Foto no disponible.';
    } on ProgressPhotoException catch (error) {
      checkInFeedback = error.message;
    } catch (_) {
      checkInFeedback = 'No se pudo completar el check-in.';
    } finally {
      isSubmittingCheckIn = false;
      _notify();
    }
  }

  /// Sube la foto pendiente vinculada a [metricId]. Devuelve el motivo si
  /// falla (la métrica ya quedó guardada) o `null` si no hubo error.
  Future<String?> _uploadCheckInPhoto(String metricId, double weightKg) async {
    final file = _pendingPhotoFile;
    if (file == null) return null;
    _pendingPhotoFile = null;
    selectedCheckInPhotoLabel = null;
    try {
      final meta = await _photos.upload(file, metricId: metricId);
      if (_disposed) return null;
      _sessionPhotos.add(meta);
      _photoWeightsById[meta.id] = _weightLabel(weightKg);
      _refreshComparisonSlots();
      return null;
    } on SessionExpiredException {
      rethrow;
    } on ProgressPhotoUnavailableException {
      return 'foto no disponible';
    } on ProgressPhotoException catch (error) {
      return error.message;
    } catch (_) {
      return 'error de conexión';
    }
  }

  /// Comportamiento previo a #130 cuando no hay repositorio de métricas.
  Future<void> _submitLegacyCheckIn() async {
    final file = _pendingPhotoFile;
    if (file != null) {
      final meta = await _photos.upload(file);
      if (_disposed) return;
      _sessionPhotos.add(meta);
      _pendingPhotoFile = null;
      selectedCheckInPhotoLabel = null;
      _refreshComparisonSlots();
      checkInFeedback = 'Foto guardada. $kMetricsBlockedReason';
    } else {
      checkInFeedback = kMetricsBlockedReason;
    }
  }

  /// Subida directa de foto de progreso (sin métrica).
  Future<ProgressPhotoMeta?> uploadProgressPhoto(File file) async {
    sessionExpired = false;
    try {
      final meta = await _photos.upload(file);
      if (_disposed) return meta;
      _sessionPhotos.add(meta);
      _refreshComparisonSlots();
      _notify();
      return meta;
    } on SessionExpiredException {
      sessionExpired = true;
      _notify();
      rethrow;
    }
  }

  Future<void> deletePhoto(String photoId) async {
    sessionExpired = false;
    try {
      await _photos.delete(photoId);
      if (_disposed) return;
      _sessionPhotos.removeWhere((p) => p.id == photoId);
      _photoWeightsById.remove(photoId);
      _refreshComparisonSlots();
      _notify();
    } on SessionExpiredException {
      sessionExpired = true;
      _notify();
      rethrow;
    } on ProgressPhotoUnavailableException {
      // 404 ajena/inexistente: no rompe; se limpia local si estaba.
      _sessionPhotos.removeWhere((p) => p.id == photoId);
      _photoWeightsById.remove(photoId);
      _refreshComparisonSlots();
      _notify();
      rethrow;
    }
  }

  void _applySeries(ProgressSeries series) {
    final weighted =
        series.points.where((point) => point.weightKg != null).toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    if (weighted.isEmpty) {
      chartData = const ProgressChartData(
        currentWeightKg: 0,
        periodDeltaKg: 0,
        averageWeightKg: 0,
        points: [],
      );
      chartStatus = ProgressSectionStatus.empty;
      return;
    }

    final values = [for (final point in weighted) point.weightKg!];
    final current = values.last;
    final average = values.reduce((a, b) => a + b) / values.length;

    chartData = ProgressChartData(
      currentWeightKg: current,
      periodDeltaKg: current - values.first,
      averageWeightKg: average,
      points: [
        for (final point in weighted)
          ProgressChartPoint(
            label: _shortDate(point.measuredAt),
            weightKg: point.weightKg!,
          ),
      ],
    );
    chartStatus = ProgressSectionStatus.data;
  }

  void _applyHistory(
    List<BodyMetric> metrics, {
    required DateTime visibleFrom,
  }) {
    final sorted = [...metrics]
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    final weighted = sorted.where((metric) => metric.weightKg != null).toList();
    final visibleCount = weighted
        .where((metric) => !metric.measuredAt.toUtc().isBefore(visibleFrom))
        .length;

    if (visibleCount == 0) {
      historyEntries = const [];
      historyStatus = ProgressSectionStatus.empty;
      return;
    }

    historyEntries = [
      for (var index = 0; index < visibleCount; index++)
        ProgressHistoryEntry(
          dateLabel: _formatDay(weighted[index].measuredAt),
          weightKg: weighted[index].weightKg!,
          weeklyDiffKg: _weeklyDiff(weighted, index),
          note: _noteFor(weighted[index]),
        ),
    ];
    historyStatus = ProgressSectionStatus.data;
  }

  /// Compara contra la medición más cercana a `measuredAt - 7 días`. Si
  /// ninguna cae dentro de ±3 días no hay referencia semanal (`null`, que la
  /// UI muestra como «Base»).
  double? _weeklyDiff(List<BodyMetric> metrics, int index) {
    final currentWeight = metrics[index].weightKg;
    if (currentWeight == null || index + 1 >= metrics.length) return null;

    final target = metrics[index].measuredAt.subtract(const Duration(days: 7));
    BodyMetric? comparator;
    var bestDistance = const Duration(days: 3).inHours;
    for (final candidate in metrics.skip(index + 1)) {
      final distance = candidate.measuredAt.difference(target).inHours.abs();
      if (distance <= bestDistance) {
        bestDistance = distance;
        comparator = candidate;
      }
    }

    final comparatorWeight = comparator?.weightKg;
    if (comparatorWeight == null) return null;
    return currentWeight - comparatorWeight;
  }

  String? _noteFor(BodyMetric metric) {
    final parts = <String>[];
    final fat = metric.bodyFatPercent;
    if (fat != null) parts.add('Grasa: ${_decimal(fat)}%');
    final waist = metric.waistCm;
    if (waist != null) parts.add('Cintura: ${_decimal(waist)} cm');
    final localNote = _notesByMetricId[metric.id]?.trim();
    if (localNote != null && localNote.isNotEmpty) parts.add(localNote);
    return parts.isEmpty ? null : parts.join(' | ');
  }

  void _refreshComparisonSlots() {
    if (_sessionPhotos.isEmpty) {
      comparisonStatus = ProgressSectionStatus.empty;
      initialPhotoSlot = null;
      currentPhotoSlot = null;
      return;
    }
    final sorted = [..._sessionPhotos]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first;
    final last = sorted.last;
    initialPhotoSlot = ProgressPhotoPreviewSlot(
      label: 'Inicial',
      dateLabel: _formatDay(first.createdAt),
      weightLabel: _photoWeightsById[first.id] ?? 'Sin métrica',
      caption: 'Sesión actual',
    );
    currentPhotoSlot = sorted.length == 1
        ? null
        : ProgressPhotoPreviewSlot(
            label: 'Actual',
            dateLabel: _formatDay(last.createdAt),
            weightLabel: _photoWeightsById[last.id] ?? 'Sin métrica',
            caption: 'Sesión actual',
          );
    comparisonStatus = ProgressSectionStatus.data;
  }

  /// Días extra de historial para calcular la diferencia semanal de la
  /// entrada más antigua del rango (7 días ± 3 de tolerancia).
  static const int _historyMarginDays = 10;

  ({String from, String historyFrom, DateTime fromDate, String to}) _rangeFor(
    ProgressRange range,
  ) {
    final now = _clock().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final days = switch (range) {
      ProgressRange.d7 => 6,
      ProgressRange.d30 => 29,
      ProgressRange.d90 => 89,
      ProgressRange.y1 => 364,
    };
    final fromDate = today.subtract(Duration(days: days));
    return (
      from: _dateParam(fromDate),
      historyFrom: _dateParam(
        fromDate.subtract(const Duration(days: _historyMarginDays)),
      ),
      fromDate: fromDate,
      to: _dateParam(today),
    );
  }

  static String _dateParam(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static String _shortDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
  }

  static String _weightLabel(double value) => '${value.toStringAsFixed(1)} kg';

  static String _decimal(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  static String _formatDay(DateTime value) {
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// Expone estados AsyncState útiles para tests de VM.
  AsyncState<ProgressChartData> get chartAsync => switch (chartStatus) {
    ProgressSectionStatus.loading => const AsyncLoading<ProgressChartData>(),
    ProgressSectionStatus.data => AsyncData(chartData),
    ProgressSectionStatus.error => AsyncError(
      chartError ??
          const ProgressMetricRequestException(
            'No se pudieron cargar las métricas',
          ),
    ),
    ProgressSectionStatus.empty => const AsyncEmpty<ProgressChartData>(),
  };

  AsyncState<List<ProgressHistoryEntry>> get historyAsync =>
      switch (historyStatus) {
        ProgressSectionStatus.loading =>
          const AsyncLoading<List<ProgressHistoryEntry>>(),
        ProgressSectionStatus.data => AsyncData(historyEntries),
        ProgressSectionStatus.error => AsyncError(
          historyError ??
              const ProgressMetricRequestException(
                'No se pudo cargar el historial',
              ),
        ),
        ProgressSectionStatus.empty =>
          const AsyncEmpty<List<ProgressHistoryEntry>>(),
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
