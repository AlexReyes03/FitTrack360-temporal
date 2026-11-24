import 'dart:async';

import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/core/widgets/offline_banner.dart';
import 'package:fit_track_360/core/widgets/permission_denied_notice.dart';
import 'package:fit_track_360/core/widgets/remote_state_views.dart';
import 'package:fit_track_360/design_system/components/primary_button.dart';
import 'package:fit_track_360/design_system/components/secondary_button.dart';
import 'package:fit_track_360/design_system/components/status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ds_test_harness.dart';

class _OfflineService implements ConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<bool> isOnline() async => false;
}

StatusBanner _banner(WidgetTester tester) =>
    tester.widget<StatusBanner>(find.byType(StatusBanner));

/// Los avisos de `lib/core/widgets` se construyen con los componentes del DS
/// (#222) en lugar de copias privadas de StatusBanner y botones glass.
void main() {
  testWidgets('OfflineBanner usa StatusBanner warning y SecondaryButton', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      dsHarness(OfflineBanner(service: _OfflineService(), onRetry: () {})),
    );
    await tester.pumpAndSettle();

    expect(_banner(tester).variant, StatusBannerVariant.warning);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    final retry = tester.widget<SecondaryButton>(find.byType(SecondaryButton));
    expect(retry.size, SecondaryButtonSize.compact);
    expect(find.bySemanticsLabel('Reintentar conexión'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('PermissionDeniedNotice usa StatusBanner warning y botones DS', (
    tester,
  ) async {
    await tester.pumpWidget(
      dsHarness(
        PermissionDeniedNotice(
          actionLabel: 'Usar zona manual',
          onAction: () {},
          secondaryActionLabel: 'Abrir ajustes',
          onSecondaryAction: () {},
        ),
      ),
    );
    expect(_banner(tester).variant, StatusBannerVariant.warning);
    expect(find.widgetWithText(PrimaryButton, 'Usar zona manual'), findsOne);
    expect(find.widgetWithText(SecondaryButton, 'Abrir ajustes'), findsOne);
  });

  testWidgets('RemoteErrorView usa StatusBanner danger', (tester) async {
    await tester.pumpWidget(dsHarness(RemoteErrorView(onRetry: () {})));
    expect(_banner(tester).variant, StatusBannerVariant.danger);
    expect(find.widgetWithText(PrimaryButton, 'Reintentar'), findsOne);
  });
}
