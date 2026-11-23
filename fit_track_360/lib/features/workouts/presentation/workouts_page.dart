import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/remote_state_views.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../../home/presentation/widgets/home_navigation_shell.dart';
import '../../settings/data/profile_api_repository.dart';
import 'session_exercise_editor.dart';
import '../data/workout_session.dart';
import '../data/workouts_api.dart';
import '../domain/workout_session_draft.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({
    super.key,
    this.api,
    this.draft,
    this.editingSession,
    this.profileClient,
    this.apiClientFactory = ApiClient.new,
    this.connectivityService,
  });

  final WorkoutsApi? api;
  final WorkoutSession? editingSession;
  final ApiClient? profileClient;

  /// Crea el cliente HTTP propio solo cuando no se inyecta [api].
  final ApiClient Function() apiClientFactory;

  /// Borrador precargado al iniciar desde una rutina; opcional.
  final WorkoutSessionDraft? draft;
  final ConnectivityService? connectivityService;

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  ApiClient? _ownClient;
  late final WorkoutsApi _api =
      widget.api ?? WorkoutsApi(_ownClient = widget.apiClientFactory());
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  late final TextEditingController _notesController = TextEditingController(
    text: widget.editingSession?.notes ?? widget.draft?.notes,
  );

  /// Borrador pendiente de guardar; se descarta al crear la sesión.
  late WorkoutSessionDraft? _draft =
      widget.draft ?? _draftFromSession(widget.editingSession);
  List<PlannedExercise>? _editedExercises;
  List<PlannedSet>? _editedSets;
  final _restController = TextEditingController(text: '90');
  int _editorKey = 0;

  WorkoutSessionDraft? _draftFromSession(WorkoutSession? session) {
    if (session == null) return null;
    final groups = <String, List<dynamic>>{};
    for (final set in session.sets) {
      if (set.exerciseId != null) {
        groups.putIfAbsent(set.exerciseId!, () => []).add(set);
      }
    }
    return WorkoutSessionDraft(
      startedAt: session.startedAt,
      notes: session.notes,
      exercises: [
        for (final e in groups.entries)
          PlannedExercise(
            exerciseId: e.key,
            exerciseName: e.value.first.exerciseName as String,
            position: groups.keys.toList().indexOf(e.key),
            targetSets: e.value.length,
            targetReps: e.value.first.reps as int,
          ),
      ],
      sets: [
        for (final set in session.sets)
          if (set.exerciseId != null)
            PlannedSet(
              exerciseId: set.exerciseId!,
              order: set.order ?? 1,
              weightKg: set.weightKg ?? 0,
              reps: set.reps,
            ),
      ],
    );
  }

  Future<void> _loadRest() async {
    final client = _ownClient ?? widget.profileClient;
    if (client == null) return;
    try {
      final profile = await ProfileApiRepository(client).fetchProfile();
      if (mounted && profile != null) {
        setState(
          () => _restController.text = '${profile.preferences.restSeconds}',
        );
      }
    } catch (_) {
      /* El valor por defecto funciona sin perfil disponible. */
    }
  }

  AsyncState<List<WorkoutSession>> _state = const AsyncLoading();
  late DateTime _startedAt =
      widget.editingSession?.startedAt.toLocal() ??
      widget.draft?.startedAt.toLocal() ??
      DateTime.now();
  bool _creating = false;
  bool _saved = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = _connectivity.onStatusChange.listen(
      _onConnectivityChange,
      onError: (_) {}, // Un fallo del plugin no debe tumbar la pantalla.
    );
    _load();
    if (widget.api == null || widget.profileClient != null) _loadRest();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _notesController.dispose();
    _restController.dispose();
    _ownClient?.dispose();
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

  /// Al recuperar la red, recarga solo si la última carga falló.
  void _onConnectivityChange(bool online) {
    if (online && mounted && _state is AsyncError) _load();
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
    final rest = int.tryParse(_restController.text);
    if (rest == null ||
        rest < 0 ||
        (_editedSets?.any(
              (s) => s.reps < 1 || s.weightKg < 0 || !s.weightKg.isFinite,
            ) ??
            false)) {
      setState(
        () => _formError = 'Revisa las repeticiones, el peso y el descanso.',
      );
      return;
    }
    setState(() {
      _creating = true;
      _saved = false;
      _formError = null;
    });
    final base =
        _draft ?? WorkoutSessionDraft(startedAt: _startedAt, exercises: []);
    try {
      final draft = base.edited(
        startedAt: _startedAt,
        notes: _notesController.text,
        exercises: _editedExercises,
        sets: _editedSets,
      );
      if (widget.editingSession case final session?) {
        final payload = draft.toCreateWorkoutPayload()..remove('routineId');
        payload['notes'] = _notesController.text.trim();
        payload['sets'] ??= <Object>[];
        await _api.update(session.id, payload);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      await _api.create(draft);
      if (!mounted) return;
      _notesController.clear();
      setState(() {
        _draft = null;
        _editedExercises = null;
        _editedSets = null;
        _editorKey++;
        _saved = true;
        _startedAt = DateTime.now();
      });
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
    final embedded =
        widget.editingSession == null &&
        HomeNavigationShell.isEmbedded(context);
    final list = ListView(
      key: const Key('workout-form-scroll'),
      padding: EdgeInsets.fromLTRB(24, embedded ? 12 : 24, 24, 28),
      children: [
        OfflineBanner(service: _connectivity, onRetry: _load),
        Row(
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textSecondary,
                ),
              ),
            Text(
              widget.editingSession == null
                  ? 'Entrenamientos'
                  : 'Editar sesión',
              style: AppTypography.pageTitle,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_draft?.routineName case final name?)
          Text('Rutina: $name', style: AppTypography.body),
        SessionExerciseEditor(
          key: ValueKey(_editorKey),
          initial: _draft,
          onChanged: (exercises, sets) {
            _editedExercises = exercises;
            _editedSets = sets;
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _restController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Descanso entre series (segundos)',
            helperText:
                'Referencia para esta sesión; no se guarda en el historial.',
          ),
        ),
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
              'Fecha y hora: ${_format(_startedAt)}',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ),
        if (_saved) ...[
          const SizedBox(height: 8),
          Text(
            'Sesión guardada',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(
            _formError!,
            style: AppTypography.body.copyWith(color: AppColors.dangerText),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _creating
              ? 'Guardando...'
              : widget.editingSession == null
              ? 'Registrar entrenamiento'
              : 'Guardar cambios',
          onPressed: _creating ? null : _create,
        ),
        if (widget.editingSession == null) ...[
          const SizedBox(height: 32),
          AsyncStateView<List<WorkoutSession>>(
            state: _state,
            onRetry: _load,
            loadingMessage: 'Cargando sesiones...',
            emptyTitle: 'Aún no tienes sesiones',
            emptyMessage: 'Crea una sesión para empezar el historial.',
            errorBuilder: (error, _) => RemoteErrorView(
              title: 'No se pudo cargar',
              message: error is AuthApiException
                  ? error.message
                  : 'No se pudo conectar',
              onRetry: _load,
            ),
            dataBuilder: (sessions) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final session in sessions)
                  InkWell(
                    onTap: () async {
                      await context.push('/app/entrenamientos/${session.id}');
                      if (mounted) await _load();
                    },
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
          ),
        ],
      ],
    );
    if (embedded) {
      return Scaffold(backgroundColor: Colors.transparent, body: list);
    }
    return AppScaffoldTemplate(body: SafeArea(child: list));
  }
}
