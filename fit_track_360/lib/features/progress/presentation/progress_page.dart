import 'package:flutter/material.dart';

import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import 'state/progress_view_state.dart';
import 'widgets/progress_checkin_card.dart';
import 'widgets/progress_history_card.dart';
import 'widgets/progress_photo_comparison_card.dart';
import 'widgets/progress_range_selector.dart';
import 'widgets/progress_weight_chart_card.dart';

/// Vista 9: Progreso biométrico e historial (maquetación Liquid Glass).
///
/// Vista pura: recibe estado y callbacks (ver `ProgressShellPage`). Los datos
/// de maqueta solo se muestran con [usePreviewData] explícito (demos/tests).
class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    this.initialRange = ProgressRange.d30,
    this.chartStatus = ProgressSectionStatus.data,
    this.checkInStatus = ProgressSectionStatus.data,
    this.historyStatus = ProgressSectionStatus.data,
    this.comparisonStatus = ProgressSectionStatus.data,
    this.chartData,
    this.historyEntries,
    this.initialPhotoSlot,
    this.currentPhotoSlot,
    this.usePreviewData = false,
    this.selectedCheckInPhotoLabel,
    this.isSubmittingCheckIn = false,
    this.checkInFeedback,
    this.checkInSavedCount = 0,
    this.onBack,
    this.onRangeChanged,
    this.onSelectCheckInPhoto,
    this.onSubmitCheckIn,
    this.onHistoryEntryTap,
    this.onComparePhotos,
    this.onAddPhoto,
    this.onRetryChart,
    this.onRetryCheckIn,
    this.onRetryHistory,
    this.onRetryComparison,
  });

  final ProgressRange initialRange;
  final ProgressSectionStatus chartStatus;
  final ProgressSectionStatus checkInStatus;
  final ProgressSectionStatus historyStatus;
  final ProgressSectionStatus comparisonStatus;
  final ProgressChartData? chartData;
  final List<ProgressHistoryEntry>? historyEntries;
  final ProgressPhotoPreviewSlot? initialPhotoSlot;
  final ProgressPhotoPreviewSlot? currentPhotoSlot;

  /// Rellena gráfica, historial y fotos con datos de maqueta cuando no se
  /// pasan. Producción lo deja en `false`.
  final bool usePreviewData;
  final String? selectedCheckInPhotoLabel;
  final bool isSubmittingCheckIn;
  final String? checkInFeedback;

  /// Métricas guardadas en esta sesión; limpia el formulario al cambiar.
  final int checkInSavedCount;
  final VoidCallback? onBack;
  final ValueChanged<ProgressRange>? onRangeChanged;
  final VoidCallback? onSelectCheckInPhoto;
  final ValueChanged<ProgressCheckInDraft>? onSubmitCheckIn;
  final ValueChanged<ProgressHistoryEntry>? onHistoryEntryTap;
  final VoidCallback? onComparePhotos;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onRetryChart;
  final VoidCallback? onRetryCheckIn;
  final VoidCallback? onRetryHistory;
  final VoidCallback? onRetryComparison;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late ProgressRange _selectedRange;

  static const ProgressChartData _emptyChart = ProgressChartData(
    currentWeightKg: 0,
    periodDeltaKg: 0,
    averageWeightKg: 0,
    points: [],
  );

  static const Map<ProgressRange, ProgressChartData> _previewChartByRange = {
    ProgressRange.d7: ProgressChartData(
      currentWeightKg: 74.2,
      periodDeltaKg: -0.4,
      averageWeightKg: 74.4,
      points: [
        ProgressChartPoint(label: 'Lun', weightKg: 74.6),
        ProgressChartPoint(label: 'Mié', weightKg: 74.5),
        ProgressChartPoint(label: 'Vie', weightKg: 74.3),
        ProgressChartPoint(label: 'Hoy', weightKg: 74.2),
      ],
    ),
    ProgressRange.d30: ProgressChartData(
      currentWeightKg: 74.2,
      periodDeltaKg: -1.4,
      averageWeightKg: 74.9,
      points: [
        ProgressChartPoint(label: 'Sem 1', weightKg: 75.6),
        ProgressChartPoint(label: 'Sem 2', weightKg: 75.1),
        ProgressChartPoint(label: 'Sem 3', weightKg: 74.6),
        ProgressChartPoint(label: 'Hoy', weightKg: 74.2),
      ],
    ),
    ProgressRange.d90: ProgressChartData(
      currentWeightKg: 74.2,
      periodDeltaKg: -3.2,
      averageWeightKg: 75.8,
      points: [
        ProgressChartPoint(label: 'Ene', weightKg: 77.4),
        ProgressChartPoint(label: 'Feb', weightKg: 76.1),
        ProgressChartPoint(label: 'Mar', weightKg: 74.9),
        ProgressChartPoint(label: 'Abr', weightKg: 74.2),
      ],
    ),
    ProgressRange.y1: ProgressChartData(
      currentWeightKg: 74.2,
      periodDeltaKg: -6.3,
      averageWeightKg: 77.1,
      points: [
        ProgressChartPoint(label: 'May', weightKg: 80.5),
        ProgressChartPoint(label: 'Ago', weightKg: 78.2),
        ProgressChartPoint(label: 'Nov', weightKg: 76.4),
        ProgressChartPoint(label: 'Feb', weightKg: 75.0),
        ProgressChartPoint(label: 'Hoy', weightKg: 74.2),
      ],
    ),
  };

  static const List<ProgressHistoryEntry> _previewHistory = [
    ProgressHistoryEntry(
      dateLabel: 'Hoy · 07:30',
      weightKg: 74.2,
      weeklyDiffKg: -0.4,
      note: 'En ayunas, buena recuperación',
    ),
    ProgressHistoryEntry(
      dateLabel: '12 abr',
      weightKg: 74.6,
      weeklyDiffKg: -0.5,
      note: 'Constante con hidratación y pasos',
    ),
    ProgressHistoryEntry(
      dateLabel: '05 abr',
      weightKg: 75.1,
      weeklyDiffKg: -0.5,
      note: 'Semana de descarga en fuerza',
    ),
    ProgressHistoryEntry(
      dateLabel: '29 mar',
      weightKg: 75.6,
      weeklyDiffKg: null,
      note: 'Registro base del mes',
    ),
  ];

  static const ProgressPhotoPreviewSlot _previewInitialPhoto =
      ProgressPhotoPreviewSlot(
        label: 'Inicial',
        dateLabel: '10 ene 2026',
        weightLabel: '77.4 kg',
        caption: 'Frente · Inicio',
      );

  static const ProgressPhotoPreviewSlot _previewCurrentPhoto =
      ProgressPhotoPreviewSlot(
        label: 'Actual',
        dateLabel: '19 abr 2026',
        weightLabel: '74.2 kg',
        caption: 'Frente · Reciente',
      );

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialRange;
  }

  @override
  void didUpdateWidget(covariant ProgressPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRange != oldWidget.initialRange &&
        widget.initialRange != _selectedRange) {
      _selectedRange = widget.initialRange;
    }
  }

  void _handleRangeSelected(ProgressRange range) {
    if (_selectedRange == range) return;
    setState(() => _selectedRange = range);
    widget.onRangeChanged?.call(range);
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.usePreviewData;
    final chartData =
        widget.chartData ??
        (preview ? _previewChartByRange[_selectedRange]! : _emptyChart);
    final historyEntries =
        widget.historyEntries ??
        (preview ? _previewHistory : const <ProgressHistoryEntry>[]);
    final initialPhoto =
        widget.initialPhotoSlot ?? (preview ? _previewInitialPhoto : null);
    final currentPhoto =
        widget.currentPhotoSlot ?? (preview ? _previewCurrentPhoto : null);

    return AppScaffoldTemplate(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                _Header(onBack: widget.onBack),
                const SizedBox(height: 18),
                ProgressRangeSelector(
                  selected: _selectedRange,
                  onSelected: _handleRangeSelected,
                ),
                const SizedBox(height: 18),
                ProgressWeightChartCard(
                  range: _selectedRange,
                  status: widget.chartStatus,
                  data: chartData,
                  onRetry: widget.onRetryChart,
                ),
                const SizedBox(height: 16),
                ProgressCheckInCard(
                  status: widget.checkInStatus,
                  selectedPhotoLabel: widget.selectedCheckInPhotoLabel,
                  isSubmitting: widget.isSubmittingCheckIn,
                  feedbackMessage: widget.checkInFeedback,
                  savedCount: widget.checkInSavedCount,
                  onSelectPhoto: widget.onSelectCheckInPhoto,
                  onSubmit: widget.onSubmitCheckIn,
                  onRetry: widget.onRetryCheckIn,
                ),
                const SizedBox(height: 16),
                ProgressHistoryCard(
                  status: widget.historyStatus,
                  entries: historyEntries,
                  onEntryTap: widget.onHistoryEntryTap,
                  onRetry: widget.onRetryHistory,
                ),
                const SizedBox(height: 16),
                ProgressPhotoComparisonCard(
                  status: widget.comparisonStatus,
                  initialSlot: initialPhoto,
                  currentSlot: currentPhoto,
                  onCompareFullScreen: widget.onComparePhotos,
                  onAddPhoto: widget.onAddPhoto,
                  onRetry: widget.onRetryComparison,
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(
                    'Seguimiento personal orientativo. No sustituye valoración ni diagnóstico médico.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Progreso', style: AppTypography.pageTitle),
              const SizedBox(height: 4),
              Text(
                'Evolución biométrica e historial',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
