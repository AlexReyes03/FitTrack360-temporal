import 'package:fit_track_360/design_system/components/app_logo.dart';
import 'package:fit_track_360/features/home/presentation/widgets/app_shell_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra AppLogo mark, marca, campana y badge con no leídas', (
    tester,
  ) async {
    var tapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppShellHeader(
              unreadCount: 3,
              onNotificationsTap: () => tapped++,
            ),
          ),
        ),
      ),
    );

    final logo = tester.widget<AppLogo>(find.byType(AppLogo));
    expect(logo.variant, AppLogoVariant.mark);
    expect(find.text('FITTRACK360'), findsOneWidget);
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);

    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('oculta el badge cuando unreadCount es cero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppShellHeader(unreadCount: 0, onNotificationsTap: () {}),
        ),
      ),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });

  testWidgets('no desborda en un ancho móvil compacto de 360dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: AppShellHeader(unreadCount: 12, onNotificationsTap: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}
