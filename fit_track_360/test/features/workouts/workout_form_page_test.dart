import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_workouts_repository.dart';

class _Api implements WorkoutsApi {
  final created = <WorkoutSessionDraft>[];

  @override
  Future<WorkoutSession> create(WorkoutSessionDraft draft) async {
    created.add(draft);
    return fakeSession();
  }

  @override
  Future<WorkoutSession> update(String id, Map<String, dynamic> payload) =>
      throw UnimplementedError();
  @override
  Future<WorkoutSession> createWithPayload(Map<String, dynamic> payload) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<WorkoutSession> getById(String id) => throw UnimplementedError();
  @override
  Future<List<WorkoutSession>> list() async => const [];
}

Future<void> _open(WidgetTester tester, _Api api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => WorkoutFormPage(api: api),
              ),
            ),
            child: const Text('Historial'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Historial'));
  await tester.pumpAndSettle();
}

Finder _field(String key) => find.byKey(Key(key));

void main() {
  testWidgets('sin cambios, Volver sale sin preguntar', (tester) async {
    await _open(tester, _Api());

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar cambios?'), findsNothing);
    expect(find.text('Historial'), findsOneWidget);
  });

  testWidgets('con cambios, Volver pregunta «¿Descartar cambios?»', (
    tester,
  ) async {
    await _open(tester, _Api());
    await tester.enterText(_field('workout-duration'), '30');
    await tester.pump();

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios?'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar entrenamiento pasado'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsOneWidget);
  });

  testWidgets('el gesto de volver del sistema también pregunta', (
    tester,
  ) async {
    await _open(tester, _Api());
    await tester.enterText(_field('workout-duration'), '30');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    expect(find.text('Registrar entrenamiento pasado'), findsOneWidget);
  });

  testWidgets('duración y descanso solo aceptan números', (tester) async {
    await _open(tester, _Api());

    await tester.enterText(_field('workout-duration'), '4a5-');
    await tester.enterText(_field('workout-rest'), '1.2x');
    await tester.pump();

    String text(String key) =>
        tester.widget<TextField>(_field(key)).controller!.text;
    expect(text('workout-duration'), '45');
    expect(text('workout-rest'), '12');
  });

  testWidgets('la duración vacía marca su campo y no guarda', (tester) async {
    final api = _Api();
    await _open(tester, api);
    await tester.enterText(_field('workout-duration'), '');
    await tester.pump();

    expect(find.text('Indica cuánto duró el entrenamiento'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Registrar entrenamiento'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('workout-form-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Registrar entrenamiento'));
    await tester.pumpAndSettle();

    expect(api.created, isEmpty);
    expect(
      find.text('Revisa las repeticiones, el peso y el descanso.'),
      findsNothing,
    );
  });
}
