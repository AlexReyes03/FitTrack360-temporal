import 'package:flutter/material.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/app_background.dart';

/// Información sobre los datos y funciones implementadas en esta versión.
const privacyNoticeSections = <(String, String)>[
  (
    'Datos de la cuenta',
    'FitTrack360 registra nombre, usuario, correo y consentimiento. Firebase '
        'Auth gestiona el acceso a la cuenta.',
  ),
  (
    'Datos que registras',
    'Puedes guardar entrenamientos, series, rutinas, comidas, medidas '
        'corporales y fotografías. Las fotos se procesan para retirar EXIF '
        'y se almacenan junto con sus metadatos técnicos.',
  ),
  (
    'Uso de los datos',
    'Los datos se usan para administrar la cuenta y mostrar los registros '
        'personales de la cuenta.',
  ),
  (
    'Acceso y eliminación',
    'La API permite exportar los registros de la cuenta y solicitar su '
        'eliminación, incluidos archivos almacenados y la identidad de '
        'Firebase. Las opciones disponibles en la aplicación dependen de '
        'la versión instalada.',
  ),
  (
    'Salud y nutrición',
    'FitTrack360 es una herramienta de registro. No ofrece diagnósticos '
        'ni sustituye la atención médica o nutricional.',
  ),
];

class PrivacyNoticePage extends StatelessWidget {
  const PrivacyNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Aviso de privacidad',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              GlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Versión 2 · 16 de noviembre de 2026',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    for (final (title, body) in privacyNoticeSections) ...[
                      const SizedBox(height: 16),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
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
    );
  }
}
