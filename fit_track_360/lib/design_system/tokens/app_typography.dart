import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const TextStyle pageTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 32,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.55,
    color: AppColors.textPrimary,
  );

  static const TextStyle cta = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 16,
    color: AppColors.textOnAccent,
  );
}
