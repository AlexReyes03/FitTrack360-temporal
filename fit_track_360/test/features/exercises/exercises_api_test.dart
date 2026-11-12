import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/exercise_test_support.dart';

void main() {
  ExercisesApi apiFor(MockClient client, {FakeSessionStorage? storage}) {
    return ExercisesApi(
      ApiClient(storage: storage ?? FakeSessionStorage(), httpClient: client),
    );
  }

  group('buildCollectionPath', () {
    test('omite filtros vacíos y conserva page/pageSize', () {
      final path = ExercisesApi.buildCollectionPath(
        query: '  ',
        bodyPart: null,
        equipment: '',
        target: 'abs',
        page: 2,
        pageSize: 20,
      );
      final uri = Uri.parse(path);

      expect(uri.path, '/api/v1/exercises');
      expect(uri.queryParameters, {
        'page': '2',
        'pageSize': '20',
        'target': 'abs',
      });
    });

    test('incluye búsqueda y los tres filtros', () {
      final uri = Uri.parse(
        ExercisesApi.buildCollectionPath(
          query: ' press ',
          bodyPart: 'chest',
          equipment: 'barbell',
          target: 'pectorals',
          page: 1,
          pageSize: 20,
        ),
      );

      expect(uri.queryParameters['q'], 'press');
      expect(uri.queryParameters['bodyPart'], 'chest');
      expect(uri.queryParameters['equipment'], 'barbell');
      expect(uri.queryParameters['target'], 'pectorals');
    });

    test('codifica valores con espacios', () {
      final path = ExercisesApi.buildCollectionPath(
        bodyPart: 'upper legs',
        page: 1,
        pageSize: 20,
      );

      expect(path, contains('bodyPart=upper+legs'));
    });
  });

  group('fetchPage', () {
    test('lee el sobre provisional', () async {
      final api = apiFor(
        MockClient(
          (request) async =>
              jsonResponse(pageJson([exerciseJson()], total: 1324)),
        ),
      );

      final page = await api.fetchPage();

      expect(page.items.single.name, '3/4 sit-up');
      expect(page.total, 1324);
    });

    test('envía el Bearer del almacén de sesión', () async {
      String? authorization;
      final api = apiFor(
        MockClient((request) async {
          authorization = request.headers['Authorization'];
          return jsonResponse(pageJson([exerciseJson()]));
        }),
      );

      await api.fetchPage();

      expect(authorization, 'Bearer access');
    });

    test('propaga el mensaje del backend en un 500', () async {
      final api = apiFor(
        MockClient(
          (request) async =>
              jsonResponse({'message': 'Catálogo caído'}, status: 500),
        ),
      );

      expect(
        api.fetchPage(),
        throwsA(
          isA<AuthApiException>().having(
            (error) => error.message,
            'message',
            'Catálogo caído',
          ),
        ),
      );
    });

    test('falla con un cuerpo vacío', () async {
      final api = apiFor(
        MockClient((request) async => http.Response.bytes(const <int>[], 200)),
      );

      expect(api.fetchPage(), throwsA(isA<FormatException>()));
    });
  });

  group('fetchById', () {
    test('lee el detalle', () async {
      final api = apiFor(
        MockClient(
          (request) async => jsonResponse(
            exerciseJson(
              instructionsEs: 'Túmbate sobre tu espalda.',
              instructionStepsEs: const ['Paso uno'],
            ),
          ),
        ),
      );

      final exercise = await api.fetchById('0001');

      expect(exercise.id, '0001');
      expect(exercise.instructionsEs, 'Túmbate sobre tu espalda.');
      expect(exercise.instructionStepsEs, ['Paso uno']);
    });

    test('pide la ruta del detalle con el id', () async {
      late Uri requested;
      final api = apiFor(
        MockClient((request) async {
          requested = request.url;
          return jsonResponse(exerciseJson());
        }),
      );

      await api.fetchById('0001');

      expect(requested.path, '/api/v1/exercises/0001');
    });

    test('traduce el 404 a un mensaje propio', () async {
      final api = apiFor(
        MockClient(
          (request) async =>
              jsonResponse({'message': 'not found'}, status: 404),
        ),
      );

      expect(
        api.fetchById('9999'),
        throwsA(
          isA<AuthApiException>().having(
            (error) => error.message,
            'message',
            ExercisesApi.notFoundMessage,
          ),
        ),
      );
    });

    test('rechaza un detalle que no es un objeto', () async {
      final api = apiFor(
        MockClient(
          (request) async => http.Response.bytes(utf8.encode('[]'), 200),
        ),
      );

      expect(api.fetchById('0001'), throwsA(isA<FormatException>()));
    });
  });
}
