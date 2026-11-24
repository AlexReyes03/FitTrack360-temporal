import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/core/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake controlable: el test decide si hay red y cuando cambia.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({required this.online});

  bool online;
  final _controller = StreamController<bool>.broadcast();

  void emit(bool value) {
    online = value;
    _controller.add(value);
  }

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<bool> isOnline() async => online;
}

Widget _host(FakeConnectivityService service, VoidCallback onRetry) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          OfflineBanner(service: service, onRetry: onRetry),
          const Expanded(child: Center(child: Text('Contenido'))),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('no muestra el banner con red', (tester) async {
    final service = FakeConnectivityService(online: true);
    await tester.pumpWidget(_host(service, () {}));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsNothing);
    expect(find.text('Contenido'), findsOneWidget);
  });

  testWidgets('aparece sin red y desaparece al recuperarla', (tester) async {
    final service = FakeConnectivityService(online: true);
    await tester.pumpWidget(_host(service, () {}));
    await tester.pumpAndSettle();

    service.emit(false);
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    // No bloquea: el contenido sigue visible.
    expect(find.text('Contenido'), findsOneWidget);

    service.emit(true);
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsNothing);
  });

  testWidgets('Reintentar llama onRetry sin tumbar la app', (tester) async {
    final service = FakeConnectivityService(online: false);
    var retries = 0;
    await tester.pumpWidget(_host(service, () => retries++));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Si al reintentar ya hay red, el banner se oculta.
    service.online = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(retries, 2);
    expect(find.text('Sin conexión'), findsNothing);
  });

  test('isOnlineFrom interpreta la lista de resultados', () {
    expect(ConnectivityService.isOnlineFrom(const []), isFalse);
  });

  group('accesibilidad', () {
    testWidgets('Reintentar tiene área táctil de 48dp y alto visual de 40', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final service = FakeConnectivityService(online: false);
      var retries = 0;
      await tester.pumpWidget(_host(service, () => retries++));
      await tester.pumpAndSettle();

      final retry = find.bySemanticsLabel('Reintentar conexión');
      expect(retry, findsOneWidget);
      final rect = tester.getRect(retry);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.width, greaterThanOrEqualTo(48));

      // La pill visible conserva 40dp de alto.
      final pill = find.ancestor(
        of: find.text('Reintentar'),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(pill).height, 40);

      // Tocar el borde del área (fuera de la pill) también reintenta.
      await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
      await tester.pumpAndSettle();
      expect(retries, 1);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('el aviso no se anuncia como botón; Reintentar sí', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final service = FakeConnectivityService(online: false);
      await tester.pumpWidget(_host(service, () {}));
      await tester.pumpAndSettle();

      final message = tester.getSemantics(find.text('Sin conexión'));
      expect(message.flagsCollection.isButton, isFalse);
      expect(message.flagsCollection.isLiveRegion, isTrue);
      expect(message.label, isNot(contains('Reintentar')));

      final retry = tester.getSemantics(
        find.bySemanticsLabel('Reintentar conexión'),
      );
      expect(retry.flagsCollection.isButton, isTrue);
      expect(retry.flagsCollection.isEnabled, Tristate.isTrue);
      handle.dispose();
    });
  });
}
