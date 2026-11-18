import 'dart:async';

import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_detail_page.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_detail_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_workouts_repository.dart';

/// Repositorio cuya carga de la sesión no termina hasta que la prueba lo
/// decide, para desmontar la pantalla a mitad de la petición.
class _SlowWorkoutsRepository extends FakeWorkoutsRepository {
  _SlowWorkoutsRepository() : super(sessions: [fakeSession()]);

  final pending = Completer<WorkoutSession>();

  @override
  Future<WorkoutSession> getById(String id) => pending.future;
}

GoRouter _router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/app/entrenamientos',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/app/entrenamientos/actual'),
              child: const Text('Listado de entrenamientos'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/app/entrenamientos/:id',
        builder: (context, state) => WorkoutDetailPage(
          sessionId: state.pathParameters['id']!,
          repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
        ),
      ),
    ],
  );
}

void main() {
  group('ciclo de vida', () {
    testWidgets(
      'desmontar la página durante la carga no notifica tras dispose',
      (tester) async {
        final repository = _SlowWorkoutsRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: WorkoutDetailPage(
              sessionId: 'actual',
              repository: repository,
            ),
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Se reemplaza la pantalla antes de que llegue la respuesta.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        repository.pending.complete(fakeSession());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    test('el view model no notifica si se libera antes de cargar', () async {
      final repository = _SlowWorkoutsRepository();
      final viewModel = WorkoutDetailViewModel(
        repository: repository,
        sessionId: 'actual',
      );
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final loading = viewModel.load();
      final beforeDispose = notifications;
      viewModel.dispose();
      repository.pending.complete(fakeSession());

      await expectLater(loading, completes);
      expect(notifications, beforeDispose);
    });
  });

  group('navegación de retorno', () {
    testWidgets('el botón Volver regresa al listado desde el detalle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: _router(initialLocation: '/app/entrenamientos'),
        ),
      );
      await tester.tap(find.text('Listado de entrenamientos'));
      await tester.pumpAndSettle();
      expect(find.text('Sesión'), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('Listado de entrenamientos'), findsOneWidget);
      expect(find.text('Sesión'), findsNothing);
    });

    testWidgets(
      'sin historial (enlace directo) Volver lleva al listado de entrenamientos',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: _router(
              initialLocation: '/app/entrenamientos/actual',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();

        expect(find.text('Listado de entrenamientos'), findsOneWidget);
      },
    );

    testWidgets('el control de retorno es visible mientras carga', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutDetailPage(
            sessionId: 'actual',
            repository: _SlowWorkoutsRepository(),
          ),
        ),
      );

      expect(find.byTooltip('Volver'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  testWidgets(
    'una sesión con fin anterior al inicio no muestra duración negativa',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutDetailPage(
            sessionId: 'actual',
            repository: FakeWorkoutsRepository(
              sessions: [fakeSession(duration: const Duration(minutes: -30))],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 min'), findsOneWidget);
      expect(find.textContaining('30 min'), findsNothing);
    },
  );
}
