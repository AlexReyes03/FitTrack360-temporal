import 'package:flutter/material.dart';

import '../../../../core/async_state.dart';
import '../../../../core/widgets/remote_state_views.dart';
import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../design_system/widgets/ds_text_field.dart';
import '../../../auth/data/auth_api.dart';
import '../../../exercises/data/exercise.dart';
import '../../../exercises/data/exercise_labels.dart';
import '../../../exercises/data/exercises_api.dart';
import '../../../exercises/presentation/widgets/exercise_media_view.dart';
import '../exercise_picker_view_model.dart';
import 'tracker_controls.dart';

/// Abre el selector glass de ejercicios y devuelve el elegido (o null).
///
/// Hoja inferior con búsqueda y carga incremental al llegar al final de la
/// lista. Privada del feature: migrar la hoja glass a DS en #222.
Future<Exercise?> showExercisePickerSheet(
  BuildContext context, {
  required ExercisesApi api,
  String title = 'Elegir ejercicio',
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (context) => ExercisePickerSheet(api: api, title: title),
  );
}

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({
    super.key,
    required this.api,
    this.title = 'Elegir ejercicio',
  });

  final ExercisesApi api;
  final String title;

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  late final ExercisePickerViewModel _viewModel = ExercisePickerViewModel(
    api: widget.api,
  );
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: GlassSurface(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TrackerIconControl(
                    icon: Icons.close_rounded,
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DsTextField(
                controller: _searchController,
                label: 'Buscar',
                hint: 'Nombre del ejercicio',
                onChanged: _viewModel.search,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => _results(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results() {
    return switch (_viewModel.state) {
      AsyncLoading() => const RemoteLoadingView(
        message: 'Cargando ejercicios...',
      ),
      AsyncError(:final error) => RemoteErrorView(
        title: 'No se pudo cargar',
        message: error is AuthApiException
            ? error.message
            : 'No se pudo conectar',
        onRetry: _viewModel.load,
      ),
      AsyncEmpty() => const RemoteEmptyView(
        title: 'Sin resultados',
        message: 'Prueba con otro nombre.',
        icon: Icons.search_off_rounded,
      ),
      AsyncData(:final data) => ListView.builder(
        key: const Key('exercise-picker-list'),
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        itemCount: data.length + 1,
        itemBuilder: (context, index) {
          if (index == data.length) return _footer();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _ExerciseOption(
              exercise: data[index],
              onTap: () => Navigator.of(context).pop(data[index]),
            ),
          );
        },
      ),
    };
  }

  /// Al construirse el pie (fin de la lista) se pide la siguiente página.
  Widget _footer() {
    final error = _viewModel.loadMoreError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.dangerText),
            ),
            const SizedBox(height: AppSpacing.xs),
            TrackerGlassButton(
              label: 'Reintentar',
              compact: true,
              onPressed: _viewModel.loadMore,
            ),
          ],
        ),
      );
    }
    if (!_viewModel.hasMore) return const SizedBox(height: AppSpacing.xs);
    if (!_viewModel.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _viewModel.loadMore();
      });
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentWhite,
          ),
        ),
      ),
    );
  }
}

class _ExerciseOption extends StatelessWidget {
  const _ExerciseOption({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = exercise.nameEs ?? exercise.name;
    final tags =
        '${translateBodyPart(exercise.bodyPart)} · '
        '${translateEquipment(exercise.equipment)}';
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.option),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.option),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: ExerciseMediaView(exercise: exercise),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tags,
                      style: AppTypography.caption.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
