import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../state/progress_view_state.dart';

/// Selector segmentado Liquid Glass para elegir rango temporal (7d a 1y).
class ProgressRangeSelector extends StatelessWidget {
  const ProgressRangeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ProgressRange selected;
  final ValueChanged<ProgressRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        color: AppColors.controlFillIdle,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: ProgressRange.values.map((range) {
          final isSelected = range == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: range.description,
              child: GestureDetector(
                onTap: () => onSelected(range),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    color: isSelected
                        ? AppColors.accentWhite
                        : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.16),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      range.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? AppColors.textOnAccent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
