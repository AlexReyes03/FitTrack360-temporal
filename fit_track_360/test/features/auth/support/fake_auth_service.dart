import 'dart:async';

import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/data/firebase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = AuthUser(
  id: '1',
  email: 'ana@test.com',
  username: 'ana_01',
  displayName: 'Ana',
  firebaseUid: 'uid-1',
);

/// Fake de [FirebaseAuthService] para pruebas de pantallas de auth.
class FakeAuthService extends Fake implements FirebaseAuthService {
  Object? loginError;
  Object? registerError;
  Object? resetError;

  /// Si no es null, las llamadas esperan a que se complete (estado de carga).
  Completer<void>? gate;

  int loginCalls = 0;
  int registerCalls = 0;
  int resetCalls = 0;
  String? lastPassword;
  String? lastEmail;

  Future<void> _wait() async {
    final pending = gate;
    if (pending != null) await pending.future;
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;
    await _wait();
    final error = loginError;
    if (error != null) throw error;
    return testUser;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required bool privacyConsent,
    required String privacyNoticeVersion,
  }) async {
    registerCalls++;
    lastEmail = email;
    lastPassword = password;
    await _wait();
    final error = registerError;
    if (error != null) throw error;
    return testUser;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetCalls++;
    lastEmail = email;
    await _wait();
    final error = resetError;
    if (error != null) throw error;
  }

  @override
  Future<AuthUser> loginWithGoogle({
    bool allowAutoRegister = false,
    bool privacyConsent = false,
    String privacyNoticeVersion = '2',
  }) async => testUser;
}

/// Semantics con live region que contiene [text].
Finder liveRegionWithText(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.liveRegion == true,
  ),
);

/// El [finder] cabe completo dentro de la ventana de prueba (sin scroll).
void expectFullyOnScreen(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  expect(rect.top, greaterThanOrEqualTo(0), reason: 'top $rect');
  expect(rect.bottom, lessThanOrEqualTo(size.height), reason: 'bottom $rect');
}
