import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:fit_track_360/features/meals/presentation/food_search_view_model.dart';
import 'package:fit_track_360/features/meals/presentation/meals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  FakeMealsRepository meals,
  FakeFoodSearchRepository foods,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MealsPage(mealsRepository: meals, foodsRepository: foods),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin registros muestra el estado vacío', (tester) async {
    await _pumpPage(tester, FakeMealsRepository(), FakeFoodSearchRepository());
    expect(find.text('Aún no registras comidas hoy'), findsOneWidget);
  });

  testWidgets('un error de carga muestra Reintentar', (tester) async {
    final meals = FakeMealsRepository()..listError = Exception('red');
    await _pumpPage(tester, meals, FakeFoodSearchRepository());
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('muestra totales del día y secciones por tipo de comida', (
    tester,
  ) async {
    final meals = FakeMealsRepository();
    await meals.add(
      NewMealEntry(
        mealType: MealType.lunch,
        eatenAt: DateTime.now(),
        name: 'Arroz',
        portionG: 150,
        macros: const Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
      ),
    );
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    expect(find.text('195 kcal'), findsOneWidget);
    expect(find.text('Comida · 195 kcal'), findsOneWidget);
    expect(find.text('Desayuno · 0 kcal'), findsOneWidget);
    expect(find.text('Sin alimentos'), findsNWidgets(3));
  });

  testWidgets('error de USDA → captura manual → el resumen se actualiza', (
    tester,
  ) async {
    final meals = FakeMealsRepository();
    final foods = FakeFoodSearchRepository()
      ..error = const FoodSearchUnavailableException();
    await _pumpPage(tester, meals, foods);

    await tester.tap(find.text('Agregar alimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cena'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('food-search')),
        matching: find.byType(TextField),
      ),
      'tacos',
    );
    await tester.pump(FoodSearchViewModel.debounceDuration);
    await tester.pumpAndSettle();

    expect(
      find.text('La búsqueda no está disponible. ¿Quieres capturarlo a mano?'),
      findsOneWidget,
    );
    // Regresión: con el aviso visible había dos botones «Captura manual».
    expect(find.text('Captura manual'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('manual-kcal')),
        matching: find.byType(TextField),
      ),
      '320',
    );
    await tester.tap(find.text('Agregar a Cena'));
    await tester.pumpAndSettle();

    expect(meals.stored.single.name, 'tacos');
    expect(meals.stored.single.mealType, MealType.dinner);
    expect(find.text('320 kcal'), findsOneWidget);
    expect(find.text('Cena · 320 kcal'), findsOneWidget);
  });

  testWidgets('búsqueda USDA → porción → agrega a la comida de destino', (
    tester,
  ) async {
    final meals = FakeMealsRepository();
    final foods = FakeFoodSearchRepository()
      ..results = const [
        FoodItem(
          fdcId: 1,
          name: 'Oats',
          baseServingG: 100,
          macros: Macros(kcal: 380, proteinG: 13, carbsG: 68, fatG: 7),
        ),
      ];
    await _pumpPage(tester, meals, foods);

    await tester.tap(find.text('Agregar alimento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('food-search')),
        matching: find.byType(TextField),
      ),
      'oats',
    );
    await tester.pump(FoodSearchViewModel.debounceDuration);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oats'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('food-portion')),
        matching: find.byType(TextField),
      ),
      '50',
    );
    await tester.pumpAndSettle();
    expect(find.text('190 kcal · P 6.5 g · C 34 g · G 3.5 g'), findsOneWidget);

    await tester.tap(find.text('Agregar a Desayuno'));
    await tester.pumpAndSettle();

    expect(foods.queries, ['oats']);
    expect(find.text('Desayuno · 190 kcal'), findsOneWidget);
  });
}
