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
          _WeightChartPlaceholder(data: data, range: range),
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
  const _WeightChartPlaceholder({required this.data, required this.range});

  final ProgressChartData data;
  final ProgressRange range;

  /// Ancho fijo de las etiquetas del eje Y y separación con el trazo: las
  /// etiquetas del eje X se posicionan con la misma geometría que el painter.
  static const double _yAxisWidth = 56;
  static const double _yAxisGap = 10;
  static const double _xLabelSlot = 64;

  List<ProgressChartPoint> get points => data.points;

  static String _kg(double value) => '${value.toStringAsFixed(1)} kg';

  static String _signedKg(double delta) {
    if (delta.abs() < 0.05) return '0.0 kg';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} kg';
  }

  /// Resumen textual de la gráfica para lectores de pantalla.
  String _semanticSummary(double minWeight, double maxWeight) {
    final count = points.length;
    final records = count == 1 ? '1 registro' : '$count registros';
    final span = count == 1
        ? 'el ${points.first.label}'
        : 'del ${points.first.label} al ${points.last.label}';
    return 'Gráfica de evolución de peso, ${range.description.toLowerCase()}: '
        '$records $span. Peso actual ${_kg(data.currentWeightKg)}, '
        'variación ${_signedKg(data.periodDeltaKg)}, '
        'promedio ${_kg(data.averageWeightKg)}, '
        'mínimo ${_kg(minWeight)} y máximo ${_kg(maxWeight)}.';
  }

  @override
  Widget build(BuildContext context) {
    final weights = points.map((p) => p.weightKg).toList();
    final minWeight = weights.reduce(math.min);
    final maxWeight = weights.reduce(math.max);
    final midWeight = (minWeight + maxWeight) / 2;

    return Semantics(
      key: const Key('progress-weight-chart-semantics'),
      container: true,
      label: _semanticSummary(minWeight, maxWeight),
      excludeSemantics: true,
      child: Container(
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
                  SizedBox(
                    width: _yAxisWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _AxisLabel(_kg(maxWeight)),
                        _AxisLabel(_kg(midWeight)),
                        _AxisLabel(_kg(minWeight)),
                      ],
                    ),
                  ),
                  const SizedBox(width: _yAxisGap),
                  Expanded(
                    child: CustomPaint(
                      key: const Key('progress-weight-chart-plot'),
                      painter: _WeightTrendPainter(points: points),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: _yAxisWidth + _yAxisGap),
              child: SizedBox(
                height: 16,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    clipBehavior: Clip.none,
                    children: _buildXAxisLabels(constraints.maxWidth),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Índices con etiqueta: todos si son pocos; si no, inicio, mitad y fin.
  List<int> _labelIndexes() {
    if (points.length <= 4) return [for (var i = 0; i < points.length; i++) i];
    return [0, points.length ~/ 2, points.length - 1];
  }

  /// Cada etiqueta queda bajo su punto (misma `x` que `_WeightTrendPainter`).
  /// La primera y la última se alinean al borde para no salirse del trazo.
  List<Widget> _buildXAxisLabels(double width) => [
    for (final index in _labelIndexes()) _positionedLabel(index, width),
  ];

  Widget _positionedLabel(int index, double width) {
    final count = points.length;
    final label = _AxisLabel(
      points[index].label,
      key: Key('progress-chart-x-label-$index'),
    );
    if (count == 1) return Positioned.fill(child: Center(child: label));
    if (index == 0) return Positioned(left: 0, top: 0, child: label);
    if (index == count - 1) return Positioned(right: 0, top: 0, child: label);
    final x = width * index / (count - 1);
    final slot = math.min(_xLabelSlot, width);
    final left = (x - slot / 2).clamp(0.0, width - slot);
    return Positioned(
      left: left,
      top: 0,
      width: slot,
      child: Center(child: label),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text, {super.key});

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
