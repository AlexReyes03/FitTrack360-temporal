import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../state/progress_view_state.dart';
import 'progress_section_shell.dart';

/// Tarjeta Liquid Glass con gráfica visual placeholder de evolución de peso.
class ProgressWeightChartCard extends StatelessWidget {
  const ProgressWeightChartCard({
    super.key,
    required this.range,
    required this.status,
    required this.data,
    this.onRetry,
  });

  final ProgressRange range;
  final ProgressSectionStatus status;
  final ProgressChartData data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus =
        status == ProgressSectionStatus.data && data.points.isEmpty
        ? ProgressSectionStatus.empty
        : status;

    return ProgressSectionShell(
      title: 'Evolución de peso',
      subtitle: range.description,
      status: effectiveStatus,
      emptyTitle: 'Sin registros en este rango',
      emptyDescription:
          'Guarda tu primer check-in para ver la tendencia de tu peso.',
      errorMessage: 'No se pudo cargar la gráfica de evolución.',
      onRetry: onRetry,
      skeletonHeight: 196,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          range.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(data: data),
          const SizedBox(height: 16),
          _WeightChartPlaceholder(points: data.points),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data});

  final ProgressChartData data;

  String _formatDelta(double delta) {
    if (delta.abs() < 0.05) return '0.0 kg';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricPill(
            label: 'Actual',
            value: '${data.currentWeightKg.toStringAsFixed(1)} kg',
            emphasized: true,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _MetricPill(
            label: 'Variación',
            value: _formatDelta(data.periodDeltaKg),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _MetricPill(
            label: 'Promedio',
            value: '${data.averageWeightKg.toStringAsFixed(1)} kg',
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        color: emphasized
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.controlFillIdle,
        border: Border.all(
          color: emphasized
              ? AppColors.glassBorderStrong
              : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: emphasized ? AppColors.accentWhite : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightChartPlaceholder extends StatelessWidget {
  const _WeightChartPlaceholder({required this.points});

  final List<ProgressChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final weights = points.map((p) => p.weightKg).toList();
    final minWeight = weights.reduce(math.min);
    final maxWeight = weights.reduce(math.max);
    final midWeight = (minWeight + maxWeight) / 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.inner),
        color: AppColors.controlFillIdle,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 136,
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AxisLabel('${maxWeight.toStringAsFixed(1)} kg'),
                    _AxisLabel('${midWeight.toStringAsFixed(1)} kg'),
                    _AxisLabel('${minWeight.toStringAsFixed(1)} kg'),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomPaint(
                    painter: _WeightTrendPainter(points: points),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _buildXAxisLabels(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildXAxisLabels() {
    if (points.length <= 4) {
      return points.map((p) => _AxisLabel(p.label)).toList();
    }
    final middleIndex = points.length ~/ 2;
    return [
      _AxisLabel(points.first.label),
      _AxisLabel(points[middleIndex].label),
      _AxisLabel(points.last.label),
    ];
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _WeightTrendPainter extends CustomPainter {
  _WeightTrendPainter({required this.points});

  final List<ProgressChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      final y = (size.height / 2) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final weights = points.map((p) => p.weightKg).toList();
    final minWeight = weights.reduce(math.min);
    final maxWeight = weights.reduce(math.max);
    final range = (maxWeight - minWeight).abs();
    const verticalPadding = 10.0;
    final usableHeight = math.max(1.0, size.height - verticalPadding * 2);

    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : (size.width / (points.length - 1)) * i;
      final normalized = range < 0.01
          ? 0.5
          : (points[i].weightKg - minWeight) / range;
      final y = verticalPadding + usableHeight * (1 - normalized);
      offsets.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final prev = offsets[i - 1];
      final curr = offsets[i];
      final controlX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
    }

    if (offsets.length > 1) {
      final areaPath = Path.from(linePath)
        ..lineTo(offsets.last.dx, size.height)
        ..lineTo(offsets.first.dx, size.height)
        ..close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(areaPath, areaPaint);
    }

    final linePaint = Paint()
      ..color = AppColors.accentWhite
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final dotOuterPaint = Paint()..color = AppColors.bgMid;
    final dotInnerPaint = Paint()..color = AppColors.accentWhite;
    for (final point in offsets) {
      canvas.drawCircle(point, 5.2, dotOuterPaint);
      canvas.drawCircle(point, 3.2, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
