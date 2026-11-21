import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../domain/progress_photo.dart';
import '../domain/progress_photo_errors.dart';
import '../domain/progress_photo_meta.dart';
import '../domain/progress_photos_repository.dart';
import 'state/progress_view_state.dart';

/// Motivo explícito del bloqueo de métricas (#122): el peso del check-in se
/// valida pero todavía no se persiste.
const String kMetricsBlockedReason =
    'Tu peso aún no se guarda: las métricas se guardarán cuando el backend '
    'de métricas corporales esté disponible (#122).';

/// ViewModel de Progreso: fotos vía [ProgressPhotosRepository]; métricas
/// bloqueadas por #122.
class ProgressViewModel extends ChangeNotifier {
  ProgressViewModel({required this._photos});

  final ProgressPhotosRepository _photos;

  bool _disposed = false;
  ProgressRange _range = ProgressRange.d30;

  /// Bloques de métricas: vacíos hasta #122 (sin preview inventado).
  ProgressSectionStatus chartStatus = ProgressSectionStatus.empty;
  ProgressSectionStatus historyStatus = ProgressSectionStatus.empty;
  ProgressSectionStatus checkInStatus = ProgressSectionStatus.data;
  ProgressSectionStatus comparisonStatus = ProgressSectionStatus.empty;

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
  bool sessionExpired = false;

  /// Fotos subidas en esta sesión (no hay GET list en el API).
  final List<ProgressPhotoMeta> _sessionPhotos = [];

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

  /// Recarga gráfica e historial del rango actual aunque no haya cambiado
  /// (usado por «Reintentar»). Sin serie de métricas (#122) quedan vacíos.
  void reloadMetrics() {
    chartStatus = ProgressSectionStatus.empty;
    historyStatus = ProgressSectionStatus.empty;
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

  /// Check-in: [draft] ya viene validado; sin #122 no se persiste el peso.
  /// Si hay foto, la sube a `/photos`.
  Future<void> submitCheckIn(ProgressCheckInDraft draft) async {
    sessionExpired = false;
    checkInFeedback = null;
    isSubmittingCheckIn = true;
    _notify();

    try {
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
    } on SessionExpiredException {
      sessionExpired = true;
      checkInFeedback = 'Sesión expirada.';
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
      _refreshComparisonSlots();
      _notify();
    } on SessionExpiredException {
      sessionExpired = true;
      _notify();
      rethrow;
    } on ProgressPhotoUnavailableException {
      // 404 ajena/inexistente: no rompe; se limpia local si estaba.
      _sessionPhotos.removeWhere((p) => p.id == photoId);
      _refreshComparisonSlots();
      _notify();
      rethrow;
    }
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
      weightLabel: 'Sin métrica',
      caption: 'Sesión actual',
    );
    currentPhotoSlot = sorted.length == 1
        ? null
        : ProgressPhotoPreviewSlot(
            label: 'Actual',
            dateLabel: _formatDay(last.createdAt),
            weightLabel: 'Sin métrica',
            caption: 'Sesión actual',
          );
    comparisonStatus = ProgressSectionStatus.data;
  }

  static String _formatDay(DateTime value) {
    final local = value.toLocal();
    const months = [
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
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  /// Expone estados AsyncState útiles para tests de VM.
  AsyncState<ProgressChartData> get chartAsync =>
      chartStatus == ProgressSectionStatus.empty
      ? const AsyncEmpty()
      : AsyncData(chartData);

  AsyncState<List<ProgressHistoryEntry>> get historyAsync =>
      historyStatus == ProgressSectionStatus.empty
      ? const AsyncEmpty()
      : AsyncData(historyEntries);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
