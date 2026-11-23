import 'package:flutter/material.dart';

import '../../../../design_system/components/app_logo.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';

/// Header global del shell: logo de FitTrack360 y campana con badge de avisos
/// no leídos.
class AppShellHeader extends StatelessWidget {
  const AppShellHeader({
    super.key,
    required this.unreadCount,
    required this.onNotificationsTap,
  });

  final int unreadCount;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return Row(
      children: [
        const AppLogo(variant: AppLogoVariant.mark, height: 28),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'FITTRACK360',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: onNotificationsTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          style: IconButton.styleFrom(
            backgroundColor: hasUnread
                ? AppColors.glassFillStrong
                : AppColors.glassFillSoft,
            side: BorderSide(
              color: hasUnread
                  ? AppColors.glassBorderStrong
                  : AppColors.glassBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.option),
            ),
          ),
          icon: Badge.count(
            count: unreadCount,
            maxCount: 99,
            isLabelVisible: hasUnread,
            backgroundColor: AppColors.accentWhite,
            textColor: AppColors.textOnAccent,
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            offset: const Offset(5, -5),
            child: Icon(
              hasUnread
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 22,
              color: hasUnread
                  ? AppColors.accentWhite
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
