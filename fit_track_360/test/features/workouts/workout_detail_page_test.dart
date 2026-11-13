import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/data/workouts_repository_impl.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_workouts_repository.dart';

Future<void> _pump(WidgetTester tester, FakeWorkoutsRepository repository) {
  return tester.pumpWidget(
    MaterialApp(
      home: WorkoutDetailPage(sessionId: 'actual', repository: repository),
    ),
  );
}

void main() {
  testWidgets('muestra duración, volumen, series, ejercicios y notas', (
    tester,
  ) async {
    await _pump(tester, FakeWorkoutsRepository(sessions: [fakeSession()]));
    await tester.pumpAndSettle();

    expect(find.text('Duración'), findsOneWidget);
    expect(find.text('1 h 0 min'), findsOneWidget);
    expect(find.text('Volumen'), findsOneWidget);
    expect(find.text('1600 kg'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Sentadilla · 2 series'), findsOneWidget);
    expect(find.text('Press banca · 1 serie'), findsOneWidget);
    expect(find.text('Buen progreso en sentadilla'), findsOneWidget);
  });

  testWidgets('valores y títulos usan el color de texto principal', (
    tester,
  ) async {
    await _pump(tester, FakeWorkoutsRepository(sessions: [fakeSession()]));
    await tester.pumpAndSettle();

    // Regresión: se usaba el estilo de botón (texto oscuro sobre acento) y no
    // se leía sobre el fondo oscuro.
    for (final label in ['1 h 0 min', '1600 kg', 'Ejercicios', 'Notas']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.color, AppColors.textPrimary, reason: label);
    }
  });

  testWidgets('muestra la comparación cuando hay una sesión anterior', (
    tester,
  ) async {
    final previous = fakeSession(
      id: 'anterior',
      startedAt: detailStart.subtract(const Duration(days: 2)),
      duration: const Duration(minutes: 45),
      sets: const [
        WorkoutSet(exerciseName: 'Sentadilla', weightKg: 90, reps: 5),
      ],
    );
    await _pump(
      tester,
      FakeWorkoutsRepository(sessions: [fakeSession(), previous]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comparación con la sesión anterior'), findsOneWidget);
    expect(find.text('+15 min'), findsOneWidget);
    expect(find.text('+1150 kg'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('sin sesión previa muestra el aviso y no bloquea el resumen', (
    tester,
  ) async {
    await _pump(tester, FakeWorkoutsRepository(sessions: [fakeSession()]));
    await tester.pumpAndSettle();

    expect(
      find.text('Aún no hay una sesión anterior para comparar.'),
      findsOneWidget,
    );
    expect(find.text('1600 kg'), findsOneWidget);
  });

  testWidgets('sesión en curso y sin series muestra estados claros', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeWorkoutsRepository(
        sessions: [fakeSession(duration: null, notes: null, sets: const [])],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('0 kg'), findsOneWidget);
    expect(find.text('Sin ejercicios registrados'), findsOneWidget);
    expect(find.text('Sin notas'), findsOneWidget);
  });

  testWidgets('error al cargar muestra el mensaje y reintentar', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeWorkoutsRepository(
        sessions: const [],
        getError: const AuthApiException('No se pudo conectar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Duración'), findsNothing);
  });

  testWidgets('carga la sesión por id desde el API real con MockClient', (
    tester,
  ) async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      final body = request.url.path.endsWith('/actual')
          ? _sessionJson()
          : [_sessionJson()];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final repository = ApiWorkoutsRepository(
      WorkoutsApi(ApiClient(storage: FakeSessionStorage(), httpClient: client)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutDetailPage(sessionId: 'actual', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(requested, contains('/api/v1/workouts/actual'));
    expect(find.text('1 h 15 min'), findsOneWidget);
    expect(find.text('Sin ejercicios registrados'), findsOneWidget);
  });
}

Map<String, dynamic> _sessionJson() => {
  'id': 'actual',
  'userId': 'u1',
  'startedAt': '2026-11-04T10:00:00.000Z',
  'endedAt': '2026-11-04T11:15:00.000Z',
  'notes': 'Pierna',
  'createdAt': '2026-11-04T10:00:00.000Z',
  'updatedAt': '2026-11-04T11:15:00.000Z',
};
