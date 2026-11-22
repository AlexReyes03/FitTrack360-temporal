import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';

/// Aviso informativo breve en Home con superficie estilo `StatusBanner` del DS.
class DashboardMedicalNotice extends StatelessWidget {
  const DashboardMedicalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.banner),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.warningFill,
              borderRadius: BorderRadius.circular(AppRadii.banner),
              border: Border.all(color: AppColors.warningBorder),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      size: 18,
                      color: AppColors.warningText,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aviso médico: FitTrack360 es una herramienta de registro. No ofrece diagnósticos ni sustituye la atención médica o nutricional.',
                      style: TextStyle(
                        color: AppColors.warningText,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
