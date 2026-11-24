import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../exercises/data/exercises_api.dart';
import '../../settings/data/profile_api_repository.dart';
import '../data/workout_session.dart';
import '../data/workouts_api.dart';
import '../domain/workout_session_draft.dart';
import 'session_exercise_editor.dart';
import 'workout_detail_format.dart';
import 'workout_form_view_model.dart';
import 'widgets/tracker_controls.dart';
import 'widgets/workout_dialogs.dart';
import 'widgets/workout_number_field.dart';

/// Formulario para «Registrar entrenamiento pasado» o «Editar sesión».
///
/// Entrenar en vivo se hace en el tracker; este formulario es solo para lo
/// que ya ocurrió, por eso pide inicio y duración y guarda la sesión
/// finalizada. Devuelve `true` al cerrar si guardó.
class WorkoutFormPage extends StatefulWidget {
  const WorkoutFormPage({
    super.key,
    this.api,
    this.draft,
    this.editingSession,
    this.profileClient,
    this.exercisesApi,
    this.apiClientFactory = ApiClient.new,
  });

  final WorkoutsApi? api;
  final WorkoutSessionDraft? draft;
  final WorkoutSession? editingSession;

  /// Cliente para leer el descanso preferido del perfil; opcional.
  final ApiClient? profileClient;
  final ExercisesApi? exercisesApi;

  /// Crea el cliente HTTP propio solo cuando no se inyecta [api].
  final ApiClient Function() apiClientFactory;

  @override
  State<WorkoutFormPage> createState() => _WorkoutFormPageState();
}

class _WorkoutFormPageState extends State<WorkoutFormPage> {
  ApiClient? _ownClient;
  late final WorkoutFormViewModel _vm = WorkoutFormViewModel(
    api: widget.api ?? WorkoutsApi(_ownClient = widget.apiClientFactory()),
    draft: widget.draft,
    editingSession: widget.editingSession,
  );
  late final _durationController = TextEditingController(
    text: _vm.durationText,
  );
  late final _restController = TextEditingController(text: _vm.restText);
  late final _notesController = TextEditingController(text: _vm.notes);
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_syncRest);
    if (widget.api == null || widget.profileClient != null) _loadRest();
  }

  @override
  void dispose() {
    _vm
      ..removeListener(_syncRest)
      ..dispose();
    _durationController.dispose();
    _restController.dispose();
    _notesController.dispose();
    _ownClient?.dispose();
    super.dispose();
  }

  /// El descanso del perfil llega tarde: solo se refleja si no se editó.
  void _syncRest() {
    if (_restController.text != _vm.restText) {
      _restController.text = _vm.restText;
    }
  }

  Future<void> _loadRest() async {
    final client = _ownClient ?? widget.profileClient;
    if (client == null) return;
    try {
      final profile = await ProfileApiRepository(client).fetchProfile();
      if (mounted && profile != null) {
        _vm.applyProfileRest(profile.preferences.restSeconds);
      }
    } catch (_) {
      /* El valor por defecto funciona sin perfil disponible. */
    }
  }

  Future<void> _pickStartedAt() async {
    final current = _vm.startedAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    _vm.setStartedAt(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _save() async {
    final result = await _vm.save();
    if (!mounted) return;
    switch (result) {
      case WorkoutFormSaveResult.saved:
        _leaving = true;
        Navigator.of(context).pop(true);
      case WorkoutFormSaveResult.sessionExpired:
        context.go('/login');
      case WorkoutFormSaveResult.invalid:
      case WorkoutFormSaveResult.failed:
        break;
    }
  }

  Future<void> _confirmLeave() async {
    final discard = await showDiscardChangesDialog(context);
    if (!discard || !mounted) return;
    _leaving = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => PopScope<Object?>(
        canPop: _leaving || !_vm.dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmLeave();
        },
        child: AppScaffoldTemplate(body: SafeArea(child: _form(context))),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final editing = _vm.isEditing;
    return ListView(
      key: const Key('workout-form-scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        Row(
          children: [
            TrackerIconControl(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                editing ? 'Editar sesión' : 'Registrar entrenamiento pasado',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (!editing) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Para entrenar ahora usa «Entrenar ahora»; aquí registras lo que '
            'ya hiciste.',
            style: AppTypography.caption,
          ),
        ],
        if (_vm.routineName case final name?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Rutina: $name', style: AppTypography.body),
        ],
        const SizedBox(height: AppSpacing.md),
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cuándo',
                style: AppTypography.cta.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              TrackerGlassButton(
                label: 'Inicio: ${formatDateTime(_vm.startedAt)}',
                icon: Icons.event_rounded,
                onPressed: _vm.saving ? null : _pickStartedAt,
              ),
              const SizedBox(height: AppSpacing.sm),
              WorkoutNumberField(
                label: 'Duración (minutos)',
                fieldKey: const Key('workout-duration'),
                controller: _durationController,
                inputFormatters: WorkoutInputFormatters.integer,
                errorText: _vm.durationError,
                enabled: !_vm.saving,
                onChanged: _vm.setDuration,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ejercicios',
          style: AppTypography.cta.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        SessionExerciseEditor(viewModel: _vm.editor, api: widget.exercisesApi),
        const SizedBox(height: AppSpacing.md),
        WorkoutNumberField(
          label: 'Descanso entre series (segundos)',
          fieldKey: const Key('workout-rest'),
          controller: _restController,
          inputFormatters: WorkoutInputFormatters.integer,
          helperText:
              'Referencia para esta sesión; no se guarda en el historial.',
          errorText: _vm.restError,
          enabled: !_vm.saving,
          onChanged: _vm.setRest,
        ),
        const SizedBox(height: AppSpacing.md),
        DsTextField(
          controller: _notesController,
          label: 'Notas',
          hint: 'Opcional',
          enabled: !_vm.saving,
          onChanged: _vm.setNotes,
        ),
        if (_vm.saveError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _vm.saveError!,
            style: AppTypography.body.copyWith(color: AppColors.dangerText),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: _vm.saving
              ? 'Guardando...'
              : editing
              ? 'Guardar cambios'
              : 'Registrar entrenamiento',
          onPressed: _vm.saving ? null : _save,
        ),
      ],
    );
  }
}
