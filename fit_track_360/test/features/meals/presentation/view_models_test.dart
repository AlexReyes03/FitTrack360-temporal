import 'dart:async';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/meals/domain/daily_summary.dart';
import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/local_day.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_type.dart';
import 'package:fit_track_360/features/meals/presentation/food_search_view_model.dart';
import 'package:fit_track_360/features/meals/presentation/meals_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const _oats = FoodItem(
  fdcId: 173904,
  name: 'Oats',
  baseServingG: 100,
  macros: Macros(kcal: 380, proteinG: 13, carbsG: 68, fatG: 7),
);

final _today = DateTime(2026, 11, 10, 12);

NewMealEntry _oatsEntry(DateTime at) => NewMealEntry(
  mealType: MealType.breakfast,
  eatenAt: at,
  name: 'Oats',
  fdcId: '173904',
  portionG: 50,
  macros: _oats.forPortion(50),
);

void main() {
  group('MealsViewModel', () {
    test('sin registros queda en Empty', () async {
      final vm = MealsViewModel(FakeMealsRepository(), now: () => _today);
      await vm.load();
      expect(vm.state, isA<AsyncEmpty<DailySummary>>());
    });

    test('un error de carga queda en Error', () async {
      final repo = FakeMealsRepository()..listError = Exception('red');
      final vm = MealsViewModel(repo, now: () => _today);
      await vm.load();
      expect(vm.state, isA<AsyncError<DailySummary>>());
    });

    test('el resumen se actualiza después de agregar', () async {
      final vm = MealsViewModel(FakeMealsRepository(), now: () => _today);
      await vm.load();

      final ok = await vm.add(_oatsEntry(_today));

      expect(ok, isTrue);
      final summary = vm.state.dataOrNull!;
      expect(summary.totals.kcal, 190);
      expect(summary.sectionFor(MealType.breakfast).entries, hasLength(1));
    });

    test(
      'pide los totales del día con la fecha local del dispositivo',
      () async {
        final repo = FakeMealsRepository();
        final vm = MealsViewModel(repo, now: () => _today.toUtc());
        await vm.load();
        expect(repo.totalsRequests, [LocalDay.of(_today)]);
        expect(repo.totalsRequests.single.key, '2026-11-10');
      },
    );

    test('los totales del día vienen del resumen del API', () async {
      final repo = FakeMealsRepository();
      await repo.add(_oatsEntry(_today));
      final vm = MealsViewModel(repo, now: () => _today);
      await vm.load();
      expect(vm.state.dataOrNull!.totals.kcal, 190);
    });

    test(
      'si el resumen falla, el dominio suma los registros del día',
      () async {
        final repo = FakeMealsRepository()..totalsError = Exception('red');
        await repo.add(_oatsEntry(_today));
        final vm = MealsViewModel(repo, now: () => _today);
        await vm.load();
        expect(vm.state.dataOrNull!.totals.kcal, 190);
      },
    );

    test('no notifica después de dispose (load pendiente)', () async {
      final repo = FakeMealsRepository()..listGate = Completer<void>();
      final vm = MealsViewModel(repo, now: () => _today);
      var notified = 0;
      vm.addListener(() => notified++);
      final pending = vm.load();
      final before = notified;
      vm.dispose();
      repo.listGate!.complete();
      await expectLater(pending, completes);
      expect(notified, before);
    });

    test('no notifica después de dispose (add pendiente)', () async {
      final repo = FakeMealsRepository();
      final vm = MealsViewModel(repo, now: () => _today);
      await vm.load();
      repo.listGate = Completer<void>();
      final pending = vm.add(_oatsEntry(_today));
      vm.dispose();
      repo.listGate!.complete();
      await expectLater(pending, completes);
    });

    test('la sesión expirada al cargar marca sessionExpired', () async {
      final repo = FakeMealsRepository()
        ..listError = const SessionExpiredException();
      final vm = MealsViewModel(repo, now: () => _today);
      await vm.load();
      expect(vm.sessionExpired, isTrue);
    });

    test(
      'la sesión expirada en add no se traga: marca sessionExpired',
      () async {
        final repo = FakeMealsRepository()
          ..addError = const SessionExpiredException();
        final vm = MealsViewModel(repo, now: () => _today);
        await vm.load();
        var notified = 0;
        vm.addListener(() => notified++);

        final ok = await vm.add(_oatsEntry(_today));

        expect(ok, isFalse);
        expect(vm.sessionExpired, isTrue);
        expect(notified, greaterThan(0));
      },
    );

    test('la sesión expirada en el resumen del día también redirige', () async {
      final repo = FakeMealsRepository()
        ..totalsError = const SessionExpiredException();
      final vm = MealsViewModel(repo, now: () => _today);
      await vm.load();
      expect(vm.sessionExpired, isTrue);
    });

    test('otro error en add devuelve false sin marcar sesión', () async {
      final repo = FakeMealsRepository()..addError = Exception('400');
      final vm = MealsViewModel(repo, now: () => _today);
      await vm.load();
      expect(await vm.add(_oatsEntry(_today)), isFalse);
      expect(vm.sessionExpired, isFalse);
    });

    test('empieza en Loading', () {
      final vm = MealsViewModel(FakeMealsRepository(), now: () => _today);
      expect(vm.state, isA<AsyncLoading<DailySummary>>());
    });
  });

  group('FoodSearchViewModel', () {
    testWidgets('el debounce no dispara una búsqueda por cada tecla', (
      tester,
    ) async {
      final repo = FakeFoodSearchRepository()..results = const [_oats];
      final vm = FoodSearchViewModel(repo);

      vm.onQueryChanged('o');
      await tester.pump(const Duration(milliseconds: 100));
      vm.onQueryChanged('oa');
      await tester.pump(const Duration(milliseconds: 100));
      vm.onQueryChanged('oat');
      await tester.pump(const Duration(milliseconds: 100));
      vm.onQueryChanged('oats');
      expect(repo.queries, isEmpty);

      await tester.pump(FoodSearchViewModel.debounceDuration);
      expect(repo.queries, ['oats']);
      expect(vm.results, isA<AsyncData<List<FoodItem>>>());
      vm.dispose();
    });

    testWidgets('un error o timeout de USDA ofrece la captura manual', (
      tester,
    ) async {
      final repo = FakeFoodSearchRepository()
        ..error = const FoodSearchUnavailableException();
      final vm = FoodSearchViewModel(repo);

      vm.onQueryChanged('oats');
      await tester.pump(FoodSearchViewModel.debounceDuration);

      expect(vm.results, isA<AsyncError<List<FoodItem>>>());
      expect(vm.offersManualCapture, isTrue);
      vm.dispose();
    });

    testWidgets('sin resultados queda en Empty y ofrece captura manual', (
      tester,
    ) async {
      final vm = FoodSearchViewModel(FakeFoodSearchRepository());
      vm.onQueryChanged('zzzz');
      await tester.pump(FoodSearchViewModel.debounceDuration);
      expect(vm.results, isA<AsyncEmpty<List<FoodItem>>>());
      expect(vm.offersManualCapture, isTrue);
      vm.dispose();
    });

    test('con resultados no ofrece captura manual por defecto', () {
      final vm = FoodSearchViewModel(FakeFoodSearchRepository());
      expect(vm.offersManualCapture, isFalse);
      vm.dispose();
    });

    test('la porción escala los macros y arma la entrada al destino', () {
      final vm = FoodSearchViewModel(FakeFoodSearchRepository());
      vm.select(_oats);
      vm.setPortion(50);
      vm.setDestination(MealType.dinner);

      expect(
        vm.selectedMacros,
        const Macros(kcal: 190, proteinG: 6.5, carbsG: 34, fatG: 3.5),
      );
      final entry = vm.buildEntry(_today)!;
      expect(entry.mealType, MealType.dinner);
      expect(entry.name, 'Oats');
      expect(entry.portionG, 50);
      expect(entry.macros.kcal, 190);
      expect(entry.fdcId, '173904');
      vm.dispose();
    });

    test('la captura manual arma la entrada sin llamar a USDA', () {
      final repo = FakeFoodSearchRepository();
      final vm = FoodSearchViewModel(repo)..setDestination(MealType.lunch);
      const macros = Macros(kcal: 250, proteinG: 20, carbsG: 10, fatG: 12);

      final entry = vm.buildManualEntry(
        name: ' Tacos de pollo ',
        portionG: 180,
        macros: macros,
        eatenAt: _today,
      )!;

      expect(entry.name, 'Tacos de pollo');
      expect(entry.mealType, MealType.lunch);
      expect(entry.macros, macros);
      expect(entry.fdcId, isNull);
      expect(repo.queries, isEmpty);
      expect(
        vm.buildManualEntry(
          name: '',
          portionG: 180,
          macros: macros,
          eatenAt: _today,
        ),
        isNull,
      );
      expect(
        vm.buildManualEntry(
          name: 'Tacos',
          portionG: 180,
          macros: const Macros(kcal: -1, proteinG: 0, carbsG: 0, fatG: 0),
          eatenAt: _today,
        ),
        isNull,
      );
      vm.dispose();
    });

    test('sin alimento elegido o porción inválida no arma entrada', () {
      final vm = FoodSearchViewModel(FakeFoodSearchRepository());
      expect(vm.buildEntry(_today), isNull);
      vm.select(_oats);
      vm.setPortion(0);
      expect(vm.buildEntry(_today), isNull);
      vm.dispose();
    });
  });
}
