import 'package:fit_track_360/features/home/presentation/widgets/dashboard_block_shell.dart';
import 'package:fit_track_360/features/home/presentation/widgets/home_dashboard_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('renderiza todos los bloques del dashboard en preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const HomeDashboardContent(displayName: 'Alex')),
    );

    expect(find.text('Contenido proximo'), findsNothing);
    expect(find.text('Hola, Alex'), findsOneWidget);
    expect(find.text('Accesos rápidos'), findsOneWidget);
    expect(find.text('Entrenamiento'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Foto progreso'), findsOneWidget);
    expect(find.text('Nutrición de hoy'), findsOneWidget);
    expect(find.text('1480'), findsOneWidget);
    expect(find.text('Sesión de entrenamiento'), findsOneWidget);
    expect(find.text('Tren superior · Fuerza'), findsOneWidget);
    expect(find.text('Última métrica'), findsOneWidget);
    expect(find.text('74.2'), findsOneWidget);
    expect(find.text('Pasos de hoy'), findsOneWidget);
    expect(find.text('6420'), findsOneWidget);
    expect(find.textContaining('Aviso médico:'), findsOneWidget);
  });

  testWidgets(
    'renderiza estados visuales loading, empty, error y pasos no disponibles',
    (tester) async {
      var retried = false;

      await tester.pumpWidget(
        wrap(
          HomeDashboardContent(
            nutritionStatus: DashboardBlockStatus.loading,
            sessionStatus: DashboardBlockStatus.empty,
            metricStatus: DashboardBlockStatus.error,
            onRetryMetric: () => retried = true,
            stepsUnavailable: true,
          ),
        ),
      );

      expect(find.text('1480'), findsNothing);
      expect(
        find.textContaining('Aún no tienes sesiones registradas'),
        findsOneWidget,
      );
      expect(find.text('No pudimos cargar tu última métrica.'), findsOneWidget);
      expect(find.text('No disponible'), findsOneWidget);

      await tester.ensureVisible(find.text('Reintentar'));
      await tester.tap(find.text('Reintentar'));
      expect(retried, isTrue);
    },
  );

  testWidgets('dispara callbacks de accesos rápidos', (tester) async {
    var workoutTapped = false;
    var mealTapped = false;
    var photoTapped = false;

    await tester.pumpWidget(
      wrap(
        HomeDashboardContent(
          onOpenWorkout: () => workoutTapped = true,
          onOpenMeals: () => mealTapped = true,
          onOpenPhoto: () => photoTapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Entrenamiento'));
    await tester.tap(find.text('Comida'));
    await tester.tap(find.text('Foto progreso'));

    expect(workoutTapped, isTrue);
    expect(mealTapped, isTrue);
    expect(photoTapped, isTrue);
  });

  testWidgets('muestra el aviso médico aprobado', (tester) async {
    await tester.pumpWidget(wrap(const HomeDashboardContent()));

    expect(
      find.text(
        'Aviso médico: FitTrack360 es una herramienta de registro. '
        'No ofrece diagnósticos ni sustituye la atención médica o '
        'nutricional.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('no promete rutinas programadas', (tester) async {
    await tester.pumpWidget(wrap(const HomeDashboardContent()));

    expect(find.textContaining('programada'), findsNothing);
    expect(find.text('Sesión de entrenamiento'), findsOneWidget);
  });

  testWidgets('los accesos siguen activos si fallan los bloques remotos', (
    tester,
  ) async {
    var workoutTapped = false;
    var mealTapped = false;
    var photoTapped = false;

    await tester.pumpWidget(
      wrap(
        HomeDashboardContent(
          nutritionStatus: DashboardBlockStatus.error,
          sessionStatus: DashboardBlockStatus.error,
          metricStatus: DashboardBlockStatus.error,
          onOpenWorkout: () => workoutTapped = true,
          onOpenMeals: () => mealTapped = true,
          onOpenPhoto: () => photoTapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Entrenamiento'));
    await tester.tap(find.text('Comida'));
    await tester.tap(find.text('Foto progreso'));

    expect(workoutTapped, isTrue);
    expect(mealTapped, isTrue);
    expect(photoTapped, isTrue);
  });

  testWidgets('se adapta a una pantalla estrecha sin desbordarse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrap(const HomeDashboardContent()));

    expect(tester.takeException(), isNull);
    expect(find.text('Entrenamiento'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Foto progreso'), findsOneWidget);
  });
}
