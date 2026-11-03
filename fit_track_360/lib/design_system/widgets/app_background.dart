import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Fondo fijo del DS: gradiente vertical bg.deep -> bg.mid -> bg.deep con
/// tres vinetas radiales. El contenido se desplaza sobre este fondo.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortSide = size.shortestSide;

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.bgDeep),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [AppColors.bgDeep, AppColors.bgMid, AppColors.bgDeep],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _RadialVignette(
              center: Alignment(-0.76, -0.84),
              radius: shortSide * 0.38,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Positioned.fill(
            child: _RadialVignette(
              center: Alignment(0.76, -0.56),
              radius: shortSide * 0.42,
              color: AppColors.textSecondary.withValues(alpha: 0.08),
            ),
          ),
          Positioned.fill(
            child: _RadialVignette(
              center: Alignment(0, 0.7),
              radius: shortSide * 0.45,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _RadialVignette extends StatelessWidget {
  final Alignment center;
  final double radius;
  final Color color;

  const _RadialVignette({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadialVignettePainter(
        center: center,
        radius: radius,
        color: color,
      ),
    );
  }
}

class _RadialVignettePainter extends CustomPainter {
  final Alignment center;
  final double radius;
  final Color color;

  _RadialVignettePainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final offset = center.withinRect(Offset.zero & size);
    final paint = Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: offset, radius: radius));
    canvas.drawCircle(offset, radius, paint);
  }

  @override
  bool shouldRepaint(_RadialVignettePainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.radius != radius ||
      oldDelegate.color != color;
}
