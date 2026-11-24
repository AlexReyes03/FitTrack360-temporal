import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/data/google_auth_gateway.dart';
import 'package:fit_track_360/features/auth/domain/auth_messages.dart';
import 'package:fit_track_360/features/auth/domain/auth_validators.dart';
import 'package:fit_track_360/features/auth/presentation/auth_view_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_service.dart';

class _GoogleAuth extends FakeAuthService {
  _GoogleAuth(this.error);

  final Object error;

  @override
  Future<AuthUser> loginWithGoogle({
    bool allowAutoRegister = false,
    bool privacyConsent = false,
    String privacyNoticeVersion = '2',
  }) async => throw error;
}

const _validForm = RegisterForm(
  displayName: 'Ana',
  username: 'ana_01',
  email: 'ana@test.com',
  password: 'Password1',
  confirmPassword: 'Password1',
);

void main() {
  test('login: cancelar Google no deja error ni carga', () async {
    final vm = LoginViewModel(
      auth: _GoogleAuth(const GoogleSignInCancelledException()),
    );
    addTearDown(vm.dispose);

    expect(await vm.submitGoogle(), isFalse);
    expect(vm.errorMessage, isNull);
    expect(vm.isGoogleLoading, isFalse);
  });

  test('login: error 500 de Google se traduce al genérico', () async {
    final vm = LoginViewModel(
      auth: _GoogleAuth(
        const AuthApiException('Internal server error', statusCode: 500),
      ),
    );
    addTearDown(vm.dispose);

    await vm.submitGoogle();
    expect(vm.errorMessage, AuthMessages.loginGeneric);
    expect(vm.state, isA<AsyncError<AuthUser>>());
  });

  test(
    'registro: aceptar el aviso limpia el motivo de consentimiento',
    () async {
      final auth = FakeAuthService();
      final vm = RegisterViewModel(auth: auth);
      addTearDown(vm.dispose);

      expect(await vm.submit(_validForm), isFalse);
      expect(vm.errorMessage, AuthMessages.consentRequired);
      expect(vm.consentMissing, isTrue);

      vm.setPrivacyConsent(true);
      expect(vm.errorMessage, isNull);
      expect(await vm.submit(_validForm), isTrue);
      expect(auth.registerCalls, 1);
    },
  );

  test('registro: Google sin consentimiento explica el motivo', () async {
    final vm = RegisterViewModel(auth: FakeAuthService());
    addTearDown(vm.dispose);

    expect(await vm.submitGoogle(), isFalse);
    expect(vm.errorMessage, AuthMessages.consentRequiredGoogle);
  });

  test('registro: completar un campo quita su error inline', () async {
    final vm = RegisterViewModel(auth: FakeAuthService());
    addTearDown(vm.dispose);

    await vm.submit(
      const RegisterForm(
        displayName: '',
        username: '',
        email: '',
        password: '',
        confirmPassword: '',
      ),
    );
    expect(vm.missingFields, hasLength(5));
    vm.fieldChanged(RegisterField.username, 'ana');
    expect(vm.missingFields.contains(RegisterField.username), isFalse);
  });

  test('recuperar: no notifica tras dispose', () async {
    final auth = FakeAuthService();
    final vm = ForgotPasswordViewModel(auth: auth);
    final pending = vm.submit('ana@test.com');
    vm.dispose();
    await pending;
    expect(auth.resetCalls, 1);
  });
}
