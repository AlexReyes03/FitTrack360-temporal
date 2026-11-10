import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../data/workout_session.dart';
import '../data/workouts_api.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key, this.api});

  final WorkoutsApi? api;

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  late final ApiClient _client = ApiClient();
  late final WorkoutsApi _api = widget.api ?? WorkoutsApi(_client);
  final TextEditingController _notesController = TextEditingController();

  AsyncState<List<WorkoutSession>> _state = const AsyncLoading();
  DateTime _startedAt = DateTime.now();
  bool _creating = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = const AsyncLoading());
    try {
      final sessions = await _api.list();
      if (!mounted) return;
      setState(() => _state = AsyncState.fromData(sessions));
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _state = AsyncError(error, stackTrace));
    }
  }

  Future<void> _pickStartedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _formError = null;
    });
    try {
      await _api.create(startedAt: _startedAt, notes: _notesController.text);
      if (!mounted) return;
      _notesController.clear();
      setState(() => _startedAt = DateTime.now());
      await _load();
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = error is AuthApiException
            ? error.message
            : 'No se pudo conectar';
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _format(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Entrenamientos', style: AppTypography.pageTitle),
            const SizedBox(height: 16),
            Text('Notas', style: AppTypography.body),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              enabled: !_creating,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Opcional',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Text('Inicio', style: AppTypography.body),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _creating ? null : _pickStartedAt,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _format(_startedAt),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 8),
              Text(
                _formError!,
                style: AppTypography.body.copyWith(color: AppColors.dangerText),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: _creating ? 'Creando...' : 'Crear sesión',
              onPressed: _creating ? null : _create,
            ),
            const SizedBox(height: 32),
            _state.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentWhite),
              ),
              data: (sessions) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final session in sessions)
                    InkWell(
                      onTap: () =>
                          context.push('/app/entrenamientos/${session.id}'),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _format(session.startedAt),
                              style: AppTypography.body,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              session.notes == null || session.notes!.isEmpty
                                  ? 'Sin notas'
                                  : session.notes!,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error is AuthApiException
                        ? error.message
                        : 'No se pudo conectar',
                    style: AppTypography.body.copyWith(
                      color: AppColors.dangerText,
                    ),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              empty: () => Text(
                'Aún no tienes sesiones',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
