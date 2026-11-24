import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../profile_view_model.dart';

// Controles glass de Perfil (UX-11). Son locales a la feature mientras el DS
// no tenga fila, interruptor, selector segmentado ni diálogo propios:
// migrar a `lib/design_system/` en #222.

const TextStyle _rowTitle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w600,
);
const TextStyle _rowSubtitle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 13,
  height: 1.4,
);

/// Fila con título, descripción e interruptor monocromo. Toda la fila es
/// tocable; [onChanged] null la deshabilita.
class ProfileSwitchRow extends StatelessWidget {
  const ProfileSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _rowTitle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: _rowSubtitle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                type: MaterialType.transparency,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: AppColors.textOnAccent,
                  activeTrackColor: AppColors.accentWhite,
                  inactiveThumbColor: AppColors.accentSilver,
                  inactiveTrackColor: AppColors.controlFillIdle,
                  trackOutlineColor: WidgetStateProperty.all(
                    AppColors.glassBorderStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector segmentado de dos o más opciones (estilo OptionTile).
class ProfileSegmentedSelector<T> extends StatelessWidget {
  const ProfileSegmentedSelector({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;

  /// null mientras se guarda otra preferencia.
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: _rowTitle),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final (index, value) in values.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _SegmentOption(
                    label: labelOf(value),
                    selected: value == selected,
                    onTap: onSelected == null || value == selected
                        ? null
                        : () => onSelected!(value),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.option),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      AppColors.accentSilver.withValues(alpha: 0.06),
                    ],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.035),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.48 : 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.accentWhite,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.accentWhite : AppColors.zinc200,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de acción (exportar, aviso, eliminar). Con [busy] muestra un
/// indicador y no responde a toques.
class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.busy = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.dangerText : AppColors.textPrimary;
    return Semantics(
      button: true,
      enabled: onTap != null && !busy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: destructive
                    ? AppColors.dangerText
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: _rowTitle.copyWith(color: color)),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentWhite,
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso junto a la acción: éxito en neutro con palomita, aviso en ámbar y
/// error en rojo (variantes Neutral / Warning / Danger de StatusBanner).
class ProfileFeedbackBanner extends StatelessWidget {
  const ProfileFeedbackBanner({super.key, required this.feedback, this.action});

  final ProfileFeedback feedback;

  /// Acción opcional bajo el texto (p. ej. «Abrir ajustes»).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (fill, border, text, icon) = switch (feedback.kind) {
      ProfileFeedbackKind.success => (
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.20),
        AppColors.zinc100,
        Icons.check_circle_outline_rounded,
      ),
      ProfileFeedbackKind.warning => (
        AppColors.warningFill,
        AppColors.warningBorder,
        AppColors.warningText,
        Icons.info_outline_rounded,
      ),
      ProfileFeedbackKind.error => (
        AppColors.dangerFill,
        AppColors.dangerBorder,
        AppColors.dangerText,
        Icons.error_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadii.banner),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: text, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feedback.text,
                    style: TextStyle(color: text, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// Botón secundario glass (texto claro sobre vidrio), para acciones que no
/// son la principal: «Cancelar», «Cerrar», «Abrir ajustes».
class ProfileGlassButton extends StatelessWidget {
  const ProfileGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.glassFillStrong, AppColors.glassFillSoft],
            ),
            border: Border.all(color: AppColors.glassBorderStrong),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre un diálogo con superficie glass (sin `AlertDialog` Material).
Future<T?> showProfileGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassSurface(child: builder(context)),
      ),
    ),
  );
}
