import 'package:fit_track_360/design_system/widgets/ds_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('DsTextField API', () {
    testWidgets('reenvía los parámetros de teclado al TextField', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      final formatter = FilteringTextInputFormatter.digitsOnly;

      await tester.pumpWidget(
        _host(
          DsTextField(
            controller: controller,
            label: 'Nombre',
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            textCapitalization: TextCapitalization.words,
            inputFormatters: [formatter],
            maxLength: 40,
            onSubmitted: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode, same(focusNode));
      expect(field.textInputAction, TextInputAction.next);
      expect(field.autofillHints, [AutofillHints.name]);
      expect(field.textCapitalization, TextCapitalization.words);
      expect(field.inputFormatters, contains(formatter));
      expect(field.maxLength, 40);
    });

    testWidgets('onSubmitted se dispara con la acción del teclado', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? submitted;

      await tester.pumpWidget(
        _host(
          DsTextField(
            controller: controller,
            label: 'Correo',
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ana@correo.mx');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, 'ana@correo.mx');
    });

    testWidgets('mantiene la API anterior (solo controller y label)', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(DsTextField(controller: controller, label: 'Correo')),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, isNull);
      expect(field.textCapitalization, TextCapitalization.none);
      expect(field.maxLength, isNull);
      expect(find.text('Correo'), findsOneWidget);
    });

    testWidgets('muestra errorText bajo el campo', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          DsTextField(
            controller: controller,
            label: 'Calorías (kcal)',
            errorText: 'Escribe un número válido.',
          ),
        ),
      );

      expect(find.text('Escribe un número válido.'), findsOneWidget);
    });
  });

  group('DsTextField numérico', () {
    testWidgets('integer: solo acepta dígitos y usa teclado numérico', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(DsTextField.integer(controller: controller, label: 'Series')),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);

      await tester.enterText(find.byType(TextField), 'xyz-5');
      expect(controller.text, '5');

      await tester.enterText(find.byType(TextField), '12.5');
      expect(controller.text, '125');
    });

    testWidgets('decimal: impide letras (regresión QA "xyz-5" en kcal)', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          DsTextField.decimal(controller: controller, label: 'Calorías (kcal)'),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );

      await tester.enterText(find.byType(TextField), 'xyz-5');
      expect(controller.text, '5');
    });

    testWidgets('decimal: acepta coma o punto, pero un solo separador', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(DsTextField.decimal(controller: controller, label: 'Peso (kg)')),
      );

      await tester.enterText(find.byType(TextField), '72,5');
      expect(controller.text, '72,5');

      await tester.enterText(find.byType(TextField), '72.5');
      expect(controller.text, '72.5');

      // Un segundo separador se rechaza y se conserva el valor previo.
      await tester.enterText(find.byType(TextField), '72.5.1');
      expect(controller.text, '72.5');
    });

    testWidgets('decimal: respeta maxDecimals', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          DsTextField.decimal(
            controller: controller,
            label: 'Peso (kg)',
            maxDecimals: 1,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '72,5');
      expect(controller.text, '72,5');
      await tester.enterText(find.byType(TextField), '72,55');
      expect(controller.text, '72,5');
    });

    test('parseDecimal interpreta coma y punto', () {
      expect(DsTextField.parseDecimal('72,5'), 72.5);
      expect(DsTextField.parseDecimal(' 72.5 '), 72.5);
      expect(DsTextField.parseDecimal('15'), 15);
      expect(DsTextField.parseDecimal(''), isNull);
      expect(DsTextField.parseDecimal('abc'), isNull);
    });
  });

  group('DsTextField semántica', () {
    testWidgets('el lector anuncia la etiqueta una sola vez y como campo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          DsTextField(
            controller: controller,
            label: 'Correo',
            hint: 'tu@correo.com',
          ),
        ),
      );

      // Un único nodo con la etiqueta: el Text visual no se anuncia aparte.
      expect(find.bySemanticsLabel(RegExp('Correo')), findsOneWidget);
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.label, contains('Correo'));
      expect(node.flagsCollection.isTextField, isTrue);
      handle.dispose();
    });

    testWidgets('cumple las guías de accesibilidad de Flutter', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          DsTextField(
            controller: controller,
            label: 'Contraseña',
            obscureText: true,
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
