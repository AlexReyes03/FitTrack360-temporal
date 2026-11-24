import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:fit_track_360/features/exercises/presentation/exercises_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../settings/fakes.dart' show FakeConnectivityService;
import 'support/exercise_test_support.dart';

Future<FakeSessionStorage> pumpCatalogue(
  WidgetTester tester, {
  required MockClient client,
  FakeConnectivityService? connectivity,
}) async {
  final storage = FakeSessionStorage();
  final api = ExercisesApi(ApiClient(storage: storage, httpClient: client));
  final router = GoRouter(
    initialLocation: '/app/ejercicios',
    routes: [
      GoRoute(path: '/app', builder: (context, state) => const Text('Home')),
      GoRoute(
        path: '/app/ejercicios',
        builder: (context, state) => ExercisesPage(
          api: api,
          connectivityService: connectivity ?? FakeConnectivityService(),
        ),
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

/// «Reintentar» de la vista de error (el banner offline tiene el suyo).
final _errorRetry = find.widgetWithText(TextButton, 'Reintentar');

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
  });

  testWidgets('los filtros usan nombres claros y el hint aclara el idioma', (
    tester,
  ) async {
    await pumpCatalogue(
      tester,
      client: MockClient(
        (request) async => jsonResponse(pageJson([exerciseJson()])),
      ),
    );
    await flush(tester);

    expect(find.text('Zona del cuerpo'), findsOneWidget);
    expect(find.text('Equipo'), findsOneWidget);
    expect(find.text('Músculo objetivo'), findsOneWidget);
    expect(find.text('Músculo'), findsNothing);
    expect(find.text('Objetivo'), findsNothing);
    expect(find.textContaining('en inglés'), findsOneWidget);
  });

  testWidgets('muestra nameEs como título cuando el API lo trae', (
    tester,
  ) async {
    await pumpCatalogue(
      tester,
      client: MockClient(
        (request) async =>
            jsonResponse(pageJson([exerciseJson(nameEs: 'Abdominal 3/4')])),
      ),
    );
    await flush(tester);

    expect(find.text('Abdominal 3/4'), findsOneWidget);
    expect(find.text('3/4 sit-up'), findsOneWidget);
  });

  testWidgets('con resultados y filtros muestra el chip Limpiar filtros', (
    tester,
  ) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        return jsonResponse(pageJson([exerciseJson()]));
      }),
    );
    await flush(tester);

    expect(find.text('Limpiar filtros'), findsNothing);

    await tester.tap(find.text('Todos').first);
    await flush(tester);
    await tester.tap(find.text('Pecho').last);
    await flush(tester);

    expect(urls.last.queryParameters['bodyPart'], 'chest');
    expect(find.text('3/4 sit-up'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros'));
    await flush(tester);

    expect(urls.last.queryParameters.containsKey('bodyPart'), isFalse);
    expect(find.text('Limpiar filtros'), findsNothing);
  });

  testWidgets('el pie de cargar más usa el estilo del DS', (tester) async {
    final pending = Completer<http.Response>();
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        if (page == 2) return pending.future;
        return jsonResponse(
          pageJson(
            List.generate(20, (i) => exerciseJson(id: '$i', name: 'E $i')),
            total: 40,
          ),
        );
      }),
    );
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pump();

    expect(find.text('Cargando más ejercicios…'), findsOneWidget);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, isNotNull);

    pending.completeError(http.ClientException('sin red'));
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await flush(tester);

    expect(find.text('Reintentar carga de ejercicios'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Reintentar carga de ejercicios'),
      findsNothing,
    );
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

    await tester.tap(_errorRetry);
    await flush(tester);

    expect(calls, 2);
    expect(find.text('3/4 sit-up'), findsOneWidget);
    expect(find.text('No se pudo conectar'), findsNothing);
  });

  testWidgets('búsqueda y filtro reinician resultados y página', (
    tester,
  ) async {
    final urls = <Uri>[];
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        final page = int.parse(request.url.queryParameters['page']!);
        final filtered =
            request.url.queryParameters.containsKey('q') ||
            request.url.queryParameters.containsKey('bodyPart');
        return jsonResponse(
          pageJson(
            List.generate(
              20,
              (i) => exerciseJson(
                id: '$page-$i',
                name: filtered ? 'Filtrado $i' : 'Ejercicio $page-$i',
              ),
            ),
            total: filtered ? 20 : 40,
            page: page,
          ),
        );
      }),
    );
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await flush(tester);
    expect(urls.last.queryParameters['page'], '2');
    await tester.enterText(find.byType(TextField), 'press');
    await tester.pump(const Duration(milliseconds: 400));
    await flush(tester);
    expect(urls.last.queryParameters['q'], 'press');
    expect(urls.last.queryParameters['page'], '1');
    expect(find.text('Ejercicio 2-0'), findsNothing);
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

  testWidgets('acumula páginas sin duplicar peticiones', (tester) async {
    final urls = <Uri>[];
    final pending = Completer<http.Response>();
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        urls.add(request.url);
        final page = int.parse(request.url.queryParameters['page']!);
        if (page == 2) return pending.future;
        return jsonResponse(
          pageJson(
            List.generate(
              20,
              (i) => exerciseJson(id: '$i', name: 'Ejercicio $i'),
            ),
            total: 40,
          ),
        );
      }),
    );
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pump();
    expect(urls.where((u) => u.queryParameters['page'] == '2').length, 1);
    pending.complete(
      jsonResponse(
        pageJson(
          List.generate(
            20,
            (i) => exerciseJson(id: '${i + 20}', name: 'Ejercicio ${i + 20}'),
          ),
          total: 40,
          page: 2,
        ),
      ),
    );
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, 3000));
    await flush(tester);
    expect(find.text('Ejercicio 0'), findsOneWidget);
    expect(urls.length, 2);
  });

  testWidgets('permite reintentar un fallo al cargar más', (tester) async {
    var pageTwoCalls = 0;
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        if (page == 2 && ++pageTwoCalls == 1) {
          throw http.ClientException('sin red');
        }
        return jsonResponse(
          pageJson(
            List.generate(
              20,
              (i) => exerciseJson(id: '$page-$i', name: 'Ejercicio $page-$i'),
            ),
            total: 40,
            page: page,
          ),
        );
      }),
    );
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await flush(tester);
    await tester.tap(find.text('Reintentar carga de ejercicios'));
    await flush(tester);
    expect(pageTwoCalls, 2);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await flush(tester);
    expect(find.text('Ejercicio 2-19'), findsOneWidget);
  });

  testWidgets('respuesta antigua se descarta al cambiar búsqueda', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await pumpCatalogue(
      tester,
      client: MockClient((request) async {
        if (request.url.queryParameters['page'] == '2') return pending.future;
        final filtered = request.url.queryParameters.containsKey('q');
        return jsonResponse(
          pageJson(
            List.generate(
              20,
              (i) => exerciseJson(
                id: '$i',
                name: filtered ? 'Filtrado $i' : 'Original $i',
              ),
            ),
            total: filtered ? 20 : 40,
          ),
        );
      }),
    );
    await flush(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'press');
    pending.complete(
      jsonResponse(
        pageJson([exerciseJson(name: 'Obsoleto')], total: 40, page: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await flush(tester);
    expect(find.text('Obsoleto'), findsNothing);
    expect(find.text('Filtrado 0'), findsOneWidget);
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

  group('conectividad', () {
    testWidgets('sin red muestra el banner offline', (tester) async {
      await pumpCatalogue(
        tester,
        client: MockClient(
          (request) async => jsonResponse(pageJson([exerciseJson()])),
        ),
        connectivity: FakeConnectivityService(online: false),
      );
      await flush(tester);

      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('sin red, Reintentar de la vista de error recarga los datos', (
      tester,
    ) async {
      var calls = 0;
      await pumpCatalogue(
        tester,
        client: MockClient((request) async {
          calls++;
          if (calls == 1) throw http.ClientException('sin red');
          return jsonResponse(pageJson([exerciseJson()]));
        }),
        connectivity: FakeConnectivityService(online: false),
      );
      await flush(tester);
      // Banner offline y vista de error muestran «Reintentar» a la vez.
      expect(find.text('Reintentar'), findsNWidgets(2));

      await tester.tap(_errorRetry);
      await flush(tester);

      expect(calls, 2);
      expect(find.text('3/4 sit-up'), findsOneWidget);
    });

    testWidgets('al recuperar la red tras un fallo recarga sola', (
      tester,
    ) async {
      var calls = 0;
      final connectivity = FakeConnectivityService(online: false);
      await pumpCatalogue(
        tester,
        client: MockClient((request) async {
          calls++;
          if (calls == 1) throw http.ClientException('sin red');
          return jsonResponse(pageJson([exerciseJson()]));
        }),
        connectivity: connectivity,
      );
      await flush(tester);
      expect(find.text('No se pudo conectar'), findsOneWidget);

      connectivity.emit(true);
      await flush(tester);

      expect(calls, 2);
      expect(find.text('3/4 sit-up'), findsOneWidget);
      expect(find.text('No se pudo conectar'), findsNothing);
    });

    testWidgets('recuperar la red con datos cargados no recarga', (
      tester,
    ) async {
      var calls = 0;
      final connectivity = FakeConnectivityService();
      await pumpCatalogue(
        tester,
        client: MockClient((request) async {
          calls++;
          return jsonResponse(pageJson([exerciseJson()]));
        }),
        connectivity: connectivity,
      );
      await flush(tester);

      connectivity.emit(true);
      await flush(tester);

      expect(calls, 1);
    });
  });
}
