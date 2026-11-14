import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/routines/data/routines_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_routines_reader.dart';
import 'support/routines_test_app.dart';

RoutineDetail _detail({
  String name = 'Full body',
  String? notes,
  List<Map<String, dynamic>> exercises = const [],
}) {
  return RoutineDetail.fromJson({
    'id': 'r1',
    'name': name,
    'notes': notes,
    'exercises': exercises,
  });
}

void main() {
  testWidgets('muestra loading mientras carga el detalle', (tester) async {
    final reader = FakeRoutinesReader()..detailGate = Completer();

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    reader.detailGate!.complete(_detail());
    await tester.pumpAndSettle();

    expect(find.text('Full body'), findsOneWidget);
  });

  testWidgets('muestra notas y ejercicios ordenados con objetivos', (
    tester,
  ) async {
    final reader = FakeRoutinesReader(
      detail: _detail(
        notes: 'Rutina de tres días',
        exercises: [
          {
            'exerciseId': 'e2',
            'position': 2,
            'exerciseName': 'Press banca',
            'targetSets': 3,
            'targetReps': 10,
          },
          {
            'exerciseId': 'e1',
            'position': 1,
            'exerciseName': 'Sentadilla',
            'targetSets': 4,
            'targetReps': 8,
          },
        ],
      ),
    );

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rutina de tres días'), findsOneWidget);
    expect(find.text('Ejercicios (2)'), findsOneWidget);
    expect(find.text('4 series × 8 reps'), findsOneWidget);
    expect(find.text('3 series × 10 reps'), findsOneWidget);

    final squat = tester.getTopLeft(find.text('Sentadilla')).dy;
    final bench = tester.getTopLeft(find.text('Press banca')).dy;
    expect(squat, lessThan(bench));
  });

  testWidgets('oculta las notas cuando no existen', (tester) async {
    final reader = FakeRoutinesReader(
      detail: _detail(
        exercises: [
          {'exerciseId': 'e1', 'position': 1, 'exerciseName': 'Sentadilla'},
        ],
      ),
    );

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.text('Rutina de tres días'), findsNothing);
  });

  testWidgets('oculta series y repeticiones cuando faltan', (tester) async {
    final reader = FakeRoutinesReader(
      detail: _detail(
        exercises: [
          {'exerciseId': 'e1', 'position': 1, 'exerciseName': 'Sentadilla'},
        ],
      ),
    );

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('series'), findsNothing);
    expect(find.textContaining('reps'), findsNothing);
  });

  testWidgets('avisa cuando la rutina no tiene ejercicios', (tester) async {
    final reader = FakeRoutinesReader(detail: _detail());

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esta rutina no tiene ejercicios.'), findsOneWidget);
  });

  testWidgets('muestra un mensaje claro ante un 404', (tester) async {
    final reader = FakeRoutinesReader(
      detailError: const RoutineNotFoundException(),
    );

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rutina no encontrada'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('muestra el error y reintenta el detalle', (tester) async {
    final reader = FakeRoutinesReader(
      detailError: const AuthApiException('Sin conexión'),
    );

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);

    reader.detailError = null;
    reader.detail = _detail();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Full body'), findsOneWidget);
    expect(reader.detailCalls, 2);
  });

  testWidgets('redirige al login si la sesión expiró', (tester) async {
    final reader = FakeRoutinesReader(
      detailError: const SessionExpiredException(),
    );

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('vuelve al listado desde el detalle', (tester) async {
    final reader = FakeRoutinesReader(detail: _detail(), routines: const []);

    await tester.pumpWidget(
      routinesTestApp(reader, initialLocation: '/app/rutinas/r1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Rutinas'), findsOneWidget);
    expect(find.text('Aún no tienes rutinas.'), findsOneWidget);
  });
}
