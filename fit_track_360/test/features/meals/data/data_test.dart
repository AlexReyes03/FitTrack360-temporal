import 'dart:async';
import 'dart:convert';

import 'package:fit_track_360/features/meals/data/foods_api_repository.dart';
import 'package:fit_track_360/features/meals/data/meal_notes_codec.dart';
import 'package:fit_track_360/features/meals/data/meals_api_repository.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  group('MealNotesCodec', () {
    const macros = Macros(kcal: 190, proteinG: 6.5, carbsG: 34, fatG: 3.5);

    test('codifica y decodifica nombre, porción y macros', () {
      final notes = MealNotesCodec.encode('Avena · cocida', 50, macros);
      final decoded = MealNotesCodec.decode(notes);
      expect(decoded.name, 'Avena · cocida');
      expect(decoded.portionG, 50);
      expect(decoded.macros, macros);
    });

    test('notas libres se conservan como nombre con macros en cero', () {
      final decoded = MealNotesCodec.decode('Tazón de avena');
      expect(decoded.name, 'Tazón de avena');
      expect(decoded.macros, Macros.zero);
    });
  });

  group('FoodsApiRepository', () {
    test('mapea los resultados del proxy GET /api/v1/foods/search', () async {
      String? requested;
      final repo = FoodsApiRepository(
        get: (path) async {
          requested = path;
          return _json([
            {
              'fdcId': 173904,
              'description': 'Oats',
              'kcal': 380,
              'proteinG': 13,
              'carbsG': 68,
              'fatG': 7,
            },
          ], 200);
        },
      );

      final results = await repo.search('oats');

      expect(requested, '/api/v1/foods/search?q=oats');
      expect(results.single.fdcId, 173904);
      expect(results.single.name, 'Oats');
      expect(results.single.baseServingG, 100);
      expect(results.single.macros.kcal, 380);
    });

    for (final status in [404, 429, 500, 503]) {
      test('HTTP $status lanza FoodSearchUnavailable', () async {
        final repo = FoodsApiRepository(
          get: (_) async => _json({'code': 'USDA_UNAVAILABLE'}, status),
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
  });

  group('MealsApiRepository', () {
    test('lista GET /api/v1/meals y decodifica las notas', () async {
      final repo = MealsApiRepository(
        get: (_) async => _json([
          {
            'id': 'm1',
            'eatenAt': '2026-11-10T15:00:00.000Z',
            'mealType': 'LUNCH',
            'notes': MealNotesCodec.encode(
              'Arroz',
              150,
              const Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
            ),
            'photoId': null,
          },
        ], 200),
        post: (_, _) async => _json({}, 500),
      );

      final entries = await repo.list();
      expect(entries.single.mealType, MealType.lunch);
      expect(entries.single.name, 'Arroz');
      expect(entries.single.macros.kcal, 195);
    });

    test('agrega con POST /api/v1/meals según el contrato real', () async {
      Map<String, dynamic>? sent;
      final repo = MealsApiRepository(
        get: (_) async => _json([], 200),
        post: (path, body) async {
          expect(path, '/api/v1/meals');
          sent = body;
          return _json({
            'id': 'm2',
            'eatenAt': body['eatenAt'],
            'mealType': body['mealType'],
            'notes': body['notes'],
            'photoId': null,
          }, 201);
        },
      );

      final created = await repo.add(
        NewMealEntry(
          mealType: MealType.snack,
          eatenAt: DateTime.utc(2026, 11, 10, 18),
          name: 'Manzana',
          portionG: 120,
          macros: const Macros(kcal: 62, proteinG: 0.3, carbsG: 17, fatG: 0.2),
        ),
      );

      expect(sent!['mealType'], 'SNACK');
      expect(sent!['eatenAt'], '2026-11-10T18:00:00.000Z');
      expect(sent!.containsKey('photoId'), isFalse);
      expect(created.id, 'm2');
      expect(created.macros.kcal, 62);
    });
  });
}
