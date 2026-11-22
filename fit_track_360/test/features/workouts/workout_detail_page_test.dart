import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/data/workouts_repository_impl.dart';
import 'package:fit_track_360/features/workouts/domain/workout_not_found_exception.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/domain/workout_summary_sharer.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_detail_page.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_detail_view_model.dart';
import 'package:fit_track_360/features/workouts/presentation/workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_workouts_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeWorkoutsRepository repository, {
  WorkoutSummarySharer? sharer,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: WorkoutDetailPage(
        sessionId: 'actual',
        repository: repository,
        sharer: sharer,
      ),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 300);
  await tester.pumpAndSettle();
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

    await _scrollTo(tester, find.text('Comparación con la sesión anterior'));
    expect(find.text('Comparación con la sesión anterior'), findsOneWidget);
    await _scrollTo(tester, find.text('+2'));
    expect(find.text('+15 min'), findsOneWidget);
    expect(find.text('+1150 kg'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('sin sesión previa muestra el aviso y no bloquea el resumen', (
    tester,
  ) async {
    await _pump(tester, FakeWorkoutsRepository(sessions: [fakeSession()]));
    await tester.pumpAndSettle();

    expect(find.text('1600 kg'), findsOneWidget);
    await _scrollTo(
      tester,
      find.text('Aún no hay una sesión anterior para comparar.'),
    );
    expect(
      find.text('Aún no hay una sesión anterior para comparar.'),
      findsOneWidget,
    );
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

  group('compartir', () {
    testWidgets('envía el resumen sin notas al pulsar Compartir', (
      tester,
    ) async {
      final sharer = FakeWorkoutSummarySharer();
      await _pump(
        tester,
        FakeWorkoutsRepository(sessions: [fakeSession()]),
        sharer: sharer,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compartir'));
      await tester.pumpAndSettle();

      final call = sharer.calls.single;
      expect(call.text, contains('Volumen: 1600 kg'));
      expect(call.text, isNot(contains('Buen progreso')));
      expect(call.origin, isNotNull);
    });

    testWidgets('cancelar la hoja no muestra error', (tester) async {
      final sharer = FakeWorkoutSummarySharer(
        result: WorkoutShareResult.dismissed,
      );
      await _pump(
        tester,
        FakeWorkoutsRepository(sessions: [fakeSession()]),
        sharer: sharer,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compartir'));
      await tester.pumpAndSettle();

      expect(find.text(workoutShareFailedMessage), findsNothing);
      expect(find.text('Compartir'), findsOneWidget);
    });

    testWidgets('un error muestra un mensaje neutro', (tester) async {
      final sharer = FakeWorkoutSummarySharer(error: StateError('interno'));
      await _pump(
        tester,
        FakeWorkoutsRepository(sessions: [fakeSession()]),
        sharer: sharer,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compartir'));
      await tester.pumpAndSettle();

      expect(find.text(workoutShareFailedMessage), findsOneWidget);
      expect(find.textContaining('interno'), findsNothing);
    });

    testWidgets(
      'no permite compartir dos veces mientras la hoja está abierta',
      (tester) async {
        final sharer = GatedWorkoutSummarySharer();
        await _pump(
          tester,
          FakeWorkoutsRepository(sessions: [fakeSession()]),
          sharer: sharer,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Compartir'));
        await tester.pump();
        expect(find.text('Compartiendo...'), findsOneWidget);

        await tester.tap(find.text('Compartiendo...'));
        await tester.pump();
        expect(sharer.calls, 1);

        sharer.gate.complete(WorkoutShareResult.shared);
        await tester.pumpAndSettle();
        expect(find.text('Compartir'), findsOneWidget);
      },
    );
  });

  group('repetir como borrador', () {
    testWidgets('navega con el borrador y no crea la sesión al pulsar', (
      tester,
    ) async {
      final api = _RecordingWorkoutsApi();
      final router = GoRouter(
        initialLocation: '/app/entrenamientos/actual',
        routes: [
          GoRoute(
            path: '/app/entrenamientos',
            builder: (context, state) => WorkoutsPage(
              api: api,
              draft: state.extra is WorkoutSessionDraft
                  ? state.extra as WorkoutSessionDraft
                  : null,
            ),
          ),
          GoRoute(
            path: '/app/entrenamientos/:id',
            builder: (context, state) => WorkoutDetailPage(
              sessionId: state.pathParameters['id']!,
              repository: FakeWorkoutsRepository(
                sessions: [repeatableSession()],
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repetir como borrador'));
      await tester.pumpAndSettle();

      expect(api.created, isEmpty);
      expect(find.text('Sentadilla'), findsOneWidget);
      expect(find.text('Press banca'), findsOneWidget);

      await tester.tap(find.text('Crear sesión'));
      await tester.pumpAndSettle();

      final draft = api.created.single;
      expect(draft.routineId, isNull);
      expect(draft.sets!.map((set) => set.order), [1, 2, 3]);
      expect(draft.sets!.map((set) => set.weightKg), [100, 110, 60]);
      expect(draft.sets!.map((set) => set.reps), [5, 3, 10]);
    });

    testWidgets('sin series identificables muestra el aviso y no navega', (
      tester,
    ) async {
      await _pump(tester, FakeWorkoutsRepository(sessions: [fakeSession()]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repetir como borrador'));
      await tester.pumpAndSettle();

      expect(find.text(workoutRepeatUnavailableMessage), findsOneWidget);
      expect(find.text('Sesión'), findsOneWidget);
    });
  });

  testWidgets('un 404 muestra el aviso y permite volver al listado', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/app/entrenamientos/otra',
      routes: [
        GoRoute(
          path: '/app/entrenamientos',
          builder: (context, state) =>
              const Scaffold(body: Text('Listado de sesiones')),
        ),
        GoRoute(
          path: '/app/entrenamientos/:id',
          builder: (context, state) => WorkoutDetailPage(
            sessionId: state.pathParameters['id']!,
            repository: FakeWorkoutsRepository(
              sessions: const [],
              getError: const WorkoutNotFoundException(),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Esta sesión no está disponible'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('Duración'), findsNothing);

    await tester.tap(find.text('Volver al listado'));
    await tester.pumpAndSettle();

    expect(find.text('Listado de sesiones'), findsOneWidget);
  });

  testWidgets('si falla el historial el resumen sigue visible', (tester) async {
    await _pump(
      tester,
      FakeWorkoutsRepository(
        sessions: [fakeSession()],
        listError: const AuthApiException('No se pudo conectar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1600 kg'), findsOneWidget);
    await _scrollTo(tester, find.text('No se pudo cargar la comparación.'));
    expect(find.text('No se pudo cargar la comparación.'), findsOneWidget);
  });

  testWidgets('duración actual nula en la comparación muestra «Sin dato»', (
    tester,
  ) async {
    final previous = fakeSession(
      id: 'anterior',
      startedAt: detailStart.subtract(const Duration(days: 2)),
    );
    await _pump(
      tester,
      FakeWorkoutsRepository(sessions: [fakeSession(duration: null), previous]),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Sin dato'));
    expect(find.text('Sin dato'), findsWidgets);
  });
}

class _RecordingWorkoutsApi implements WorkoutsApi {
  final created = <WorkoutSessionDraft>[];

  @override
  Future<List<WorkoutSession>> list() async => const [];

  @override
  Future<WorkoutSession> getById(String id) => throw UnimplementedError();

  @override
  Future<WorkoutSession> create(WorkoutSessionDraft draft) async {
    created.add(draft);
    return WorkoutSession(
      id: 'nueva',
      userId: 'u1',
      startedAt: draft.startedAt,
      endedAt: null,
      notes: draft.notes,
      createdAt: draft.startedAt,
      updatedAt: draft.startedAt,
    );
  }

  @override
  Future<WorkoutSession> createWithPayload(Map<String, dynamic> payload) async {
    final startedAt =
        DateTime.tryParse('${payload['startedAt']}') ??
        DateTime.utc(2026, 11, 10, 18);
    return WorkoutSession(
      id: 'nueva',
      userId: 'u1',
      startedAt: startedAt,
      endedAt: null,
      notes: payload['notes'] as String?,
      createdAt: startedAt,
      updatedAt: startedAt,
    );
  }
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
