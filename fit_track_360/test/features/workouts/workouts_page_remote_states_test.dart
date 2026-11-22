import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/widgets/remote_state_views.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/presentation/workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../settings/fakes.dart' show FakeConnectivityService;
import 'fake_workouts_repository.dart' show FakeSessionStorage;

/// API de sesiones que falla mientras [fail] sea true.
class _FlakyApi {
  bool fail = true;
  int calls = 0;

  late final WorkoutsApi api = WorkoutsApi(
    ApiClient(
      storage: FakeSessionStorage(),
      httpClient: MockClient((_) async {
        calls++;
        if (fail) throw http.ClientException('sin red');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'id': 'abc',
                'userId': 'u1',
                'startedAt': '2026-11-04T10:00:00.000Z',
                'endedAt': null,
                'notes': 'Pierna',
                'createdAt': '2026-11-04T10:00:00.000Z',
                'updatedAt': '2026-11-04T10:00:00.000Z',
              },
            ]),
          ),
          200,
        );
      }),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _FlakyApi flaky,
  FakeConnectivityService connectivity,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: WorkoutsPage(api: flaky.api, connectivityService: connectivity),
    ),
  );
  await tester.pumpAndSettle();
}

/// «Reintentar» de la vista de error (el banner offline tiene el suyo).
final _errorRetry = find.descendant(
  of: find.byType(RemoteErrorView),
  matching: find.text('Reintentar'),
);

void main() {
  testWidgets('sin red muestra el banner offline', (tester) async {
    await _pump(
      tester,
      _FlakyApi()..fail = false,
      FakeConnectivityService(online: false),
    );
    expect(find.text('Sin conexión'), findsOneWidget);
  });

  testWidgets('Reintentar de la vista de error recarga y muestra datos', (
    tester,
  ) async {
    final flaky = _FlakyApi();
    await _pump(tester, flaky, FakeConnectivityService(online: false));
    // Banner offline y vista de error muestran «Reintentar» a la vez.
    expect(find.text('Reintentar'), findsNWidgets(2));

    flaky.fail = false;
    await tester.tap(_errorRetry);
    await tester.pumpAndSettle();

    expect(flaky.calls, 2);
    expect(find.byType(RemoteErrorView), findsNothing);
    expect(find.text('Pierna'), findsOneWidget);
  });

  testWidgets('al recuperar la red tras un fallo recarga sola', (tester) async {
    final flaky = _FlakyApi();
    final connectivity = FakeConnectivityService(online: false);
    await _pump(tester, flaky, connectivity);
    expect(find.byType(RemoteErrorView), findsOneWidget);

    flaky.fail = false;
    connectivity.emit(true);
    await tester.pumpAndSettle();

    expect(flaky.calls, 2);
    expect(find.byType(RemoteErrorView), findsNothing);
    expect(find.text('Pierna'), findsOneWidget);
  });

  testWidgets('recuperar la red con datos cargados no recarga', (tester) async {
    final flaky = _FlakyApi()..fail = false;
    final connectivity = FakeConnectivityService();
    await _pump(tester, flaky, connectivity);

    connectivity.emit(true);
    await tester.pumpAndSettle();

    expect(flaky.calls, 1);
  });
}
