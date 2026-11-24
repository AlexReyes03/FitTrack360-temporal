import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/design_system/components/glass_surface.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/session_editor_view_model.dart';
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

Map<String, Object?> _exercise(String id, String name) => {
  'id': id,
  'name': name,
  'bodyPart': 'upper legs',
  'equipment': 'body weight',
  'target': 'quads',
  'attribution': 'Gym Visual',
};

/// Catálogo paginado de [total] ejercicios («Ejercicio 1»…).
MockClient _catalog({int total = 1, List<String>? paths}) {
  return MockClient((request) async {
    paths?.add(request.url.toString());
    final page = int.parse(request.url.queryParameters['page'] ?? '1');
    final size = int.parse(request.url.queryParameters['pageSize'] ?? '20');
    final names = total == 1
        ? ['Sentadilla']
        : [for (var i = 1; i <= total; i++) 'Ejercicio $i'];
    final start = (page - 1) * size;
    final items = [
      for (var i = start; i < start + size && i < names.length; i++)
        _exercise('${i + 1}'.padLeft(4, '0'), names[i]),
    ];
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'items': items,
          'total': names.length,
          'page': page,
          'pageSize': size,
        }),
      ),
      200,
    );
  });
}

Future<SessionEditorViewModel> _pumpEditor(
  WidgetTester tester, {
  required MockClient client,
  WorkoutSessionDraft? initial,
}) async {
  final vm = SessionEditorViewModel(initial: initial);
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SessionExerciseEditor(
            viewModel: vm,
            api: ExercisesApi(
              ApiClient(storage: _Storage(), httpClient: client),
            ),
          ),
        ),
      ),
    ),
  );
  return vm;
}

void main() {
  testWidgets('selecciona ejercicio y construye series editables', (
    tester,
  ) async {
    final paths = <String>[];
    final vm = await _pumpEditor(tester, client: _catalog(paths: paths));

    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sentadilla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reps-0-0')), '12');
    await tester.tap(find.text('Agregar serie'));
    await tester.pumpAndSettle();

    expect(vm.sets.map((s) => [s.exerciseId, s.order, s.reps, s.weightKg]), [
      ['0001', 1, 12, 0.0],
      ['0001', 2, 12, 0.0],
    ]);
    expect(paths.single, contains('page=1'));
  });

  testWidgets('el editor usa superficies glass y no Card de Material', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      client: _catalog(),
      initial: WorkoutSessionDraft(
        startedAt: DateTime.utc(2026, 11, 10),
        exercises: const [
          PlannedExercise(
            exerciseId: '0001',
            exerciseName: 'Sentadilla',
            position: 0,
            targetSets: 2,
            targetReps: 8,
          ),
        ],
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.text('2 series × 8 reps'), findsOneWidget);
  });

  testWidgets('el error se muestra en el campo y no se convierte en 0', (
    tester,
  ) async {
    final vm = await _pumpEditor(
      tester,
      client: _catalog(),
      initial: WorkoutSessionDraft(
        startedAt: DateTime.utc(2026, 11, 10),
        exercises: const [
          PlannedExercise(
            exerciseId: '0001',
            exerciseName: 'Sentadilla',
            position: 0,
            targetSets: 1,
            targetReps: 8,
          ),
        ],
      ),
    );

    await tester.enterText(find.byKey(const Key('reps-0-0')), '');
    await tester.pump();

    expect(find.text('Indica las repeticiones'), findsOneWidget);
    expect(vm.isValid, isFalse);

    await tester.enterText(find.byKey(const Key('reps-0-0')), '0');
    await tester.pump();
    expect(find.text('De 1 a 1000'), findsOneWidget);
  });

  testWidgets('repeticiones y peso solo aceptan números', (tester) async {
    await _pumpEditor(
      tester,
      client: _catalog(),
      initial: WorkoutSessionDraft(
        startedAt: DateTime.utc(2026, 11, 10),
        exercises: const [
          PlannedExercise(
            exerciseId: '0001',
            exerciseName: 'Sentadilla',
            position: 0,
            targetSets: 1,
            targetReps: 8,
          ),
        ],
      ),
    );

    await tester.enterText(find.byKey(const Key('reps-0-0')), '1a2-');
    await tester.enterText(find.byKey(const Key('weight-0-0')), '-4x0.5');
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('reps-0-0')))
          .controller!
          .text,
      '12',
    );
    final weight = tester
        .widget<TextField>(find.byKey(const Key('weight-0-0')))
        .controller!
        .text;
    expect(weight, isNot(contains('-')));
    expect(weight, isNot(contains('x')));
  });

  testWidgets('quitar un ejercicio ofrece «Deshacer»', (tester) async {
    final vm = await _pumpEditor(
      tester,
      client: _catalog(),
      initial: WorkoutSessionDraft(
        startedAt: DateTime.utc(2026, 11, 10),
        exercises: const [
          PlannedExercise(
            exerciseId: '0001',
            exerciseName: 'Sentadilla',
            position: 0,
            targetSets: 1,
            targetReps: 8,
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('Quitar ejercicio'));
    await tester.pumpAndSettle();
    expect(vm.blocks, isEmpty);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(vm.blocks.single.name, 'Sentadilla');
  });

  testWidgets('el selector carga más al llegar al final, sin paginación', (
    tester,
  ) async {
    final paths = <String>[];
    await _pumpEditor(tester, client: _catalog(total: 45, paths: paths));

    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();

    expect(find.text('Anterior'), findsNothing);
    expect(find.text('Siguiente'), findsNothing);
    expect(find.textContaining(' / '), findsNothing);

    final list = find.byKey(const Key('exercise-picker-list'));
    await tester.scrollUntilVisible(
      find.text('Ejercicio 45'),
      400,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ejercicio 45'), findsOneWidget);
    expect(paths.where((p) => p.contains('page=2')), hasLength(1));
    expect(paths.where((p) => p.contains('page=3')), hasLength(1));
  });

  testWidgets('el selector busca por nombre tras una pausa', (tester) async {
    final paths = <String>[];
    await _pumpEditor(tester, client: _catalog(paths: paths));

    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'sent');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(paths.last, contains('sent'));
  });
}
