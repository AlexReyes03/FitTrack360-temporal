import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';

/// Modelo visual para una tarjeta de acceso rapido en Home.
class QuickActionItem {
  const QuickActionItem({
    required this.label,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
}

/// Bloque de accesos rapidos con cards glass monocromas y estado tactil
/// Pressed segun el design system.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.actions,
    this.title = 'ACCESOS RÁPIDOS',
  });

  final String? title;
  final List<QuickActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null && title!.isNotEmpty) ...[
          Text(
            title!,
            style: const TextStyle(
              color: AppColors.zinc200,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 280;
            final spacing = 10.0;
            final itemWidth = twoColumns
                ? (constraints.maxWidth - spacing) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: itemWidth,
                    child: _QuickActionCard(action: action),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({required this.action});

  final QuickActionItem action;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.action.onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.action.label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: () => _setPressed(false),
          onTap: widget.action.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.option),
              color: _pressed
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: _pressed
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.badge),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Icon(
                    widget.action.icon,
                    size: 18,
                    color: AppColors.accentWhite,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.action.subtitle != null &&
                          widget.action.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.action.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
