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
import 'widgets/routine_card.dart';

class RoutinesPage extends StatefulWidget {
  const RoutinesPage({super.key, this.reader});

  final RoutinesReader? reader;

  @override
  State<RoutinesPage> createState() => _RoutinesPageState();
}

class _RoutinesPageState extends State<RoutinesPage> {
  late final ApiClient _client = ApiClient();
  late final RoutinesReader _reader = widget.reader ?? RoutinesApi(_client);

  AsyncState<List<RoutineSummary>> _state = const AsyncLoading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = const AsyncLoading());
    try {
      final routines = await _reader.list();
      if (!mounted) return;
      setState(() => _state = AsyncState.fromData(routines));
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _state = AsyncError(error, stackTrace));
    }
  }

  String _message(Object error) {
    return error is AuthApiException ? error.message : 'No se pudo conectar';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Rutinas', style: AppTypography.pageTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tus plantillas de entrenamiento.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _state.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentWhite,
                  ),
                ),
              ),
              data: (routines) => Column(
                children: [
                  for (final routine in routines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RoutineCard(
                        routine: routine,
                        onTap: () => context.push(
                          '/app/rutinas/${Uri.encodeComponent(routine.id)}',
                        ),
                      ),
                    ),
                ],
              ),
              error: (error, _) =>
                  _ErrorView(message: _message(error), onRetry: _load),
              empty: () => _EmptyView(onRetry: _load),
            ),
          ],
        ),
      ),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aún no tienes rutinas.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: onRetry,
          child: const Text(
            'Actualizar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
