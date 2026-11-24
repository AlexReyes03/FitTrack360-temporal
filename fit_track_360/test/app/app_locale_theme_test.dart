import 'package:fit_track_360/app/app.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Teal por defecto de `ColorScheme.dark()` (secondary/tertiary de Material).
const Color _materialDefaultTeal = Color(0xFF03DAC6);

class _EmptyStorage implements SessionStorage {
  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

/// App mínima con la misma configuración de idioma y tema que `FitTrackApp`.
Widget _harness({required void Function(BuildContext) onOpen}) {
  return MaterialApp(
    theme: fitTrackDarkTheme,
    darkTheme: fitTrackDarkTheme,
    themeMode: ThemeMode.dark,
    locale: fitTrackLocale,
    supportedLocales: fitTrackSupportedLocales,
    localizationsDelegates: fitTrackLocalizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => onOpen(context),
            child: const Text('ABRIR'),
          ),
        ),
      ),
    ),
  );
}

/// Colores pintados por superficies y textos dentro del diálogo abierto.
Iterable<Color> _paintedColors(WidgetTester tester) sync* {
  final dialog = find.byType(Dialog);
  for (final m in tester.widgetList<Material>(
    find.descendant(of: dialog, matching: find.byType(Material)),
  )) {
    if (m.color != null) yield m.color!;
  }
  for (final c in tester.widgetList<Container>(
    find.descendant(of: dialog, matching: find.byType(Container)),
  )) {
    if (c.color != null) yield c.color!;
    final decoration = c.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      yield decoration.color!;
    }
    if (decoration is ShapeDecoration && decoration.color != null) {
      yield decoration.color!;
    }
  }
  for (final d in tester.widgetList<DecoratedBox>(
    find.descendant(of: dialog, matching: find.byType(DecoratedBox)),
  )) {
    final decoration = d.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      yield decoration.color!;
    }
    if (decoration is ShapeDecoration && decoration.color != null) {
      yield decoration.color!;
    }
  }
  for (final rt in tester.widgetList<RichText>(
    find.descendant(of: dialog, matching: find.byType(RichText)),
  )) {
    final color = rt.text.style?.color;
    if (color != null) yield color;
  }
}

/// Croma (max - min de RGB): ~0 para grises, blanco y negro de la paleta.
double _chroma(Color c) {
  final channels = [c.r, c.g, c.b];
  return channels.reduce((a, b) => a > b ? a : b) -
      channels.reduce((a, b) => a < b ? a : b);
}

bool _isTealish(Color c) {
  final hsv = HSVColor.fromColor(c);
  return hsv.saturation > 0.2 && hsv.hue >= 150 && hsv.hue <= 200;
}

void main() {
  group('Idioma es-MX', () {
    testWidgets(
      'FitTrackApp declara locale es_MX, título y delegates Global*',
      (tester) async {
        final previousStorage = appSessionStorage;
        appSessionStorage = _EmptyStorage();
        addTearDown(() => appSessionStorage = previousStorage);
        final viewModel = NotificationsViewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(FitTrackApp(notifications: viewModel));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.locale, const Locale('es', 'MX'));
        expect(app.title, 'FitTrack360');
        expect(app.supportedLocales, contains(const Locale('es', 'MX')));
        expect(app.localizationsDelegates, fitTrackLocalizationsDelegates);

        final context = tester.element(find.byType(Navigator).first);
        expect(Localizations.localeOf(context), const Locale('es', 'MX'));
        expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');
        expect(
          MaterialLocalizations.of(context).copyButtonLabel.toLowerCase(),
          'copiar',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('showDatePicker sale en español con selección monocroma', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          onOpen: (context) => showDatePicker(
            context: context,
            initialDate: DateTime(2026, 11, 24),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
        ),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.textContaining('noviembre'), findsWidgets);

      final colors = _paintedColors(tester).toList();
      expect(colors, contains(AppColors.accentWhite));
      expect(colors, contains(AppColors.bgMid));
      expect(colors.where(_isTealish), isEmpty);
    });

    testWidgets('showTimePicker sale en español, 24 h y sin turquesa', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          onOpen: (context) => showTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 18, minute: 30),
          ),
        ),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('18'), findsWidgets);
      expect(find.text('PM'), findsNothing);
      expect(find.text('p.m.'), findsNothing);

      final colors = _paintedColors(tester).toList();
      expect(colors, contains(AppColors.accentWhite));
      expect(colors, contains(AppColors.bgMid));
      expect(colors.where(_isTealish), isEmpty);
    });
  });

  group('Tema oscuro monocromo', () {
    test('el ColorScheme no conserva el teal por defecto de Material', () {
      final scheme = fitTrackDarkTheme.colorScheme;
      final roles = <String, Color>{
        'primary': scheme.primary,
        'primaryContainer': scheme.primaryContainer,
        'secondary': scheme.secondary,
        'onSecondary': scheme.onSecondary,
        'secondaryContainer': scheme.secondaryContainer,
        'onSecondaryContainer': scheme.onSecondaryContainer,
        'tertiary': scheme.tertiary,
        'onTertiary': scheme.onTertiary,
        'tertiaryContainer': scheme.tertiaryContainer,
        'onTertiaryContainer': scheme.onTertiaryContainer,
        'inversePrimary': scheme.inversePrimary,
        'surfaceTint': scheme.surfaceTint,
      };
      for (final entry in roles.entries) {
        expect(
          entry.value,
          isNot(_materialDefaultTeal),
          reason: '${entry.key} sigue en teal',
        );
        expect(
          _chroma(entry.value),
          lessThan(0.05),
          reason: '${entry.key} no es monocromo',
        );
      }
    });

    test('periodo del día seleccionado usa accentWhite con textOnAccent', () {
      final picker = fitTrackDarkTheme.timePickerTheme;
      const selected = {WidgetState.selected};
      expect(
        WidgetStateProperty.resolveAs(picker.dayPeriodColor, selected),
        AppColors.accentWhite,
      );
      expect(
        WidgetStateProperty.resolveAs(picker.dayPeriodTextColor, selected),
        AppColors.textOnAccent,
      );
      expect(picker.backgroundColor, AppColors.bgMid);
      expect(
        fitTrackDarkTheme.datePickerTheme.backgroundColor,
        AppColors.bgMid,
      );
    });
  });
}
