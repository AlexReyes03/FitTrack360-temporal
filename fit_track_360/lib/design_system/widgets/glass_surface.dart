import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Superficie glass del DS: blur sigma 16, fill diagonal blanco 8.5% -> 2.5%
/// -> 5%, borde fino, sombra exterior y dos lineas superiores separadas
/// (rim completo + specular streak al 84% del ancho). Sin inset shadow.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0xC7000000),
            blurRadius: 54,
            offset: Offset(0, 24),
            spreadRadius: -14,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.5, 1.0],
                      colors: [
                        Color(0x16FFFFFF),
                        Color(0x07FFFFFF),
                        Color(0x0DFFFFFF),
                      ],
                    ),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.glassRim),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: FractionallySizedBox(
                  widthFactor: 0.84,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
