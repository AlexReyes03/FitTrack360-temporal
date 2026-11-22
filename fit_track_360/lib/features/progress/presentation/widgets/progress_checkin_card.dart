import 'package:flutter/material.dart';

import '../../../../design_system/components/primary_button.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/widgets/ds_text_field.dart';
import '../../domain/body_weight_validation.dart';
import '../state/progress_view_state.dart';
import 'progress_section_shell.dart';

/// Formulario Liquid Glass de check-in diario: peso, medidas opcionales, notas y foto P1.
class ProgressCheckInCard extends StatefulWidget {
  const ProgressCheckInCard({
    super.key,
    this.status = ProgressSectionStatus.data,
    this.initialWeightText = '',
    this.initialBodyFatText = '',
    this.initialWaistText = '',
    this.initialNotesText = '',
    this.selectedPhotoLabel,
    this.isSubmitting = false,
    this.feedbackMessage,
    this.onSelectPhoto,
    this.onSubmit,
    this.onRetry,
  });

  final ProgressSectionStatus status;
  final String initialWeightText;
  final String initialBodyFatText;
  final String initialWaistText;
  final String initialNotesText;
  final String? selectedPhotoLabel;
  final bool isSubmitting;

  /// Resultado del último envío (éxito o error decidido por el ViewModel).
  final String? feedbackMessage;
  final VoidCallback? onSelectPhoto;
  final ValueChanged<ProgressCheckInDraft>? onSubmit;
  final VoidCallback? onRetry;

  @override
  State<ProgressCheckInCard> createState() => _ProgressCheckInCardState();
}

class _ProgressCheckInCardState extends State<ProgressCheckInCard> {
  static final RegExp _decimal = RegExp(r'^\d+([.,]\d+)?$');

  late final TextEditingController _weightController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _waistController;
  late final TextEditingController _notesController;
  String? _weightError;
  String? _bodyFatError;
  String? _waistError;
  bool _awaitingSubmitResult = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.initialWeightText);
    _bodyFatController = TextEditingController(text: widget.initialBodyFatText);
    _waistController = TextEditingController(text: widget.initialWaistText);
    _notesController = TextEditingController(text: widget.initialNotesText);
  }

  @override
  void didUpdateWidget(covariant ProgressCheckInCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final finishedSubmit =
        (oldWidget.isSubmitting || _awaitingSubmitResult) &&
        !widget.isSubmitting;
    if (!finishedSubmit) return;

    if (_isSuccessFeedback(widget.feedbackMessage)) {
      _weightController.clear();
      _bodyFatController.clear();
      _waistController.clear();
      _notesController.clear();
      _weightError = null;
      _bodyFatError = null;
      _waistError = null;
      _awaitingSubmitResult = false;
    } else if (widget.feedbackMessage != null) {
      _awaitingSubmitResult = false;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static bool _isSuccessFeedback(String? message) {
    if (message == null) return false;
    return message.trim().toLowerCase().startsWith('check-in registrado');
  }

  static ({double? value, String? error}) _validateBodyFat(String input) {
    final text = input.trim();
    if (text.isEmpty) return (value: null, error: null);
    if (!_decimal.hasMatch(text)) {
      return (value: null, error: 'Ingresa un valor entre 0 y 100.');
    }
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0 || value > 100) {
      return (value: null, error: 'Ingresa un valor entre 0 y 100.');
    }
    return (value: value, error: null);
  }

  static ({double? value, String? error}) _validateWaist(String input) {
    final text = input.trim();
    if (text.isEmpty) return (value: null, error: null);
    if (!_decimal.hasMatch(text)) {
      return (value: null, error: 'Ingresa un valor mayor a 0.');
    }
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) {
      return (value: null, error: 'Ingresa un valor mayor a 0.');
    }
    return (value: value, error: null);
  }

  void _handleSubmit() {
    final weightValidation = validateBodyWeightKg(_weightController.text);
    final bodyFatValidation = _validateBodyFat(_bodyFatController.text);
    final waistValidation = _validateWaist(_waistController.text);
    setState(() {
      _weightError = weightValidation.error;
      _bodyFatError = bodyFatValidation.error;
      _waistError = waistValidation.error;
    });
    final weightKg = weightValidation.weightKg;
    if (weightKg == null ||
        bodyFatValidation.error != null ||
        waistValidation.error != null) {
      return;
    }

    if (widget.onSubmit != null) {
      _awaitingSubmitResult = true;
    }
    widget.onSubmit?.call(
      ProgressCheckInDraft(
        weightKg: weightKg,
        bodyFatPercent: bodyFatValidation.value,
        waistCm: waistValidation.value,
        notesText: _notesController.text.trim(),
        hasPhotoSelected: widget.selectedPhotoLabel != null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.selectedPhotoLabel != null;

    return ProgressSectionShell(
      title: 'Nuevo check-in',
      subtitle: 'Registra tu peso, una nota breve y una foto opcional',
      status: widget.status,
      emptyTitle: 'Formulario no disponible',
      emptyDescription: 'Intenta nuevamente en unos momentos.',
      errorMessage: 'No se pudo cargar el formulario de check-in.',
      onRetry: widget.onRetry,
      skeletonHeight: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsTextField(
            key: const Key('checkin-weight-field'),
            controller: _weightController,
            label: 'Peso corporal (kg)',
            hint: 'Ej. 74.2',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !widget.isSubmitting,
            errorText: _weightError,
            onChanged: (_) {
              if (_weightError != null) {
                setState(() => _weightError = null);
              }
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DsTextField(
                  key: const Key('checkin-body-fat-field'),
                  controller: _bodyFatController,
                  label: '% grasa corporal (opcional)',
                  hint: 'Ej. 18.5',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !widget.isSubmitting,
                  errorText: _bodyFatError,
                  onChanged: (_) {
                    if (_bodyFatError != null) {
                      setState(() => _bodyFatError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DsTextField(
                  key: const Key('checkin-waist-field'),
                  controller: _waistController,
                  label: 'Cintura en cm (opcional)',
                  hint: 'Ej. 82.0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !widget.isSubmitting,
                  errorText: _waistError,
                  onChanged: (_) {
                    if (_waistError != null) {
                      setState(() => _waistError = null);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DsTextField(
            key: const Key('checkin-notes-field'),
            controller: _notesController,
            label: 'Notas del día (opcional)',
            hint: 'Ej. Medición en ayunas, buen descanso',
            enabled: !widget.isSubmitting,
          ),
          const SizedBox(height: 14),
          _PhotoSlotButton(
            selectedPhotoLabel: widget.selectedPhotoLabel,
            hasPhoto: hasPhoto,
            enabled: !widget.isSubmitting,
            onTap: widget.onSelectPhoto,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: widget.isSubmitting ? 'Guardando...' : 'Guardar check-in',
            onPressed: widget.isSubmitting ? null : _handleSubmit,
          ),
          if (widget.feedbackMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.feedbackMessage!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoSlotButton extends StatelessWidget {
  const _PhotoSlotButton({
    required this.selectedPhotoLabel,
    required this.hasPhoto,
    required this.enabled,
    this.onTap,
  });

  final String? selectedPhotoLabel;
  final bool hasPhoto;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.inner),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.inner),
            color: AppColors.controlFillIdle,
            border: Border.all(
              color: hasPhoto
                  ? AppColors.glassBorderStrong
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.option),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(
                  hasPhoto
                      ? Icons.photo_library_outlined
                      : Icons.add_a_photo_outlined,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPhoto
                          ? 'Foto adjunta al check-in'
                          : 'Agregar foto de progreso',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedPhotoLabel ??
                          'Opcional · Cámara o galería privada',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
