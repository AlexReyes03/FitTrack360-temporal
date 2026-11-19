import 'package:fit_track_360/features/auth/data/google_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements GoogleAuthGateway {
  _FakeGateway({this.cancel = false, this.tokens});

  final bool cancel;
  final GoogleAuthTokens? tokens;

  @override
  Future<GoogleAuthTokens> signIn() async {
    if (cancel) throw const GoogleSignInCancelledException();
    final value = tokens;
    if (value == null) {
      throw const AuthGoogleTokensMissingException();
    }
    return value;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  test('cancelacion expone GoogleSignInCancelledException', () async {
    final gateway = _FakeGateway(cancel: true);
    expect(gateway.signIn(), throwsA(isA<GoogleSignInCancelledException>()));
  });

  test('tokens faltantes exponen mensaje de configuracion', () async {
    final gateway = _FakeGateway();
    expect(gateway.signIn(), throwsA(isA<AuthGoogleTokensMissingException>()));
  });

  test('signIn exitoso devuelve id y access token', () async {
    final gateway = _FakeGateway(
      tokens: const GoogleAuthTokens(
        idToken: 'id',
        accessToken: 'access',
        email: 'a@test.com',
        displayName: 'Ana',
      ),
    );

    final tokens = await gateway.signIn();
    expect(tokens.idToken, 'id');
    expect(tokens.accessToken, 'access');
    expect(tokens.email, 'a@test.com');
  });
}
