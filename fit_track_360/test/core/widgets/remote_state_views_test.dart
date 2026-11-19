import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/widgets/remote_state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('RemoteLoadingView muestra mensaje e indicador de carga', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const RemoteLoadingView(message: 'Cargando entrenos...')),
    );

    expect(find.text('Cargando entrenos...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('RemoteEmptyView muestra copy y ejecuta CTA opcional', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        RemoteEmptyView(
          title: 'Sin comidas',
          message: 'Registra tu primera comida.',
          actionLabel: 'Agregar',
          onAction: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Sin comidas'), findsOneWidget);
    expect(find.text('Registra tu primera comida.'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('RemoteErrorView muestra error y ejecuta onRetry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        RemoteErrorView(
          title: 'Error de carga',
          message: 'Intenta de nuevo.',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Error de carga'), findsOneWidget);
    expect(find.text('Intenta de nuevo.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('AsyncStateView resuelve loading, data, empty y error', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      _wrap(
        AsyncStateView<String>(
          state: const AsyncLoading<String>(),
          loadingMessage: 'Cargando datos',
          dataBuilder: Text.new,
        ),
      ),
    );
    expect(find.text('Cargando datos'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        AsyncStateView<String>(
          state: const AsyncData<String>('Listo'),
          dataBuilder: Text.new,
        ),
      ),
    );
    expect(find.text('Listo'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        AsyncStateView<String>(
          state: const AsyncEmpty<String>(),
          emptyTitle: 'Nada por aquí',
          dataBuilder: Text.new,
        ),
      ),
    );
    expect(find.text('Nada por aquí'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        AsyncStateView<String>(
          state: AsyncError<String>(Exception('fallo')),
          errorTitle: 'Falló la carga',
          onRetry: () => retried = true,
          dataBuilder: Text.new,
        ),
      ),
    );
    expect(find.text('Falló la carga'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
