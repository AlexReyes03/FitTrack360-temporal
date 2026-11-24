import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../data/exercise.dart';
import '../../data/exercise_media.dart';

/// GIF cuando [animate] y hay archivo; si no, JPG y, en último caso, un
/// marcador. No fija tamaño: ocupa el espacio que le da el padre.
///
/// Mientras la imagen descarga se pinta un skeleton del mismo tamaño.
class ExerciseMediaView extends StatelessWidget {
  const ExerciseMediaView({
    super.key,
    required this.exercise,
    this.animate = false,
    this.decodeWidth,
  });

  static const Key gifKey = Key('exercise-gif');
  static const Key imageKey = Key('exercise-image');
  static const Key placeholderKey = Key('exercise-media-placeholder');
  static const Key skeletonKey = Key('exercise-media-skeleton');

  final Exercise exercise;

  /// En el detalle se pide `true`; en las tarjetas se deja `false` para no
  /// descargar 20 GIF por página.
  final bool animate;

  /// Ancho lógico en el que se pinta la imagen. Si se indica, la imagen se
  /// decodifica a `decodeWidth × devicePixelRatio` (`cacheWidth`) en lugar de
  /// a su tamaño original; útil para miniaturas.
  final double? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = decodeWidth == null
        ? null
        : (decodeWidth! * MediaQuery.devicePixelRatioOf(context)).round();

    final media = animate && hasAnimation(exercise)
        ? Image.network(
            exerciseGifUrl(exercise.gifFile),
            key: gifKey,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: cacheWidth,
            loadingBuilder: _loadingBuilder,
            errorBuilder: (context, error, stackTrace) => _image(cacheWidth),
          )
        : _image(cacheWidth);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(color: const Color(0x14FFFFFF), child: media),
    );
  }

  Widget _image(int? cacheWidth) {
    if (exercise.imageFile.trim().isEmpty) return _placeholder();

    return Image.network(
      exerciseImageUrl(exercise.imageFile),
      key: imageKey,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: cacheWidth,
      loadingBuilder: _loadingBuilder,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  static Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) return child;
    return const _MediaSkeleton(key: skeletonKey);
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(
        Icons.fitness_center,
        key: placeholderKey,
        color: AppColors.textMuted,
        size: 28,
      ),
    );
  }
}

/// Bloque skeleton con el mismo look de `RemoteLoadingView` (relleno y borde
/// blancos translúcidos). Privado del feature: migrar a DS en #222.
class _MediaSkeleton extends StatelessWidget {
  const _MediaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando imagen',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
