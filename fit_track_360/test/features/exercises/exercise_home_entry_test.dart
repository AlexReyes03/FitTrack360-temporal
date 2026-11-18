import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/features/home/presentation/home_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/exercise_test_support.dart';

class FakeConnectivityService implements ConnectivityService {
  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => true;
}

http.Response _profile() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'id': '1',
      'email': 'ana@test.com',
      'username': 'ana',
      'displayName': 'Ana',
      'createdAt': '2026-11-04T00:00:00.000Z',
    }),
  ),
  200,
);

void main() {
  testWidgets('Home abre el catálogo de ejercicios', (tester) async {
    final storage = FakeSessionStorage();
    final router = GoRouter(
      initialLocation: '/app',
      routes: [
        GoRoute(
          path: '/app',
          builder: (context, state) => HomeShellPage(
            apiClient: ApiClient(
              storage: storage,
              httpClient: MockClient((request) async => _profile()),
            ),
            sessionStorage: storage,
            connectivityService: FakeConnectivityService(),
          ),
        ),
        GoRoute(
          path: '/app/ejercicios',
          builder: (context, state) => const Text('Catálogo de ejercicios'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Ejercicios'), findsOneWidget);

    await tester.tap(find.text('Ejercicios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Catálogo de ejercicios'), findsOneWidget);
  });
}
