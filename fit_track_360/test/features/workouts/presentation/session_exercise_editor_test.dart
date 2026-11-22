import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/session_exercise_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage implements SessionStorage {
  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      'access';
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

void main() {
  testWidgets('selecciona ejercicio y construye series editables', (
    tester,
  ) async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.toString());
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': '0001',
              'name': 'Sentadilla',
              'bodyPart': 'upper legs',
              'equipment': 'body weight',
              'target': 'quads',
              'attribution': 'Gym Visual',
            },
          ],
          'total': 1,
          'page': 1,
          'pageSize': 20,
        }),
        200,
      );
    });
    var sets = <PlannedSet>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionExerciseEditor(
            initial: null,
            api: ExercisesApi(
              ApiClient(storage: _Storage(), httpClient: client),
            ),
            onChanged: (_, value) => sets = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Añadir ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sentadilla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Reps'), '12');
    await tester.tap(find.text('Añadir serie'));
    await tester.pumpAndSettle();
    expect(sets.map((s) => [s.exerciseId, s.order, s.reps, s.weightKg]), [
      ['0001', 1, 12, 0.0],
      ['0001', 2, 12, 0.0],
    ]);
    expect(paths.single, contains('page=1'));
  });
}
