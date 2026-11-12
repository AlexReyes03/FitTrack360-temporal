import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:fit_track_360/features/exercises/presentation/exercise_detail_page.dart';
import 'package:fit_track_360/features/exercises/presentation/widgets/exercise_media_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/exercise_test_support.dart';

Future<void> pumpDetail(
  WidgetTester tester, {
  required MockClient client,
  String id = '0001',
}) async {
  // Superficie alta para que el ListView construya también las secciones de
  // abajo (pasos, errores comunes, atribución).
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final api = ExercisesApi(
    ApiClient(storage: FakeSessionStorage(), httpClient: client),
  );
  final router = GoRouter(
    initialLocation: '/app/ejercicios/$id',
    routes: [
      GoRoute(
        path: '/app/ejercicios',
        builder: (context, state) => const Text('Catálogo'),
      ),
      GoRoute(
        path: '/app/ejercicios/:id',
        builder: (context, state) => ExerciseDetailPage(
          exerciseId: state.pathParameters['id']!,
          api: api,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Text('Pantalla login'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
}

Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// URL de la imagen que está pintando el widget con esa [key].
String? imageUrlFor(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) return null;
  final widget = tester.widget<Image>(finder);
  final provider = widget.image;
  return provider is NetworkImage ? provider.url : null;
}

void main() {
  testWidgets('muestra el detalle completo', (tester) async {
    await pumpDetail(
      tester,
      client: MockClient(
        (request) async => jsonResponse(
          exerciseJson(
            nameEs: 'Sentadilla 3/4',
            level: 'beginner',
            instructionsEs:
                'Túmbate sobre tu espalda con las rodillas flexionadas.',
            instructionStepsEs: const [
              'Túmbate sobre tu espalda.',
              'Levanta el torso.',
            ],
            secondaryMuscles: const ['hip flexors', 'lower back'],
            muscleGroup: 'hip flexors',
            commonErrors: 'No curvar la espalda.',
          ),
        ),
      ),
    );
    await flush(tester);

    expect(find.text('3/4 sit-up'), findsOneWidget);
    expect(find.text('Sentadilla 3/4'), findsOneWidget);
    expect(find.text('Nivel: beginner'), findsOneWidget);
    expect(
      find.text('Túmbate sobre tu espalda con las rodillas flexionadas.'),
      findsOneWidget,
    );
    expect(find.text('Pasos'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Túmbate sobre tu espalda.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('Levanta el torso.'), findsOneWidget);
    expect(find.text('Objetivo: Abdominales'), findsOneWidget);
    expect(find.text('Grupo: Flexores de cadera'), findsOneWidget);
    expect(
      find.text('Secundarios: Flexores de cadera, Espalda baja'),
      findsOneWidget,
    );
    expect(find.text('Errores comunes'), findsOneWidget);
    expect(find.text('No curvar la espalda.'), findsOneWidget);
    expect(find.text('Atribución'), findsOneWidget);
    expect(find.textContaining('Gym visual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oculta los campos opcionales ausentes', (tester) async {
    await pumpDetail(
      tester,
      client: MockClient((request) async => jsonResponse(exerciseJson())),
    );
    await flush(tester);

    expect(find.text('3/4 sit-up'), findsOneWidget);
    expect(find.textContaining('Nivel:'), findsNothing);
    expect(find.text('Instrucciones'), findsNothing);
    expect(find.text('Pasos'), findsNothing);
    expect(find.text('Errores comunes'), findsNothing);
    expect(find.text('Secundarios:'), findsNothing);
    expect(find.text('Grupo:'), findsNothing);
    // La atribución no es opcional: siempre se muestra.
    expect(find.textContaining('Gym visual'), findsOneWidget);
  });

  testWidgets('usa el GIF animado cuando existe', (tester) async {
    await pumpDetail(
      tester,
      client: MockClient((request) async => jsonResponse(exerciseJson())),
    );
    await flush(tester);

    expect(imageUrlFor(tester, ExerciseMediaView.gifKey), isNotNull);
    expect(
      imageUrlFor(tester, ExerciseMediaView.gifKey),
      endsWith('/static/exercises/videos/0001-2gPfomN.gif'),
    );
  });

  testWidgets('cae a la imagen JPG cuando no hay GIF', (tester) async {
    await pumpDetail(
      tester,
      client: MockClient(
        (request) async => jsonResponse(exerciseJson(gifFile: '')),
      ),
    );
    await flush(tester);

    expect(find.byKey(ExerciseMediaView.gifKey), findsNothing);
    expect(
      imageUrlFor(tester, ExerciseMediaView.imageKey),
      endsWith('/static/exercises/images/0001-2gPfomN.jpg'),
    );
  });

  testWidgets('un 404 muestra el mensaje propio del catálogo', (tester) async {
    await pumpDetail(
      tester,
      client: MockClient(
        (request) async => jsonResponse({'message': 'not found'}, status: 404),
      ),
    );
    await flush(tester);

    expect(find.text(ExercisesApi.notFoundMessage), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('reintenta el detalle tras un error de red', (tester) async {
    var calls = 0;
    await pumpDetail(
      tester,
      client: MockClient((request) async {
        calls++;
        if (calls == 1) throw http.ClientException('sin red');
        return jsonResponse(exerciseJson());
      }),
    );
    await flush(tester);

    expect(find.text('No se pudo conectar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await flush(tester);

    expect(calls, 2);
    expect(find.text('3/4 sit-up'), findsOneWidget);
  });

  testWidgets('sesión expirada manda a login', (tester) async {
    await pumpDetail(
      tester,
      client: MockClient((request) async => jsonResponse({}, status: 401)),
    );
    await flush(tester);

    expect(find.text('Pantalla login'), findsOneWidget);
  });

  testWidgets('el botón volver regresa al catálogo', (tester) async {
    await pumpDetail(
      tester,
      client: MockClient((request) async => jsonResponse(exerciseJson())),
    );
    await flush(tester);

    await tester.tap(find.byTooltip('Volver'));
    await flush(tester);

    expect(find.text('Catálogo'), findsOneWidget);
  });
}
