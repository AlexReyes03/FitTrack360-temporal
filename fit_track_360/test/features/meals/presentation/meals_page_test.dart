import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_item.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:fit_track_360/features/meals/presentation/food_search_page.dart';
import 'package:fit_track_360/features/meals/presentation/food_search_view_model.dart';
import 'package:fit_track_360/features/meals/presentation/meals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes.dart';

/// MealsPage dentro de GoRouter, como en la app (`/app/comidas` + buscar).
Future<void> _pumpRouted(
  WidgetTester tester,
  FakeMealsRepository meals,
  FakeFoodSearchRepository foods, {
  String initialLocation = '/app/comidas',
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/app/comidas',
        builder: (context, state) =>
            MealsPage(mealsRepository: meals, foodsRepository: foods),
      ),
      GoRoute(
        path: '/app/comidas/buscar',
        builder: (context, state) => FoodSearchPage(repository: foods),
      ),
      GoRoute(path: '/login', builder: (context, state) => const Text('login')),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _pumpPage(
  WidgetTester tester,
  FakeMealsRepository meals,
  FakeFoodSearchRepository foods,
) => _pumpRouted(tester, meals, foods);

Future<void> _addManually(WidgetTester tester, String name, String kcal) async {
  await tester.tap(find.text('Agregar alimento'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Captura manual'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('manual-name')),
      matching: find.byType(TextField),
    ),
    name,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('manual-kcal')),
      matching: find.byType(TextField),
    ),
    kcal,
  );
  await tester.tap(find.text('Agregar a Desayuno'));
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

    expect(meals.stored.single.items.single.name, 'tacos');
    expect(meals.stored.single.mealType, MealType.dinner);
    expect(find.text('320 kcal'), findsOneWidget);
    expect(find.text('Cena · 320 kcal'), findsOneWidget);
  });

  testWidgets(
    'captura manual rechaza un macro no numérico en vez de guardarlo en 0',
    (tester) async {
      // Regresión: «7avena» en Grasa se guardaba como 0 g (visto en simulador).
      final meals = FakeMealsRepository();
      final foods = FakeFoodSearchRepository()
        ..error = const FoodSearchUnavailableException();
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
      await tester.tap(find.byKey(const Key('open-manual')));
      await tester.pumpAndSettle();

      Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      await tester.enterText(field('manual-kcal'), '380');
      await tester.enterText(field('manual-fat'), '7avena');
      await tester.tap(find.text('Agregar a Desayuno'));
      await tester.pumpAndSettle();

      expect(meals.stored, isEmpty);
      expect(find.textContaining('Revisa'), findsOneWidget);

      // Vacío sí significa 0: corregido el valor, se agrega.
      await tester.enterText(field('manual-fat'), '');
      await tester.tap(find.text('Agregar a Desayuno'));
      await tester.pumpAndSettle();

      expect(meals.stored.single.items.single.macros.fatG, 0);
    },
  );

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

  testWidgets('FoodSearchPage tiene botón Volver que regresa sin agregar', (
    tester,
  ) async {
    final meals = FakeMealsRepository();
    await _pumpRouted(tester, meals, FakeFoodSearchRepository());

    await tester.tap(find.text('Agregar alimento'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar alimento'), findsOneWidget); // título
    expect(find.byTooltip('Volver'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Comidas de hoy'), findsOneWidget);
    expect(find.byType(FoodSearchPage), findsNothing);
    expect(meals.stored, isEmpty);
  });

  testWidgets('sin ruta previa, Volver lleva a /app/comidas', (tester) async {
    await _pumpRouted(
      tester,
      FakeMealsRepository(),
      FakeFoodSearchRepository(),
      initialLocation: '/app/comidas/buscar',
    );

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Comidas de hoy'), findsOneWidget);
  });

  testWidgets('sesión expirada al cargar navega a /login', (tester) async {
    final meals = FakeMealsRepository()
      ..listError = const SessionExpiredException();
    await _pumpRouted(tester, meals, FakeFoodSearchRepository());
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('sesión expirada al agregar navega a /login sin aviso', (
    tester,
  ) async {
    final meals = FakeMealsRepository()
      ..addError = const SessionExpiredException();
    await _pumpRouted(tester, meals, FakeFoodSearchRepository());

    await _addManually(tester, 'Avena', '150');

    expect(find.text('login'), findsOneWidget);
    expect(find.text('No se pudo agregar el alimento'), findsNothing);
  });

  testWidgets('otro error al agregar muestra el aviso y no navega', (
    tester,
  ) async {
    final meals = FakeMealsRepository()..addError = Exception('400');
    await _pumpRouted(tester, meals, FakeFoodSearchRepository());

    await _addManually(tester, 'Avena', '150');

    expect(find.text('No se pudo agregar el alimento'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });

  testWidgets('cada MealItem de una comida se muestra en su sección', (
    tester,
  ) async {
    final meals = FakeMealsRepository();
    meals.stored.add(
      MealEntry(
        id: 'm1',
        mealType: MealType.lunch,
        eatenAt: DateTime.now(),
        items: const [
          MealItem(
            name: 'Arroz',
            servingG: 150,
            macros: Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
          ),
          MealItem(
            name: 'Frijoles',
            servingG: 100,
            macros: Macros(kcal: 127, proteinG: 8.7, carbsG: 22.8, fatG: 0.5),
          ),
        ],
      ),
    );
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    expect(find.text('Comida · 322 kcal'), findsOneWidget);
    expect(find.textContaining('Arroz · 150 g'), findsOneWidget);
    expect(find.textContaining('Frijoles · 100 g'), findsOneWidget);
  });
}
