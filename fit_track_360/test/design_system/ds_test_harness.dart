import 'package:fit_track_360/app/app.dart';
import 'package:flutter/material.dart';

/// App mínima con el tema y el idioma reales de FitTrack360 para probar
/// componentes del DS de forma aislada.
Widget dsHarness(Widget child) {
  return MaterialApp(
    theme: fitTrackDarkTheme,
    darkTheme: fitTrackDarkTheme,
    themeMode: ThemeMode.dark,
    locale: fitTrackLocale,
    supportedLocales: fitTrackSupportedLocales,
    localizationsDelegates: fitTrackLocalizationsDelegates,
    home: Scaffold(body: Center(child: child)),
  );
}

/// Igual que [dsHarness] pero entrega un `BuildContext` dentro del Scaffold
/// para abrir diálogos, hojas o snackbars desde un botón «ABRIR».
Widget dsLauncher(void Function(BuildContext context) onOpen) {
  return dsHarness(
    Builder(
      builder: (context) => TextButton(
        onPressed: () => onOpen(context),
        child: const Text('ABRIR'),
      ),
    ),
  );
}

/// Teal por defecto de Material (`ColorScheme.dark().secondary`).
bool isTealish(Color c) {
  final hsv = HSVColor.fromColor(c);
  return hsv.saturation > 0.2 && hsv.hue >= 150 && hsv.hue <= 200;
}
