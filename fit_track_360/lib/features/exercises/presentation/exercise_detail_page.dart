import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../data/exercise.dart';
import '../data/exercise_labels.dart';
import '../data/exercises_api.dart';
import 'widgets/exercise_media_view.dart';
import 'widgets/exercise_tag.dart';

/// Detalle de un ejercicio: media, instrucciones, pasos, músculos y atribución.
///
/// Los campos opcionales se ocultan cuando llegan nulos o vacíos.
class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.exerciseId, this.api});

  final String exerciseId;

  final ExercisesApi? api;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late final ApiClient? _ownedClient = widget.api == null ? ApiClient() : null;
  late final ExercisesApi _api = widget.api ?? ExercisesApi(_ownedClient!);

  AsyncState<Exercise> _state = const AsyncLoading<Exercise>();
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ownedClient?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() => _state = const AsyncLoading<Exercise>());
    try {
      final exercise = await _api.fetchById(widget.exerciseId);
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = AsyncData<Exercise>(exercise));
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (error, stackTrace) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = AsyncError<Exercise>(error, stackTrace));
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/app/ejercicios');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                Expanded(
                  child: _state.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentWhite,
                      ),
                    ),
                    data: (exercise) => _detail(exercise),
                    error: (error, _) => _error(error),
                    empty: _empty,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('Ejercicio', style: AppTypography.pageTitle)),
        ],
      ),
    );
  }

  Widget _detail(Exercise exercise) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
            child: AspectRatio(
              aspectRatio: 1,
              child: ExerciseMediaView(exercise: exercise, animate: true),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          exercise.name,
          style: AppTypography.pageTitle.copyWith(fontSize: 26),
        ),
        if (exercise.nameEs != null) ...[
          const SizedBox(height: 4),
          Text(
            exercise.nameEs!,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ExerciseTag(translateBodyPart(exercise.bodyPart), highlight: true),
            ExerciseTag(translateEquipment(exercise.equipment)),
            ExerciseTag(translateTarget(exercise.target)),
          ],
        ),
        if (exercise.level != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nivel: ${exercise.level!}',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (exercise.instructionsEs != null)
          _section('Instrucciones', Text(exercise.instructionsEs!)),
        if (exercise.instructionStepsEs.isNotEmpty)
          _section('Pasos', _steps(exercise.instructionStepsEs)),
        _section('Músculos', _muscles(exercise)),
        if (exercise.commonErrors != null)
          _section('Errores comunes', Text(exercise.commonErrors!)),
        const SizedBox(height: AppSpacing.sm),
        _attribution(exercise.attribution),
      ],
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: GlassSurface(
        radius: AppRadii.inner,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            DefaultTextStyle.merge(
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _steps(List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 22, child: Text('${index + 1}.')),
                Expanded(child: Text(steps[index])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _muscles(Exercise exercise) {
    final secondary = exercise.secondaryMuscles
        .map(translateMuscle)
        .where((label) => label != translateTarget(exercise.target))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Objetivo: ${translateTarget(exercise.target)}'),
        if (exercise.muscleGroup != null)
          Text('Grupo: ${translateMuscle(exercise.muscleGroup!)}'),
        if (secondary.isNotEmpty) Text('Secundarios: ${secondary.join(', ')}'),
      ],
    );
  }

  Widget _attribution(String attribution) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.glassBorder, height: AppSpacing.md),
        const Text(
          'Atribución',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          attribution,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Este ejercicio no tiene información para mostrar.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _goBack,
              child: const Text(
                'Volver',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error is AuthApiException ? error.message : 'No se pudo conectar',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.dangerText),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Reintentar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
