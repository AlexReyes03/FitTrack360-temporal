import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:fit_track_360/features/exercises/presentation/exercises_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/exercise_test_support.dart';

Future<FakeSessionStorage> pumpCatalogue(
  WidgetTester tester, {
  required MockClient client,
}) async {
  final storage = FakeSessionStorage();
  final api = ExercisesApi(ApiClient(storage: storage, httpClient: client));
  final router = GoRouter(
    initialLocation: '/app/ejercicios',
    routes: [
      GoRoute(path: '/app', builder: (context, state) => const Text('Home')),
      GoRoute(
        path: '/app/ejercicios',
        builder: (context, state) => ExercisesPage(api: api),
      ),
      GoRoute(
        path: '/app/ejercicios/:id',
        builder: (context, state) =>
            Text('Detalle ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Text('Pantalla login'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  return storage;
}

/// Avanza petición, dropdowns y transición sin `pumpAndSettle`, que no termina
/// por el indicador de carga.
Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('muestra carga y luego los datos con contador', (tester) async {
    final pending = Completer<http.Response>();
    await pumpCatalogue(
      tester,
      client: MockClient((request) => pending.future),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(jsonResponse(pageJson([exerciseJson()], total: 1324)));
    await flush(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('1324 resultados'), findsOneWidget);
    expect(find.text('3/4 sit-up'), findsOneWidget);
    expect(find.text('Cintura'), findsOneWidget);
    expect(find.text('Peso corporal'), findsOneWidget);
    expect(find.textContaining('Gym visual'), findsOneWidget);
    expect(find.text('Página 1 de 67'), findsOneWidget);
  });

  testWidgets('singulariza el contador con un solo resultado', (tester) async {
    await pumpCatalogue(
      tester,
      client: MockClient(
        (request) async => jsonResponse(pageJson([exerciseJson()])),
      ),
    );
    await flush(tester);

    expect(find.text('1 resultado'), findsOneWidget);
  });

  testWidgets('muestra el estado vacío sin filtros', (tester) async {
    await pumpCatalogue(
      tester,
      client: MockClient(
        (request) async => jsonResponse(pageJson(const [], total: 0)),
      ),
    );
    await flush(tester);

    expect(
      find.text('El catálogo todavía no tiene ejercicios.'),
      findsOneWidget,
    );
    expect(find.text('Limpiar filtros'), findsNothing);
  });

  testWidgets('muestra error y reintenta la misma página', (tester) async {
    var calls = 0;
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        calls++;
        if (calls == 1) throw http.ClientException('sin red');
        return jsonResponse(pageJson([exerciseJson()]));
      }),
    );
    await flush(tester);

    expect(find.text('No se pudo conectar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await flush(tester);

    expect(calls, 2);
    expect(find.text('3/4 sit-up'), findsOneWidget);
    expect(find.text('No se pudo conectar'), findsNothing);
  });

  testWidgets('la búsqueda envía q y reinicia a la página 1', (tester) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(pageJson([exerciseJson()], total: 1324));
      }),
    );
    await flush(tester);

    await tester.tap(find.text('Siguiente'));
    await flush(tester);
    expect(urls.last.queryParameters['page'], '2');

    await tester.enterText(find.byType(TextField), 'press');
    await tester.pump(const Duration(milliseconds: 400));
    await flush(tester);

    expect(urls.last.queryParameters['q'], 'press');
    expect(urls.last.queryParameters['page'], '1');
    expect(urls.last.queryParameters.containsKey('bodyPart'), isFalse);
  });

  testWidgets('el filtro de músculo envía bodyPart y reinicia la página', (
    tester,
  ) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(pageJson([exerciseJson()], total: 1324));
      }),
    );
    await flush(tester);

    await tester.tap(find.text('Siguiente'));
    await flush(tester);
    expect(urls.last.queryParameters['page'], '2');

    await tester.tap(find.text('Todos').first);
    await flush(tester);
    await tester.tap(find.text('Pecho').last);
    await flush(tester);

    expect(urls.last.queryParameters['bodyPart'], 'chest');
    expect(urls.last.queryParameters['page'], '1');
  });

  testWidgets('el filtro de equipo envía equipment', (tester) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(pageJson([exerciseJson()]));
      }),
    );
    await flush(tester);

    await tester.tap(find.text('Todos').at(1));
    await flush(tester);
    await tester.tap(find.text('Mancuerna').last);
    await flush(tester);

    expect(urls.last.queryParameters['equipment'], 'dumbbell');
  });

  testWidgets('el filtro de objetivo envía target', (tester) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(pageJson([exerciseJson()]));
      }),
    );
    await flush(tester);

    await tester.tap(find.text('Todos').at(2));
    await flush(tester);
    // "Abductores" es el primer objetivo de la lista y queda visible en el menú.
    await tester.tap(find.text('Abductores').last);
    await flush(tester);

    expect(urls.last.queryParameters['target'], 'abductors');
  });

  testWidgets('pagina hacia adelante y atrás', (tester) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(
          pageJson(
            [exerciseJson()],
            total: 1324,
            page: int.parse(request.url.queryParameters['page']!),
          ),
        );
      }),
    );
    await flush(tester);
    expect(find.text('Página 1 de 67'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await flush(tester);

    expect(urls.last.queryParameters['page'], '2');
    expect(find.text('Página 2 de 67'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await flush(tester);

    expect(urls.last.queryParameters['page'], '1');
    expect(find.text('Página 1 de 67'), findsOneWidget);
  });

  testWidgets('una página nueva descarta la búsqueda que aún no venció', (
    tester,
  ) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(
          pageJson(
            [exerciseJson()],
            total: 1324,
            page: int.parse(request.url.queryParameters['page']!),
          ),
        );
      }),
    );
    await flush(tester);
    expect(find.text('Página 1 de 67'), findsOneWidget);

    // Escribe y, antes de que venza el debounce, pide la página siguiente.
    await tester.enterText(find.byType(TextField), 'press');
    await tester.tap(find.text('Siguiente'));
    await tester.pump(const Duration(milliseconds: 400));
    await flush(tester);

    // El debounce vencido no debe devolver al usuario a la página 1.
    expect(urls.last.queryParameters['page'], '2');
    expect(urls.last.queryParameters['q'], 'press');
    expect(find.text('Página 2 de 67'), findsOneWidget);
  });

  testWidgets('sesión expirada manda a login', (tester) async {
    await pumpCatalogue(
      tester,
      client: MockClient((request) async => jsonResponse({}, status: 401)),
    );
    await flush(tester);

    expect(find.text('Pantalla login'), findsOneWidget);
  });

  testWidgets('tocar una tarjeta navega al detalle con su id', (tester) async {
    await pumpCatalogue(
      tester,
      client: MockClient(
        (request) async => jsonResponse(pageJson([exerciseJson(id: '0007')])),
      ),
    );
    await flush(tester);

    await tester.tap(find.text('3/4 sit-up'));
    await flush(tester);

    expect(find.text('Detalle 0007'), findsOneWidget);
  });

  testWidgets('el vacío con filtros permite limpiarlos', (tester) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(pageJson(const [], total: 0));
      }),
    );
    await flush(tester);

    await tester.tap(find.text('Todos').first);
    await flush(tester);
    await tester.tap(find.text('Pecho').last);
    await flush(tester);

    expect(
      find.text('No encontramos ejercicios con esos filtros.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Limpiar filtros'));
    await flush(tester);

    expect(urls.last.queryParameters.containsKey('bodyPart'), isFalse);
  });
}
