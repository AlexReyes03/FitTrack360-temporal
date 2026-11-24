import 'package:fit_track_360/app/router.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/presentation/forgot_password_page.dart';
import 'package:fit_track_360/features/settings/presentation/privacy_notice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TokenStorage implements SessionStorage {
  _TokenStorage(this.accessToken);

  final String? accessToken;

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

GoRouter _router(String? token, String initialLocation, {Object? extra}) {
  final previous = appSessionStorage;
  appSessionStorage = _TokenStorage(token);
  addTearDown(() => appSessionStorage = previous);
  final router = GoRouter(
    initialLocation: initialLocation,
    initialExtra: extra,
    redirect: (context, state) => resolveAppSessionRedirect(state),
    routes: buildAppRoutes(),
  );
  addTearDown(router.dispose);
  return router;
}

void main() {
  for (final token in [null, 'token']) {
    testWidgets(
      '$appPrivacyNoticePath es pública (sesión: ${token != null}) y muestra '
      'PrivacyNoticePage',
      (tester) async {
        final router = _router(token, appPrivacyNoticePath);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.byType(PrivacyNoticePage), findsOneWidget);
      },
    );
  }

  testWidgets('/forgot-password recibe el correo por extra', (tester) async {
    final router = _router(null, '/forgot-password', extra: 'ana@test.com');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final page = tester.widget<ForgotPasswordPage>(
      find.byType(ForgotPasswordPage),
    );
    expect(page.initialEmail, 'ana@test.com');
  });
}
