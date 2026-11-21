import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../data/routines_api.dart';
import '../data/routines_reader.dart';
import 'widgets/routine_exercise_tile.dart';

class RoutineDetailPage extends StatefulWidget {
  const RoutineDetailPage({super.key, required this.routineId, this.reader});

  final String routineId;
  final RoutinesReader? reader;

  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  // El cliente solo se crea (y se libera) si la página no recibió un reader.
  late final ApiClient? _ownedClient = widget.reader == null
      ? ApiClient()
      : null;
  late final RoutinesReader _reader =
      widget.reader ?? RoutinesApi(_ownedClient!);

  AsyncState<RoutineDetail> _state = const AsyncLoading();

  /// Descarta respuestas viejas cuando cambia la rutina solicitada.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RoutineDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routineId != widget.routineId) {
      _load();
    }
  }

  @override
  void dispose() {
    _ownedClient?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() => _state = const AsyncLoading());
    try {
      final routine = await _reader.getById(widget.routineId);
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = AsyncData(routine));
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (error, stackTrace) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = AsyncError(error, stackTrace));
    }
  }

  String _message(Object error) {
    if (error is RoutineNotFoundException) return error.toString();
    if (error is AuthApiException) return error.message;
    return 'No se pudo conectar';
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app/rutinas');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Volver',
                  onPressed: _back,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Rutina',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _state.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentWhite,
                  ),
                ),
              ),
              data: _content,
              error: (error, _) =>
                  _ErrorView(message: _message(error), onRetry: _load),
              empty: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(RoutineDetail routine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          routine.name.isEmpty ? 'Rutina sin nombre' : routine.name,
          style: AppTypography.pageTitle,
        ),
        if (routine.notes != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            routine.notes!,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ejercicios (${routine.exercises.length})',
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (routine.exercises.isEmpty)
          Text(
            'Esta rutina no tiene ejercicios.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          )
        else
          for (var index = 0; index < routine.exercises.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: RoutineExerciseTile(
                ordinal: index + 1,
                exercise: routine.exercises[index],
              ),
            ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppTypography.body.copyWith(color: AppColors.dangerText),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: onRetry,
          child: const Text(
            'Reintentar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
