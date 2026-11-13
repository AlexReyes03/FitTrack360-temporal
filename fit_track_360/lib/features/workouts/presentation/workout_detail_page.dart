import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../data/workouts_api.dart';
import '../data/workouts_repository_impl.dart';
import '../domain/workout_summary.dart';
import '../domain/workouts_repository.dart';
import 'workout_detail_format.dart';
import 'workout_detail_view_model.dart';

/// Detalle de una sesión (W11-10): resumen, ejercicios, notas y comparación
/// con la sesión anterior.
class WorkoutDetailPage extends StatefulWidget {
  const WorkoutDetailPage({
    super.key,
    required this.sessionId,
    this.repository,
  });

  final String sessionId;
  final WorkoutsRepository? repository;

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  ApiClient? _client;
  late final WorkoutDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final repository =
        widget.repository ??
        ApiWorkoutsRepository(WorkoutsApi(_client = ApiClient()));
    _viewModel = WorkoutDetailViewModel(
      repository: repository,
      sessionId: widget.sessionId,
    )..addListener(_onSessionExpired);
    _viewModel.load();
  }

  void _onSessionExpired() {
    if (_viewModel.sessionExpired && mounted) context.go('/login');
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onSessionExpired)
      ..dispose();
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => _viewModel.summary.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentWhite),
            ),
            data: (summary) => _DetailContent(
              summary: summary,
              comparison: _viewModel.comparison,
            ),
            error: (error, _) => _ErrorView(
              message: error is AuthApiException
                  ? error.message
                  : 'No se pudo conectar',
              onRetry: _viewModel.load,
            ),
            empty: () => _ErrorView(
              message: 'No hay datos de esta sesión',
              onRetry: _viewModel.load,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.summary, required this.comparison});

  final WorkoutSummary summary;
  final AsyncState<WorkoutComparison> comparison;

  @override
  Widget build(BuildContext context) {
    final notes = summary.notes;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Sesión', style: AppTypography.pageTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          formatDateTime(summary.startedAt),
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        // W11-FE-03.2 (Loreley): aquí van las acciones «Compartir» y
        // «Repetir como borrador».
        const SizedBox(height: AppSpacing.md),
        GlassSurface(
          child: Row(
            children: [
              _Metric(
                label: 'Duración',
                value: formatDuration(summary.duration),
              ),
              _Metric(label: 'Volumen', value: formatKg(summary.volumeKg)),
              _Metric(label: 'Series', value: '${summary.setCount}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Ejercicios',
          children: summary.exercises.isEmpty
              ? [const _Muted('Sin ejercicios registrados')]
              : [
                  for (final exercise in summary.exercises)
                    Text(
                      '$exercise · '
                      '${formatSetCount(summary.setsPerExercise[exercise]!)}',
                      style: AppTypography.body,
                    ),
                ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Notas',
          children: [
            if (notes == null || notes.trim().isEmpty)
              const _Muted('Sin notas')
            else
              Text(notes, style: AppTypography.body),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ComparisonSection(state: comparison),
      ],
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.state});

  final AsyncState<WorkoutComparison> state;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Comparación con la sesión anterior',
      children: [
        state.when(
          loading: () => const _Muted('Cargando comparación…'),
          data: (comparison) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Muted(
                'Anterior: ${formatDateTime(comparison.previousStartedAt)}',
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  _Metric(
                    label: 'Duración',
                    value: formatDurationDelta(comparison.durationDelta),
                  ),
                  _Metric(
                    label: 'Volumen',
                    value: formatKgDelta(comparison.volumeDeltaKg),
                  ),
                  _Metric(
                    label: 'Series',
                    value: formatIntDelta(comparison.setCountDelta),
                  ),
                ],
              ),
            ],
          ),
          error: (_, _) => const _Muted('No se pudo cargar la comparación.'),
          empty: () =>
              const _Muted('Aún no hay una sesión anterior para comparar.'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.cta.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.cta.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.dangerText),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Reintentar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
