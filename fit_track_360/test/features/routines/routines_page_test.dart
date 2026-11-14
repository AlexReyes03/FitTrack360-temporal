import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/routines/data/routines_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_routines_reader.dart';
import 'support/routines_test_app.dart';

RoutineSummary _summary({
  String id = 'r1',
  String name = 'Fuerza',
  String? notes,
  int? exerciseCount,
  int? targetSetCount,
}) {
  return RoutineSummary(
    id: id,
    name: name,
    notes: notes,
    exerciseCount: exerciseCount,
    targetSetCount: targetSetCount,
  );
}

void main() {
  testWidgets('muestra loading mientras carga el listado', (tester) async {
    final reader = FakeRoutinesReader()..listGate = Completer();

    await tester.pumpWidget(routinesTestApp(reader));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    reader.listGate!.complete([]);
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes rutinas.'), findsOneWidget);
  });

  testWidgets('muestra las rutinas con sus métricas', (tester) async {
    final reader = FakeRoutinesReader(
      routines: [
        _summary(
          name: 'Fuerza',
          notes: 'Empuje',
          exerciseCount: 2,
          targetSetCount: 7,
        ),
        _summary(id: 'r2', name: 'Pierna', exerciseCount: 1, targetSetCount: 3),
      ],
    );

    await tester.pumpWidget(routinesTestApp(reader));
    await tester.pumpAndSettle();

    expect(find.text('Fuerza'), findsOneWidget);
    expect(find.text('Empuje'), findsOneWidget);
    expect(find.text('2 ejercicios'), findsOneWidget);
    expect(find.text('7 series'), findsOneWidget);
    expect(find.text('1 ejercicio'), findsOneWidget);
    expect(find.text('3 series'), findsOneWidget);
  });

  testWidgets('muestra el vacío y permite actualizar', (tester) async {
    final reader = FakeRoutinesReader();

    await tester.pumpWidget(routinesTestApp(reader));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes rutinas.'), findsOneWidget);

    reader.routines = [_summary(name: 'Fuerza')];
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();

    expect(find.text('Fuerza'), findsOneWidget);
    expect(reader.listCalls, 2);
  });

  testWidgets('muestra el error y reintenta', (tester) async {
    final reader = FakeRoutinesReader(
      listError: const AuthApiException('Sin conexión'),
    );

    await tester.pumpWidget(routinesTestApp(reader));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);

    reader.listError = null;
    reader.routines = [_summary(name: 'Fuerza')];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Fuerza'), findsOneWidget);
    expect(reader.listCalls, 2);
  });

  testWidgets('navega al detalle de la rutina elegida', (tester) async {
    final reader = FakeRoutinesReader(
      routines: [_summary(id: 'r1', name: 'Fuerza')],
      detail: const RoutineDetail(id: 'r1', name: 'Fuerza'),
    );

    await tester.pumpWidget(routinesTestApp(reader));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fuerza'));
    await tester.pumpAndSettle();

    expect(reader.lastRequestedId, 'r1');
    expect(find.text('Ejercicios (0)'), findsOneWidget);
  });

  testWidgets('redirige al login si la sesión expiró', (tester) async {
    final reader = FakeRoutinesReader(
      listError: const SessionExpiredException(),
    );

    await tester.pumpWidget(routinesTestApp(reader));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });
}
