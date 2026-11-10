import 'package:fit_track_360/features/meals/domain/daily_summary.dart';
import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';

MealEntry _entry(MealType type, Macros macros, {DateTime? at}) => MealEntry(
  id: '${type.name}-${macros.kcal}',
  mealType: type,
  eatenAt: at ?? DateTime(2026, 11, 10, 9),
  name: 'Alimento',
  portionG: 100,
  macros: macros,
);

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
  });
}
