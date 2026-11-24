import 'package:fit_track_360/design_system/tokens/app_typography.dart';
import 'package:fit_track_360/features/home/presentation/widgets/glass_bottom_nav_bar.dart';
import 'package:fit_track_360/features/home/presentation/widgets/home_navigation_shell.dart';
import 'package:fit_track_360/features/home/presentation/widgets/nav_placeholder_page.dart';
import 'package:fit_track_360/features/home/presentation/widgets/quick_actions_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const destinations = [
    GlassNavDestination(label: 'Inicio', icon: Icons.home_outlined),
    GlassNavDestination(label: 'Entrenos', icon: Icons.fitness_center_outlined),
    GlassNavDestination(label: 'Comidas', icon: Icons.restaurant_outlined),
    GlassNavDestination(
      label: 'Ejercicios',
      icon: Icons.sports_gymnastics_outlined,
    ),
    GlassNavDestination(label: 'Progreso', icon: Icons.photo_camera_outlined),
    GlassNavDestination(label: 'Perfil', icon: Icons.person_outline_rounded),
  ];

  testWidgets('HomeNavigationShell renderiza slots y notifica destino tocado', (
    tester,
  ) async {
    int? tappedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeNavigationShell(
          topBanner: const Text('Banner superior'),
          header: const Text('Cabecera'),
          body: const Center(child: Text('Cuerpo')),
          footer: const Text('Pie'),
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (index) => tappedIndex = index,
        ),
      ),
    );

    expect(find.text('Banner superior'), findsOneWidget);
    expect(find.text('Cabecera'), findsOneWidget);
    expect(find.text('Cuerpo'), findsOneWidget);
    expect(find.text('Pie'), findsOneWidget);
    expect(find.text('Ejercicios'), findsOneWidget);

    await tester.tap(find.text('Ejercicios'));
    await tester.pump();

    expect(tappedIndex, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuickActionsRow dispara callback al tocar un acceso rapido', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickActionsRow(
            actions: [
              QuickActionItem(
                label: 'Nuevo entreno',
                subtitle: 'Registrar sesión',
                icon: Icons.fitness_center_rounded,
                onTap: () => tapped = true,
              ),
              const QuickActionItem(
                label: 'Tracker diario',
                subtitle: 'Próximamente',
                icon: Icons.insights_rounded,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ACCESOS RÁPIDOS'), findsOneWidget);
    expect(find.text('Nuevo entreno'), findsOneWidget);
    expect(find.text('Tracker diario'), findsOneWidget);

    await tester.tap(find.text('Nuevo entreno'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets(
    'QuickActionsRow conserva su API, su Key y los roles tipográficos',
    (tester) async {
      const rowKey = ValueKey('quick-actions-row');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickActionsRow(
              key: rowKey,
              title: 'ATAJOS',
              actions: [
                QuickActionItem(
                  label: 'Nuevo entreno',
                  subtitle: 'Registrar sesión',
                  icon: Icons.fitness_center_rounded,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(rowKey), findsOneWidget);
      expect(
        tester.widget<QuickActionsRow>(find.byKey(rowKey)).title,
        'ATAJOS',
      );
      expect(
        tester.widget<Text>(find.text('ATAJOS')).style!.fontSize,
        AppTypography.meta.fontSize,
      );
      expect(
        tester.widget<Text>(find.text('Nuevo entreno')).style!.fontSize,
        AppTypography.body.fontSize,
      );
      expect(
        tester.widget<Text>(find.text('Registrar sesión')).style!.fontSize,
        AppTypography.micro.fontSize,
      );
      expect(QuickActionsRow(actions: const []).title, 'ACCESOS RÁPIDOS');
    },
  );

  testWidgets(
    'QuickActionsRow sin título no lo renderiza y sin onTap no actúa',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickActionsRow(
              title: null,
              actions: [
                QuickActionItem(label: 'Próximamente', icon: Icons.insights),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ACCESOS RÁPIDOS'), findsNothing);
      expect(find.text('Próximamente'), findsOneWidget);
      await tester.tap(find.text('Próximamente'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('NavPlaceholderPage muestra titulo y ejecuta onBack', (
    tester,
  ) async {
    var backed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: NavPlaceholderPage(
          title: 'Tracker diario',
          subtitle: 'Resumen de objetivos diarios.',
          onBack: () => backed = true,
        ),
      ),
    );

    expect(find.text('Tracker diario'), findsNWidgets(2));
    expect(find.text('Resumen de objetivos diarios.'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pump();
    expect(backed, isTrue);
  });
}
