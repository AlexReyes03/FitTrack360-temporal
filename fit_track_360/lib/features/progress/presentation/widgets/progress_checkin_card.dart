import 'package:flutter/material.dart';

import '../../../../design_system/components/primary_button.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/widgets/ds_text_field.dart';
import 'progress_section_shell.dart';

/// Valores capturados en el formulario visual de check-in.
class ProgressCheckInDraft {
  const ProgressCheckInDraft({
    required this.weightText,
    required this.notesText,
    required this.hasPhotoSelected,
  });

  final String weightText;
  final String notesText;
  final bool hasPhotoSelected;
}

/// Formulario Liquid Glass de check-in diario: peso, notas y slot de foto P1.
class ProgressCheckInCard extends StatefulWidget {
  const ProgressCheckInCard({
    super.key,
    this.status = ProgressSectionStatus.data,
    this.initialWeightText = '',
    this.initialNotesText = '',
    this.selectedPhotoLabel,
    this.isSubmitting = false,
    this.onSelectPhoto,
    this.onSubmit,
    this.onRetry,
  });

  final ProgressSectionStatus status;
  final String initialWeightText;
  final String initialNotesText;
  final String? selectedPhotoLabel;
  final bool isSubmitting;
  final VoidCallback? onSelectPhoto;
  final ValueChanged<ProgressCheckInDraft>? onSubmit;
  final VoidCallback? onRetry;

  @override
  State<ProgressCheckInCard> createState() => _ProgressCheckInCardState();
}

class _ProgressCheckInCardState extends State<ProgressCheckInCard> {
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  String? _weightError;
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.initialWeightText);
    _notesController = TextEditingController(text: widget.initialNotesText);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final weight = _weightController.text.trim();
    if (weight.isEmpty) {
      setState(() {
        _weightError = 'Ingresa tu peso en kg para guardar el check-in.';
        _feedbackMessage = null;
      });
      return;
    }

    setState(() {
      _weightError = null;
      _feedbackMessage = 'Check-in listo para guardar ($weight kg).';
    });

    widget.onSubmit?.call(
      ProgressCheckInDraft(
        weightText: weight,
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
            controller: _weightController,
            label: 'Peso corporal (kg)',
            hint: 'Ej. 74.2',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !widget.isSubmitting,
            errorText: _weightError,
            onChanged: (_) {
              if (_weightError != null || _feedbackMessage != null) {
                setState(() {
                  _weightError = null;
                  _feedbackMessage = null;
                });
              }
            },
          ),
          const SizedBox(height: 14),
          DsTextField(
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
          if (_feedbackMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _feedbackMessage!,
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
