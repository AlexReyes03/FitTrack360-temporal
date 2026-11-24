import 'package:flutter/material.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/app_background.dart';

/// Aviso en lenguaje claro y coherente con lo que la app ofrece hoy:
/// «Exportar mis datos» y «Eliminar mi cuenta» viven en Perfil > Tus datos.
const privacyNoticeSections = <(String, String)>[
  (
    'Datos de la cuenta',
    'Guardamos tu nombre, tu nombre de usuario, tu correo y la fecha en que '
        'aceptaste este aviso. El inicio de sesión lo resuelve un servicio de '
        'autenticación seguro.',
  ),
  (
    'Datos que registras',
    'Puedes guardar entrenamientos, series, rutinas, comidas, medidas '
        'corporales y fotos de progreso. Antes de guardar una foto le '
        'quitamos la información oculta del archivo, como el lugar donde se '
        'tomó.',
  ),
  (
    'Para qué usamos tus datos',
    'Solo para administrar tu cuenta y mostrarte tus propios registros.',
  ),
  (
    'Copia y eliminación de tus datos',
    'En Perfil, dentro de «Tus datos», puedes usar «Exportar mis datos» para '
        'obtener una copia de todo lo que has registrado, y «Eliminar mi '
        'cuenta» para borrar tu cuenta con todos tus registros y fotos. La '
        'eliminación es definitiva y no se puede deshacer.',
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
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mismo encabezado que Perfil: volver + título de página.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Volver',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Aviso de privacidad',
                            style: AppTypography.pageTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      children: [
                        GlassSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Versión 2 · 16 de noviembre de 2026',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              for (final (title, body)
                                  in privacyNoticeSections) ...[
                                const SizedBox(height: 16),
                                Text(
                                  title,
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textPrimary,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
