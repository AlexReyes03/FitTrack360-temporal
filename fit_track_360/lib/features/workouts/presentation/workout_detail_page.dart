import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../data/workouts_api.dart';
import '../data/workout_session.dart';
import 'workouts_page.dart';
import '../data/workouts_repository_impl.dart';
import '../domain/workout_summary.dart';
import '../domain/workout_summary_sharer.dart';
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
    this.sharer,
    this.api,
  });

  final String sessionId;
  final WorkoutsRepository? repository;
  final WorkoutSummarySharer? sharer;
  final WorkoutsApi? api;

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  ApiClient? _client;
  final _shareKey = GlobalKey();
  late final WorkoutDetailViewModel _viewModel;
  bool _repeating = false;
  bool _deleting = false;
  String? _editError;
  late final WorkoutsApi _api =
      widget.api ?? WorkoutsApi(_client ??= ApiClient());

  Future<void> _editSession() async {
    final session = _viewModel.session;
    if (session == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutsPage(
          api: _api,
          editingSession: session,
          profileClient: _client,
        ),
      ),
    );
    if (changed == true && mounted) await _viewModel.load();
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar sesión'),
        content: const Text('¿Deseas eliminar esta sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _deleting = true;
      _editError = null;
    });
    try {
      await _api.delete(widget.sessionId);
      if (mounted) _goBack();
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) {
        setState(
          () => _editError = error is AuthApiException
              ? error.message
              : 'No se pudo eliminar la sesión.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final repository =
        widget.repository ??
        ApiWorkoutsRepository(WorkoutsApi(_client = ApiClient()));
    _viewModel = WorkoutDetailViewModel(
      repository: repository,
      sessionId: widget.sessionId,
      sharer: widget.sharer,
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

  /// Vuelve a la pantalla anterior; si se abrió por enlace directo y no hay
  /// historial, va al listado de entrenamientos.
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app/entrenamientos');
    }
  }

  Rect? _shareOrigin() {
    final box = _shareKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareSummary() =>
      _viewModel.shareSummary(origin: _shareOrigin());

  Future<void> _repeatSession() async {
    if (_repeating) return;
    final draft = _viewModel.repeatDraft();
    if (draft == null) return;

    setState(() => _repeating = true);
    await context.push('/app/entrenamientos', extra: draft);
    if (mounted) setState(() => _repeating = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: _goBack,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text('Sesión', style: AppTypography.pageTitle),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  if (_viewModel.notFound) {
                    return _UnavailableView(
                      onGoToList: () => context.go('/app/entrenamientos'),
                    );
                  }
                  return _viewModel.summary.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentWhite,
                      ),
                    ),
                    data: (summary) => _DetailContent(
                      summary: summary,
                      session: _viewModel.session!,
                      editingError: _editError,
                      deleting: _deleting,
                      onEdit: _editSession,
                      onDelete: _deleteSession,
                      comparison: _viewModel.comparison,
                      actionError: _viewModel.actionError,
                      sharing: _viewModel.sharing,
                      repeating: _repeating,
                      shareKey: _shareKey,
                      onShare: _shareSummary,
                      onRepeat: _repeatSession,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.summary,
    required this.session,
    required this.editingError,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
    required this.comparison,
    required this.actionError,
    required this.sharing,
    required this.repeating,
    required this.shareKey,
    required this.onShare,
    required this.onRepeat,
  });

  final WorkoutSummary summary;
  final WorkoutSession session;
  final String? editingError;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AsyncState<WorkoutComparison> comparison;
  final String? actionError;
  final bool sharing;
  final bool repeating;
  final GlobalKey shareKey;
  final VoidCallback onShare;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final notes = summary.notes;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatDateTime(summary.startedAt),
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: shareKey,
            label: sharing ? 'Compartiendo...' : 'Compartir',
            onPressed: sharing ? null : onShare,
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: repeating ? null : onRepeat,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.glassBorderStrong),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Repetir como borrador'),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: deleting ? null : onEdit,
                  child: const Text('Editar'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: deleting ? null : onDelete,
                  child: Text(deleting ? 'Eliminando...' : 'Eliminar'),
                ),
              ),
            ],
          ),
          if (editingError != null)
            Text(
              editingError!,
              style: AppTypography.body.copyWith(color: AppColors.dangerText),
            ),
          if (actionError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              actionError!,
              style: AppTypography.body.copyWith(color: AppColors.dangerText),
            ),
          ],
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
                    for (final set in session.sets)
                      Text(
                        '${set.exerciseName}: ${set.reps} reps, ${set.weightKg ?? 0} kg',
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
      ),
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

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.onGoToList});

  final VoidCallback onGoToList;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workoutNotFoundMessage,
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
          TextButton(
            onPressed: onGoToList,
            child: const Text(
              'Volver al listado',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
