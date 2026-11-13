import 'package:flutter/material.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/app_background.dart';

/// Secciones del aviso breve. Fuente única: `docs/copy/aviso-privacidad.md`
/// (versión 1, 2026-11-02); si el documento cambia, se actualiza aquí.
const privacyNoticeSections = <(String, String)>[
  (
    '',
    'Este aviso resume cómo tratamos tus datos personales cuando usas '
        'FitTrack360. El detalle completo, incluidos plazos, procedimientos y '
        'cambios, se encuentra en el aviso de privacidad integral.',
  ),
  (
    'Responsable del tratamiento',
    '[NOMBRE O RAZÓN SOCIAL DEL RESPONSABLE], con domicilio en [DOMICILIO DEL '
        'RESPONSABLE], es responsable del tratamiento de los datos personales '
        'que proporcionas al utilizar FitTrack360. Para asuntos de privacidad '
        'puedes contactarnos en [CORREO O MEDIO DE CONTACTO PARA PRIVACIDAD].',
  ),
  (
    'Datos que tratamos',
    'Cuenta: nombre, correo electrónico y datos de acceso necesarios para '
        'crear y administrar tu cuenta.\n'
        'Entrenamiento: rutinas, sesiones, ejercicios, series, repeticiones y '
        'cargas que registres.\n'
        'Alimentación: comidas, alimentos, calorías y macronutrientes que '
        'registres.\n'
        'Progreso: medidas corporales, peso y otros registros de seguimiento '
        'que decidas capturar.\n'
        'Fotografías opcionales: imágenes de progreso o de comidas, únicamente '
        'si eliges proporcionarlas y la función está disponible.\n\n'
        'Algunos datos relacionados con tu salud o composición corporal pueden '
        'considerarse datos personales sensibles. Su tratamiento requiere tu '
        'consentimiento expreso, otorgado de forma previa e informada, sin que '
        'ello impida el uso de las demás funciones que no dependan de esos '
        'datos.',
  ),
  (
    'Finalidades del tratamiento',
    'Crear, autenticar y administrar tu cuenta. Guardar y mostrarte tus '
        'registros, historial y progreso. Habilitar las funciones de '
        'seguimiento de entrenamiento, alimentación y progreso que elijas '
        'usar. Mantener la seguridad, integridad y operación del servicio, así '
        'como atender solicitudes de soporte. Cumplir obligaciones legales '
        'aplicables.\n\n'
        'No utilizamos tus datos para finalidades distintas sin informarte y, '
        'cuando corresponda, obtener tu consentimiento.',
  ),
  (
    'Uso y protección de tus datos',
    'No vendemos ni rentamos tus datos personales. Para operar el servicio '
        'pueden intervenir proveedores tecnológicos que traten información por '
        'nuestra cuenta, conforme al aviso de privacidad integral y a las '
        'medidas de seguridad aplicables.',
  ),
  (
    'Tus derechos ARCO y el aviso integral',
    'Puedes ejercer tus derechos de acceso, rectificación, cancelación y '
        'oposición (ARCO), así como solicitar información sobre el tratamiento '
        'de tus datos, mediante [CORREO O MEDIO DE CONTACTO PARA PRIVACIDAD] o '
        'el procedimiento que se habilite en [ENLACE O MÓDULO PARA EJERCER '
        'DERECHOS ARCO]. Tu solicitud debe permitir identificarte y describir '
        'claramente lo que deseas ejercer; atenderemos lo que corresponda '
        'conforme a la legislación aplicable.\n\n'
        'Consulta el aviso de privacidad integral en [ENLACE AL AVISO DE '
        'PRIVACIDAD INTEGRAL], donde se explican las finalidades, el '
        'tratamiento de datos sensibles, los medios para ejercer tus derechos '
        'y la forma en que se comunicarán los cambios. La versión y la fecha '
        'de este aviso aparecen al inicio del documento; cualquier '
        'actualización se identificará con una nueva versión.',
  ),
  (
    'Límite sobre salud y nutrición',
    'FitTrack360 es una herramienta de registro y seguimiento personal. No '
        'sustituye la atención médica ni nutricional, no emite prescripciones '
        'médicas ni nutricionales y no ofrece diagnósticos ni tratamientos. Si '
        'tienes dudas sobre tu salud, alimentación o entrenamiento, consulta a '
        'un profesional de la salud o de la nutrición, según corresponda.',
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
                      'Versión 1 · 2 de noviembre de 2026',
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
