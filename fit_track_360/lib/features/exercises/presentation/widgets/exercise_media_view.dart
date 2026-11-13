import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../data/exercise.dart';
import '../../data/exercise_media.dart';

/// GIF cuando [animate] y hay archivo; si no, JPG y, en último caso, un
/// marcador. No fija tamaño: ocupa el espacio que le da el padre.
class ExerciseMediaView extends StatelessWidget {
  const ExerciseMediaView({
    super.key,
    required this.exercise,
    this.animate = false,
  });

  static const Key gifKey = Key('exercise-gif');
  static const Key imageKey = Key('exercise-image');
  static const Key placeholderKey = Key('exercise-media-placeholder');

  final Exercise exercise;

  /// En el detalle se pide `true`; en las tarjetas se deja `false` para no
  /// descargar 20 GIF por página.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final media = animate && hasAnimation(exercise)
        ? Image.network(
            exerciseGifUrl(exercise.gifFile),
            key: gifKey,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _image(),
          )
        : _image();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(color: const Color(0x14FFFFFF), child: media),
    );
  }

  Widget _image() {
    if (exercise.imageFile.trim().isEmpty) return _placeholder();

    return Image.network(
      exerciseImageUrl(exercise.imageFile),
      key: imageKey,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
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
