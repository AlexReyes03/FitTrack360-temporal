import 'dart:async';
import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/meals/data/foods_api_repository.dart';
import 'package:fit_track_360/features/meals/data/meal_notes_codec.dart';
import 'package:fit_track_360/features/meals/data/meals_api_repository.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/local_day.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes.dart';

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

/// Respuesta con la forma real de MealResponseDto (meal-response.dto.ts).
Map<String, dynamic> _meal({
  required String id,
  required String eatenAt,
  required String mealType,
  String? notes,
  List<Map<String, dynamic>> items = const [],
}) => {
  'id': id,
  'userId': 'u1',
  'eatenAt': eatenAt,
  'mealType': mealType,
  'notes': notes,
  'photoId': null,
  'items': items,
  'totals': {'kcal': 0, 'proteinG': 0, 'carbsG': 0, 'fatG': 0},
  'createdAt': eatenAt,
  'updatedAt': eatenAt,
};

Map<String, dynamic> _item({
  required String name,
  String? fdcId,
  required num servingG,
  required num kcal,
  required num proteinG,
  required num carbsG,
  required num fatG,
}) => {
  'id': 'i-$name',
  'mealLogId': 'm',
  'fdcId': fdcId,
  'name': name,
  'servingG': servingG,
  'kcal': kcal,
  'proteinG': proteinG,
  'carbsG': carbsG,
  'fatG': fatG,
  'createdAt': '2026-11-10T15:00:00.000Z',
  'updatedAt': '2026-11-10T15:00:00.000Z',
};

MealsApiRepository _repo(MockClient client) => MealsApiRepository.fromClient(
  ApiClient(storage: FakeSessionStorage(), httpClient: client),
);

void main() {
  group('MealNotesCodec (solo lectura legacy)', () {
    test('decodifica nombre, porción y macros del formato viejo', () {
      final decoded = MealNotesCodec.decode(
        'Avena · cocida · 50 g · 190 kcal · P 6.5 g · C 34 g · G 3.5 g',
      );
      expect(decoded.name, 'Avena · cocida');
      expect(decoded.portionG, 50);
      expect(
        decoded.macros,
        const Macros(kcal: 190, proteinG: 6.5, carbsG: 34, fatG: 3.5),
      );
    });

    test('notas libres se conservan como nombre con macros en cero', () {
      final decoded = MealNotesCodec.decode('Tazón de avena');
      expect(decoded.name, 'Tazón de avena');
      expect(decoded.macros, Macros.zero);
    });
  });

  group('FoodsApiRepository (proxy GET /api/v1/foods/search, PR #153)', () {
    test('mapea el arreglo de FoodItemDto real del proxy', () async {
      String? requested;
      final repo = FoodsApiRepository(
        get: (path) async {
          requested = path;
          return _json([
            {
              'fdcId': 173904,
              'description': 'Oats',
              'name': 'Oats',
              'servingG': 100,
              'kcal': 389,
              'proteinG': 16.9,
              'carbsG': 66.3,
              'fatG': 6.9,
              'brandOwner': null,
            },
          ], 200);
        },
      );

      final results = await repo.search('rolled oats');

      expect(requested, '/api/v1/foods/search?q=rolled+oats');
      expect(results.single.fdcId, 173904);
      expect(results.single.name, 'Oats');
      expect(results.single.baseServingG, 100);
      expect(
        results.single.macros,
        const Macros(kcal: 389, proteinG: 16.9, carbsG: 66.3, fatG: 6.9),
      );
    });

    // 400: q vacío o > 120; 503: USDA_UNAVAILABLE (timeout, cuota, sin key).
    for (final status in [400, 404, 429, 500, 503]) {
      test('HTTP $status lanza FoodSearchUnavailable', () async {
        final repo = FoodsApiRepository(
          get: (_) async => _json({
            'code': 'USDA_UNAVAILABLE',
            'message': 'Servicio nutricional no disponible temporalmente',
          }, status),
        );
        await expectLater(
          repo.search('oats'),
          throwsA(isA<FoodSearchUnavailableException>()),
        );
      });
    }

    test('timeout lanza FoodSearchUnavailable', () async {
      final repo = FoodsApiRepository(
        get: (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        repo.search('oats'),
        throwsA(isA<FoodSearchUnavailableException>()),
      );
    });

    test('la sesión expirada no se convierte en captura manual', () async {
      final repo = FoodsApiRepository.fromClient(
        ApiClient(
          storage: FakeSessionStorage(),
          httpClient: MockClient((_) async => http.Response('', 401)),
        ),
      );
      await expectLater(
        repo.search('oats'),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });

  group('MealsApiRepository', () {
    test(
      'lista GET /api/v1/meals leyendo macros tipados desde items',
      () async {
        late http.Request request;
        final repo = _repo(
          MockClient((r) async {
            request = r;
            return _json([
              _meal(
                id: 'm1',
                eatenAt: '2026-11-10T15:00:00.000Z',
                mealType: 'LUNCH',
                // Notas libres: ya no se interpretan si hay items.
                notes: 'Otra cosa · 1 g · 1 kcal · P 1 g · C 1 g · G 1 g',
                items: [
                  _item(
                    name: 'Arroz',
                    fdcId: '168878',
                    servingG: 150,
                    kcal: 195,
                    proteinG: 4,
                    carbsG: 42,
                    fatG: 0.5,
                  ),
                  _item(
                    name: 'Frijoles',
                    servingG: 100,
                    kcal: 127,
                    proteinG: 8.7,
                    carbsG: 22.8,
                    fatG: 0.5,
                  ),
                ],
              ),
            ], 200);
          }),
        );

        final entries = await repo.list();

        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/meals');
        final entry = entries.single;
        expect(entry.mealType, MealType.lunch);
        expect(entry.eatenAt, DateTime.utc(2026, 11, 10, 15));
        expect(entry.isLegacy, isFalse);
        expect(entry.items.map((item) => item.name), ['Arroz', 'Frijoles']);
        expect(entry.items.first.fdcId, '168878');
        expect(entry.items.first.servingG, 150);
        expect(
          entry.items.first.macros,
          const Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
        );
        expect(entry.macros.kcal, 322);
      },
    );

    test('lee registros legacy (items vacío y macros en notes)', () async {
      final repo = _repo(
        MockClient(
          (_) async => _json([
            _meal(
              id: 'old',
              eatenAt: '2026-11-09T15:00:00.000Z',
              mealType: 'SNACK',
              notes: 'Manzana · 120 g · 62 kcal · P 0.3 g · C 17 g · G 0.2 g',
            ),
            _meal(
              id: 'empty',
              eatenAt: '2026-11-09T16:00:00.000Z',
              mealType: 'SNACK',
            ),
          ], 200),
        ),
      );

      final entries = await repo.list();

      final legacy = entries.first;
      expect(legacy.isLegacy, isTrue);
      expect(legacy.items.single.name, 'Manzana');
      expect(legacy.items.single.servingG, 120);
      expect(
        legacy.macros,
        const Macros(kcal: 62, proteinG: 0.3, carbsG: 17, fatG: 0.2),
      );
      expect(entries.last.isLegacy, isFalse);
      expect(entries.last.items, isEmpty);
    });

    test(
      'agrega con POST /api/v1/meals enviando items (CreateMealItemDto)',
      () async {
        late http.Request request;
        final repo = _repo(
          MockClient((r) async {
            request = r;
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            final sent = (body['items'] as List).single as Map<String, dynamic>;
            return _json(
              _meal(
                id: 'm2',
                eatenAt: body['eatenAt'] as String,
                mealType: body['mealType'] as String,
                items: [
                  _item(
                    name: sent['name'] as String,
                    fdcId: sent['fdcId'] as String?,
                    servingG: sent['servingG'] as num,
                    kcal: sent['kcal'] as num,
                    proteinG: sent['proteinG'] as num,
                    carbsG: sent['carbsG'] as num,
                    fatG: sent['fatG'] as num,
                  ),
                ],
              ),
              201,
            );
          }),
        );

        final created = await repo.add(
          NewMealEntry(
            mealType: MealType.snack,
            eatenAt: DateTime.utc(2026, 11, 10, 18),
            name: 'Manzana',
            fdcId: '171688',
            portionG: 120,
            macros: const Macros(
              kcal: 62,
              proteinG: 0.3,
              carbsG: 17,
              fatG: 0.2,
            ),
          ),
        );

        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/meals');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        // forbidNonWhitelisted: solo llaves del contrato; nada en notes ni photoId.
        expect(body.keys.toSet(), {'eatenAt', 'mealType', 'items'});
        expect(body['eatenAt'], '2026-11-10T18:00:00.000Z');
        expect(body['mealType'], 'SNACK');
        expect(body['items'], [
          {
            'name': 'Manzana',
            'fdcId': '171688',
            'servingG': 120,
            'kcal': 62,
            'proteinG': 0.3,
            'carbsG': 17,
            'fatG': 0.2,
          },
        ]);
        expect(created.id, 'm2');
        expect(created.isLegacy, isFalse);
        expect(created.items.single.name, 'Manzana');
        expect(created.macros.kcal, 62);
      },
    );

    test('la captura manual se envía sin fdcId', () async {
      late Map<String, dynamic> body;
      final repo = _repo(
        MockClient((r) async {
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return _json(
            _meal(
              id: 'm3',
              eatenAt: body['eatenAt'] as String,
              mealType: 'DINNER',
              items: [
                _item(
                  name: 'Tacos',
                  servingG: 180,
                  kcal: 320,
                  proteinG: 0,
                  carbsG: 0,
                  fatG: 0,
                ),
              ],
            ),
            201,
          );
        }),
      );

      await repo.add(
        NewMealEntry(
          mealType: MealType.dinner,
          eatenAt: DateTime.utc(2026, 11, 10, 2),
          name: 'Tacos',
          portionG: 180,
          macros: const Macros(kcal: 320, proteinG: 0, carbsG: 0, fatG: 0),
        ),
      );

      final item = (body['items'] as List).single as Map<String, dynamic>;
      expect(item.containsKey('fdcId'), isFalse);
    });

    test('un 400 del API se reporta con su mensaje', () async {
      final repo = _repo(
        MockClient(
          (_) async => _json({
            'message': ['items.0.kcal debe ser un número no negativo'],
          }, 400),
        ),
      );
      await expectLater(
        repo.add(
          NewMealEntry(
            mealType: MealType.lunch,
            eatenAt: DateTime.utc(2026, 11, 10),
            name: 'X',
            portionG: 1,
            macros: Macros.zero,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensaje',
            contains('kcal'),
          ),
        ),
      );
    });

    test('la sesión expirada se propaga desde add y list', () async {
      final repo = _repo(MockClient((_) async => http.Response('', 401)));
      await expectLater(repo.list(), throwsA(isA<SessionExpiredException>()));
      await expectLater(
        repo.add(
          NewMealEntry(
            mealType: MealType.lunch,
            eatenAt: DateTime.utc(2026, 11, 10),
            name: 'X',
            portionG: 1,
            macros: Macros.zero,
          ),
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test(
      'el resumen del día consulta /meals/summary con la fecha local',
      () async {
        late http.Request request;
        final repo = _repo(
          MockClient((r) async {
            request = r;
            return _json({
              'date': '2026-01-05',
              'from': r.url.queryParameters['from'],
              'to': r.url.queryParameters['to'],
              'totals': {
                'kcal': 680,
                'proteinG': 59,
                'carbsG': 56.5,
                'fatG': 21,
              },
              'byMealType': <String, dynamic>{},
            }, 200);
          }),
        );
        // Instante tardío del 5 de enero local, en UTC puede ser otro día.
        final day = LocalDay.of(DateTime(2026, 1, 5, 23, 30).toUtc());

        final totals = await repo.dayTotals(day);

        expect(request.url.path, '/api/v1/meals/summary');
        final query = request.url.queryParameters;
        expect(query['date'], '2026-01-05');
        // El API interpreta `date` como día UTC; from/to fijan el día local.
        expect(DateTime.parse(query['from']!), DateTime(2026, 1, 5).toUtc());
        expect(
          DateTime.parse(query['to']!),
          DateTime(2026, 1, 5, 23, 59, 59, 999).toUtc(),
        );
        expect(
          totals,
          const Macros(kcal: 680, proteinG: 59, carbsG: 56.5, fatG: 21),
        );
      },
    );
  });
}
