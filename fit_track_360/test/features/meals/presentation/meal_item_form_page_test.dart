import 'dart:async';

import 'package:fit_track_360/design_system/components/primary_button.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_item.dart';
import 'package:fit_track_360/features/meals/presentation/meal_item_form_page.dart';
import 'package:fit_track_360/features/meals/presentation/meals_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _arroz = MealItem(
  id: 'i1',
  name: 'Arroz',
  servingG: 150,
  macros: Macros(kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5),
);

Future<void> _pumpForm(
  WidgetTester tester,
  Future<MealMutationResult> Function(MealItem item) onSave,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MealItemFormPage(item: _arroz, onSave: onSave),
    ),
  );
}

Finder get _cta => find.byType(PrimaryButton);

void main() {
  testWidgets('en reposo el CTA dice «Guardar cambios» y no carga', (
    tester,
  ) async {
    await _pumpForm(tester, (_) async => MealMutationResult.success);

    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(_cta).isLoading, isFalse);
  });

  testWidgets('mientras guarda el CTA carga y un segundo toque no reenvía', (
    tester,
  ) async {
    final gate = Completer<MealMutationResult>();
    var calls = 0;
    await _pumpForm(tester, (_) {
      calls++;
      return gate.future;
    });

    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();

    final button = tester.widget<PrimaryButton>(_cta);
    expect(button.isLoading, isTrue);
    expect(button.loadingLabel, 'Guardando…');
    expect(find.text('Guardando…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('primary-button-spinner')),
      findsOneWidget,
    );

    await tester.tap(find.text('Guardando…'));
    await tester.tap(find.text('Guardando…'));
    await tester.pump();
    expect(calls, 1);

    gate.complete(MealMutationResult.failure);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(tester.widget<PrimaryButton>(_cta).isLoading, isFalse);
    expect(
      find.text('No se pudo guardar el alimento. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('no usa el texto «Guardando...» con tres puntos ASCII', (
    tester,
  ) async {
    final gate = Completer<MealMutationResult>();
    await _pumpForm(tester, (_) => gate.future);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();

    expect(find.text('Guardando...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(MealMutationResult.failure);
    await tester.pumpAndSettle();
  });
}
