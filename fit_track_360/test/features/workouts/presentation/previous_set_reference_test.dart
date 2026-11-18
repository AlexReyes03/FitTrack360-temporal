import 'package:fit_track_360/features/workouts/domain/exercise_reference.dart';
import 'package:fit_track_360/features/workouts/presentation/widgets/previous_set_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('muestra peso y repeticiones de la referencia', (tester) async {
    final reference = PreviousSetReference(
      performedAt: DateTime.utc(2026, 11, 10),
      weightKg: 60,
      reps: 10,
    );

    await tester.pumpWidget(
      _host(PreviousSetReferenceView(reference: reference)),
    );

    expect(find.text('Anterior: 60 kg × 10'), findsOneWidget);
  });

  testWidgets('muestra el peso decimal sin ceros sobrantes', (tester) async {
    final reference = PreviousSetReference(
      performedAt: DateTime.utc(2026, 11, 10),
      weightKg: 62.5,
      reps: 8,
    );

    await tester.pumpWidget(
      _host(PreviousSetReferenceView(reference: reference)),
    );

    expect(find.text('Anterior: 62.5 kg × 8'), findsOneWidget);
  });

  testWidgets('omite el peso cuando la serie no lo registra', (tester) async {
    final reference = PreviousSetReference(
      performedAt: DateTime.utc(2026, 11, 10),
      weightKg: null,
      reps: 12,
    );

    await tester.pumpWidget(
      _host(PreviousSetReferenceView(reference: reference)),
    );

    expect(find.text('Anterior: 12 reps'), findsOneWidget);
  });

  testWidgets('muestra el aviso cuando no hay historial', (tester) async {
    await tester.pumpWidget(
      _host(const PreviousSetReferenceView(reference: null)),
    );

    expect(find.text('Sin registro anterior'), findsOneWidget);
  });
}
