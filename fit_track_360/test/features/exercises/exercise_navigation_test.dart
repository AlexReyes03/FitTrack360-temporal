import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:fit_track_360/features/exercises/presentation/exercise_detail_page.dart';
import 'package:fit_track_360/features/exercises/presentation/exercises_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';

import 'support/exercise_test_support.dart';

/// Router con las dos rutas reales del catálogo, como en `app/router.dart`.
GoRouter exerciseRouter(
  ExercisesApi api, {
  String location = '/app/ejercicios',
}) {
  return GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/app/ejercicios',
        builder: (context, state) => ExercisesPage(api: api),
      ),
      GoRoute(
        path: '/app/ejercicios/:id',
        builder: (context, state) => ExerciseDetailPage(
          exerciseId: state.pathParameters['id']!,
          api: api,
        ),
      ),
    ],
  );
}

MockClient catalogueClient() {
  return MockClient((request) async {
    if (request.url.path == '/api/v1/exercises') {
      return jsonResponse(
        pageJson([
          exerciseJson(id: '0001'),
          exerciseJson(id: '0002', name: 'bench press'),
        ], total: 2),
      );
    }
    if (request.url.path == '/api/v1/exercises/0001') {
      return jsonResponse(
        exerciseJson(instructionsEs: 'Túmbate sobre tu espalda.'),
      );
    }
    return jsonResponse({'message': 'not found'}, status: 404);
  });
}

Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Superficie alta para que el detalle construya todas sus secciones.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('del catálogo al detalle y de vuelta', (tester) async {
    useTallSurface(tester);
    final api = ExercisesApi(
      ApiClient(storage: FakeSessionStorage(), httpClient: catalogueClient()),
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: exerciseRouter(api)),
    );
    await flush(tester);

    expect(find.text('Ejercicios'), findsOneWidget);
    expect(find.text('3/4 sit-up'), findsOneWidget);

    await tester.tap(find.text('3/4 sit-up'));
    await flush(tester);

    expect(find.text('Ejercicio'), findsOneWidget);
    expect(find.text('Túmbate sobre tu espalda.'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await flush(tester);

    expect(find.text('Ejercicios'), findsOneWidget);
    expect(find.text('3/4 sit-up'), findsOneWidget);
  });

  testWidgets('un enlace directo abre el detalle del id', (tester) async {
    useTallSurface(tester);
    final api = ExercisesApi(
      ApiClient(storage: FakeSessionStorage(), httpClient: catalogueClient()),
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: exerciseRouter(api, location: '/app/ejercicios/0001'),
      ),
    );
    await flush(tester);

    expect(find.text('Ejercicio'), findsOneWidget);
    expect(find.text('3/4 sit-up'), findsOneWidget);
  });
}
