import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_item.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:fit_track_360/features/meals/domain/meals_repository.dart';
import 'package:fit_track_360/features/meals/presentation/food_search_page.dart';
import 'package:fit_track_360/features/meals/presentation/food_search_view_model.dart';
import 'package:fit_track_360/core/widgets/remote_state_views.dart';
import 'package:fit_track_360/features/meals/presentation/meals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../settings/fakes.dart' show FakeConnectivityService;
import '../fakes.dart';

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Future<void> _openItemMenu(
  WidgetTester tester,
  String entryId,
  int index,
) async {
  await tester.tap(find.byKey(Key('item-menu-$entryId-$index')));
  await tester.pumpAndSettle();
}

const _arroz = MealItem(
  id: 'i1',
  name: 'Arroz',
  servingG: 150,
  macros: Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
);

const _frijoles = MealItem(
  id: 'i2',
  name: 'Frijoles',
  servingG: 100,
  macros: Macros(kcal: 127, proteinG: 8.7, carbsG: 22.8, fatG: 0.5),
);

MealEntry _lunch(List<MealItem> items, {bool legacy = false}) => MealEntry(
  id: 'm1',
  mealType: MealType.lunch,
  eatenAt: DateTime.now(),
  items: items,
  isLegacy: legacy,
);

/// MealsPage dentro de GoRouter, como en la app (`/app/comidas` + buscar).
Future<void> _pumpRouted(
  WidgetTester tester,
  FakeMealsRepository meals,
  FakeFoodSearchRepository foods, {
  String initialLocation = '/app/comidas',
  FakeConnectivityService? connectivity,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/app/comidas',
        builder: (context, state) => MealsPage(
          mealsRepository: meals,
          foodsRepository: foods,
          connectivityService: connectivity ?? FakeConnectivityService(),
        ),
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
  FakeFoodSearchRepository foods, {
  FakeConnectivityService? connectivity,
}) => _pumpRouted(tester, meals, foods, connectivity: connectivity);

/// «Reintentar» de la vista de error (el banner offline tiene el suyo).
final _errorRetry = find.descendant(
  of: find.byType(RemoteErrorView),
  matching: find.text('Reintentar'),
);

NewMealEntry _rice() => NewMealEntry(
  mealType: MealType.lunch,
  eatenAt: DateTime.now(),
  name: 'Arroz',
  portionG: 150,
  macros: const Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
);

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

  testWidgets('editar escala macros y actualiza el resumen', (tester) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar alimento'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('195'), findsOneWidget);

    await tester.enterText(_field('edit-name'), 'Arroz integral');
    await tester.enterText(_field('edit-portion'), '300');
    await tester.pumpAndSettle();

    expect(find.text('390'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final sent = meals.updates.single.items.single;
    expect(sent.id, 'i1');
    expect(sent.name, 'Arroz integral');
    expect(sent.servingG, 300);
    expect(sent.macros.kcal, 390);
    expect(sent.macros.proteinG, 8);
    expect(sent.macros.carbsG, 84);
    expect(sent.macros.fatG, 1);
    expect(find.text('Comida · 390 kcal'), findsOneWidget);
    expect(find.textContaining('Arroz integral · 300 g'), findsOneWidget);
  });

  testWidgets('editar conserva los demás alimentos del registro', (
    tester,
  ) async {
    final meals = FakeMealsRepository()
      ..stored.add(_lunch(const [_arroz, _frijoles]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('edit-name'), 'Arroz blanco');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(meals.updates.single.items, hasLength(2));
    expect(meals.stored.single.items.map((item) => item.name), [
      'Arroz blanco',
      'Frijoles',
    ]);
    expect(find.textContaining('Frijoles · 100 g'), findsOneWidget);
  });

  testWidgets('cancelar la eliminación conserva el alimento', (tester) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar alimento'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(meals.updates, isEmpty);
    expect(meals.deletes, isEmpty);
    expect(find.textContaining('Arroz · 150 g'), findsOneWidget);
  });

  testWidgets('eliminar el último alimento usa DELETE', (tester) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(meals.deletes, ['m1']);
    expect(meals.updates, isEmpty);
    expect(find.text('Aún no registras comidas hoy'), findsOneWidget);
  });

  testWidgets('eliminar un alimento con varios conserva el resto', (
    tester,
  ) async {
    final meals = FakeMealsRepository()
      ..stored.add(_lunch(const [_arroz, _frijoles]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(meals.deletes, isEmpty);
    expect(meals.updates.single.items.single.name, 'Frijoles');
    expect(find.textContaining('Arroz · 150 g'), findsNothing);
    expect(find.textContaining('Frijoles · 100 g'), findsOneWidget);
  });

  testWidgets('un error al editar conserva los datos y el formulario', (
    tester,
  ) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    meals.updateError = Exception('red');

    await tester.enterText(_field('edit-name'), 'Arroz integral');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo guardar el alimento. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Editar alimento'), findsOneWidget);
    expect(meals.stored.single.items.single.name, 'Arroz');
  });

  testWidgets('un error al eliminar conserva el alimento', (tester) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    meals.deleteError = Exception('red');
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo eliminar el alimento'), findsOneWidget);
    expect(find.textContaining('Arroz · 150 g'), findsOneWidget);
  });

  testWidgets('un 404 al editar avisa que el alimento ya no existe', (
    tester,
  ) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    meals.updateError = const MealNotFoundException();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('El alimento ya no existe'), findsOneWidget);
    expect(find.text('Editar alimento'), findsNothing);
  });

  testWidgets('el formulario valida nombre, porción y macros', (tester) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('edit-name'), '');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el nombre del alimento'), findsOneWidget);

    await tester.enterText(_field('edit-name'), 'Arroz');
    await tester.enterText(_field('edit-portion'), '0');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(
      find.text('La porción debe ser un número mayor que cero'),
      findsOneWidget,
    );

    await tester.enterText(_field('edit-portion'), '150');
    await tester.enterText(_field('edit-kcal'), '-1');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(
      find.text('Las calorías deben ser un número no negativo'),
      findsOneWidget,
    );
    expect(meals.updates, isEmpty);
  });

  testWidgets('muestra progreso y evita un segundo guardado', (tester) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    meals.updateGate = Completer<void>();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(find.text('Guardando...'), findsOneWidget);

    meals.updateGate!.complete();
    await tester.pumpAndSettle();

    expect(meals.updates, hasLength(1));
    expect(find.text('Comida · 195 kcal'), findsOneWidget);
  });

  testWidgets('sesión expirada al editar navega a /login', (tester) async {
    final meals = FakeMealsRepository()..stored.add(_lunch(const [_arroz]));
    meals.updateError = const SessionExpiredException();
    await _pumpRouted(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('un legacy sin porción se elimina pero no se edita', (
    tester,
  ) async {
    final meals = FakeMealsRepository()
      ..stored.add(
        _lunch(const [
          MealItem(name: 'Notas libres', servingG: 0, macros: Macros.zero),
        ], legacy: true),
      );
    await _pumpPage(tester, meals, FakeFoodSearchRepository());

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('No se puede editar'), findsOneWidget);
    expect(find.textContaining('no guarda porción'), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    await _openItemMenu(tester, 'm1', 0);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(meals.deletes, ['m1']);
  });

  group('estados remotos y conectividad', () {
    testWidgets('sin red muestra el banner offline', (tester) async {
      await _pumpPage(
        tester,
        FakeMealsRepository(),
        FakeFoodSearchRepository(),
        connectivity: FakeConnectivityService(online: false),
      );
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('Reintentar de la vista de error recarga y muestra datos', (
      tester,
    ) async {
      final meals = FakeMealsRepository()..listError = Exception('red');
      await _pumpPage(
        tester,
        meals,
        FakeFoodSearchRepository(),
        connectivity: FakeConnectivityService(online: false),
      );
      // Banner offline y vista de error muestran «Reintentar» a la vez.
      expect(find.text('Reintentar'), findsNWidgets(2));

      meals.listError = null;
      await meals.add(_rice());
      await tester.tap(_errorRetry);
      await tester.pumpAndSettle();

      expect(find.byType(RemoteErrorView), findsNothing);
      expect(find.text('Comida · 195 kcal'), findsOneWidget);
    });

    testWidgets('al recuperar la red tras un fallo recarga sola', (
      tester,
    ) async {
      final connectivity = FakeConnectivityService(online: false);
      final meals = FakeMealsRepository()..listError = Exception('red');
      await _pumpPage(
        tester,
        meals,
        FakeFoodSearchRepository(),
        connectivity: connectivity,
      );
      expect(find.byType(RemoteErrorView), findsOneWidget);

      meals.listError = null;
      await meals.add(_rice());
      connectivity.emit(true);
      await tester.pumpAndSettle();

      expect(find.byType(RemoteErrorView), findsNothing);
      expect(find.text('Comida · 195 kcal'), findsOneWidget);
    });
  });
}
