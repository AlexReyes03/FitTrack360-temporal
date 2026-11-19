import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import 'dashboard_block_shell.dart';

/// Bloque de accesos rápidos táctiles a entrenamiento, comida y foto de progreso.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
    this.onWorkoutTap,
    this.onMealTap,
    this.onPhotoTap,
  });

  final VoidCallback? onWorkoutTap;
  final VoidCallback? onMealTap;
  final VoidCallback? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return DashboardBlockShell(
      title: 'Accesos rápidos',
      icon: Icons.bolt_outlined,
      child: Row(
        children: [
          Expanded(
            child: _QuickActionTile(
              icon: Icons.fitness_center_rounded,
              label: 'Entrenamiento',
              onTap: onWorkoutTap,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.restaurant_menu_rounded,
              label: 'Comida',
              onTap: onMealTap,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.photo_camera_outlined,
              label: 'Foto progreso',
              onTap: onPhotoTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.option),
            color: _pressed
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.045),
            border: Border.all(
              color: _pressed
                  ? AppColors.glassBorderStrong
                  : AppColors.glassBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 22, color: AppColors.textPrimary),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.zinc200,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
