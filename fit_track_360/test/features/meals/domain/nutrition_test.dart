import 'package:fit_track_360/features/meals/domain/daily_summary.dart';
import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/local_day.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_item.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';

MealEntry _entry(
  MealType type,
  Macros macros, {
  DateTime? at,
  bool legacy = false,
}) => MealEntry(
  id: '${type.name}-${macros.kcal}',
  mealType: type,
  eatenAt: at ?? DateTime(2026, 11, 10, 9),
  items: [MealItem(name: 'Alimento', servingG: 100, macros: macros)],
  isLegacy: legacy,
);

/// Instante cuya fecha UTC difiere de la local (null si la zona es UTC).
/// Al oeste de UTC, las 23:30 locales ya son el día siguiente en UTC; al
/// este, las 00:30 locales todavía son el día anterior en UTC.
DateTime? _utcInstantOnOtherUtcDate(DateTime localDay) {
  final offset = localDay.timeZoneOffset;
  if (offset == Duration.zero) return null;
  final local = offset.isNegative
      ? DateTime(localDay.year, localDay.month, localDay.day, 23, 30)
      : DateTime(localDay.year, localDay.month, localDay.day, 0, 30);
  final utc = local.toUtc();
  expect(utc.day, isNot(local.day));
  return utc;
}

void main() {
  group('Macros', () {
    test('suma calorías y cada macro', () {
      const a = Macros(kcal: 100, proteinG: 10, carbsG: 20, fatG: 3);
      const b = Macros(kcal: 50, proteinG: 1, carbsG: 2, fatG: 4);
      expect(a + b, const Macros(kcal: 150, proteinG: 11, carbsG: 22, fatG: 7));
    });

    test('escala por un factor', () {
      const a = Macros(kcal: 200, proteinG: 10, carbsG: 30, fatG: 4);
      expect(
        a.scale(1.5),
        const Macros(kcal: 300, proteinG: 15, carbsG: 45, fatG: 6),
      );
    });
  });

  group('FoodItem.forPortion', () {
    test('escala los macros base (100 g) a la porción elegida', () {
      const food = FoodItem(
        fdcId: 1,
        name: 'Oats',
        baseServingG: 100,
        macros: Macros(kcal: 380, proteinG: 13, carbsG: 68, fatG: 7),
      );
      expect(
        food.forPortion(50),
        const Macros(kcal: 190, proteinG: 6.5, carbsG: 34, fatG: 3.5),
      );
    });

    test('porción no positiva da macros en cero', () {
      const food = FoodItem(
        name: 'Oats',
        baseServingG: 100,
        macros: Macros(kcal: 380, proteinG: 13, carbsG: 68, fatG: 7),
      );
      expect(food.forPortion(0), Macros.zero);
      expect(food.forPortion(-5), Macros.zero);
    });
  });

  group('MealEntry', () {
    test('sus macros son la suma de sus MealItem', () {
      final entry = MealEntry(
        id: 'm',
        mealType: MealType.lunch,
        eatenAt: DateTime(2026, 11, 10, 14),
        items: const [
          MealItem(
            name: 'Arroz',
            servingG: 150,
            macros: Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
          ),
          MealItem(
            fdcId: '1',
            name: 'Frijoles',
            servingG: 100,
            macros: Macros(kcal: 127, proteinG: 8.5, carbsG: 22, fatG: 0.5),
          ),
        ],
      );
      expect(
        entry.macros,
        const Macros(kcal: 322, proteinG: 12.5, carbsG: 64, fatG: 1),
      );
    });

    test('NewMealEntry arma un MealItem con macros congelados', () {
      final entry = NewMealEntry(
        mealType: MealType.lunch,
        eatenAt: DateTime(2026, 11, 10),
        name: 'Oats',
        fdcId: '173904',
        portionG: 50,
        macros: const Macros(kcal: 190, proteinG: 6.5, carbsG: 34, fatG: 3.5),
      );
      expect(entry.item.name, 'Oats');
      expect(entry.item.fdcId, '173904');
      expect(entry.item.servingG, 50);
      expect(entry.item.macros.kcal, 190);
    });
  });

  group('LocalDay', () {
    test('la llave es YYYY-MM-DD con ceros del día local', () {
      expect(LocalDay.of(DateTime(2026, 1, 5, 23, 59)).key, '2026-01-05');
    });

    test('normaliza instantes UTC al día local del dispositivo', () {
      final local = DateTime(2026, 1, 5, 23, 30);
      expect(LocalDay.of(local.toUtc()), LocalDay.of(local));
      expect(LocalDay.of(local.toUtc()).key, '2026-01-05');
    });

    test('expone los límites locales del día', () {
      final day = LocalDay.of(DateTime(2026, 1, 5, 12));
      expect(day.start, DateTime(2026, 1, 5));
      expect(day.end, DateTime(2026, 1, 5, 23, 59, 59, 999));
      expect(day.contains(DateTime(2026, 1, 5, 23, 59).toUtc()), isTrue);
      expect(day.contains(DateTime(2026, 1, 6)), isFalse);
    });
  });

  group('DailySummary', () {
    final day = DateTime(2026, 11, 10);

    test('agrupa por tipo de comida y suma totales por sección y del día', () {
      final summary = DailySummary.forDay(day, [
        _entry(
          MealType.breakfast,
          const Macros(kcal: 300, proteinG: 10, carbsG: 40, fatG: 8),
        ),
        _entry(
          MealType.breakfast,
          const Macros(kcal: 100, proteinG: 5, carbsG: 10, fatG: 2),
        ),
        _entry(
          MealType.dinner,
          const Macros(kcal: 500, proteinG: 30, carbsG: 50, fatG: 15),
        ),
      ]);

      expect(
        summary.sectionFor(MealType.breakfast).totals,
        const Macros(kcal: 400, proteinG: 15, carbsG: 50, fatG: 10),
      );
      expect(summary.sectionFor(MealType.breakfast).entries, hasLength(2));
      expect(summary.sectionFor(MealType.lunch).entries, isEmpty);
      expect(summary.sectionFor(MealType.lunch).totals, Macros.zero);
      expect(
        summary.totals,
        const Macros(kcal: 900, proteinG: 45, carbsG: 100, fatG: 25),
      );
    });

    test('siempre expone las cuatro secciones en orden', () {
      final summary = DailySummary.forDay(day, const []);
      expect(summary.sections.map((s) => s.mealType).toList(), [
        MealType.breakfast,
        MealType.lunch,
        MealType.dinner,
        MealType.snack,
      ]);
      expect(summary.isEmpty, isTrue);
    });

    test('ignora registros de otros días', () {
      final summary = DailySummary.forDay(day, [
        _entry(
          MealType.lunch,
          const Macros(kcal: 700, proteinG: 1, carbsG: 1, fatG: 1),
          at: DateTime(2026, 11, 9, 14),
        ),
        _entry(
          MealType.lunch,
          const Macros(kcal: 200, proteinG: 1, carbsG: 1, fatG: 1),
          at: DateTime(2026, 11, 10, 14),
        ),
      ]);
      expect(summary.totals.kcal, 200);
    });

    test('_sameDay es simétrico: el día puede llegar en UTC', () {
      final dayUtc = _utcInstantOnOtherUtcDate(day);
      if (dayUtc == null) {
        markTestSkipped('La zona del dispositivo es UTC; no hay borde.');
        return;
      }
      final entries = [
        _entry(
          MealType.breakfast,
          const Macros(kcal: 300, proteinG: 1, carbsG: 1, fatG: 1),
        ),
      ];
      final fromUtc = DailySummary.forDay(dayUtc, entries);
      final fromLocal = DailySummary.forDay(day, entries);
      expect(fromUtc.totals.kcal, 300);
      expect(fromUtc.totals, fromLocal.totals);
      expect(fromUtc.day, DateTime(2026, 11, 10));
    });

    test('borde UTC contra local: el registro llega en UTC del API', () {
      final eatenUtc = _utcInstantOnOtherUtcDate(day);
      if (eatenUtc == null) {
        markTestSkipped('La zona del dispositivo es UTC; no hay borde.');
        return;
      }
      final entry = _entry(
        MealType.dinner,
        const Macros(kcal: 450, proteinG: 1, carbsG: 1, fatG: 1),
        at: eatenUtc,
      );
      // Mismo día local, ya se pase el día en local o en UTC.
      expect(DailySummary.forDay(day, [entry]).totals.kcal, 450);
      expect(DailySummary.forDay(eatenUtc, [entry]).totals.kcal, 450);
      // Y no se cuela en el día UTC vecino.
      final otherLocalDay = DateTime(
        eatenUtc.year,
        eatenUtc.month,
        eatenUtc.day,
        12,
      );
      expect(DailySummary.forDay(otherLocalDay, [entry]).isEmpty, isTrue);
    });

    test(
      'con totales persistidos del API suma además los registros legacy',
      () {
        final summary = DailySummary.forDay(
          day,
          [
            _entry(
              MealType.lunch,
              const Macros(kcal: 200, proteinG: 10, carbsG: 20, fatG: 5),
            ),
            _entry(
              MealType.snack,
              const Macros(kcal: 62, proteinG: 0.5, carbsG: 17, fatG: 0.5),
              legacy: true,
            ),
          ],
          persistedItemTotals: const Macros(
            kcal: 200,
            proteinG: 10,
            carbsG: 20,
            fatG: 5,
          ),
        );
        expect(
          summary.totals,
          const Macros(kcal: 262, proteinG: 10.5, carbsG: 37, fatG: 5.5),
        );
        expect(summary.sectionFor(MealType.snack).totals.kcal, 62);
      },
    );
  });
}
