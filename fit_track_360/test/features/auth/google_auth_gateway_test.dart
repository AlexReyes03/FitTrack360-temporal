import 'package:fit_track_360/features/auth/data/google_auth_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeAuthentication extends Fake implements GoogleSignInAuthentication {
  _FakeAuthentication({this.idToken, this.accessToken});

  @override
  final String? idToken;

  @override
  final String? accessToken;
}

class _FakeAccount extends Fake implements GoogleSignInAccount {
  _FakeAccount({this.auth, this.authError});

  final GoogleSignInAuthentication? auth;
  final Object? authError;

  @override
  String get email => 'ana@test.com';

  @override
  String? get displayName => 'Ana';

  @override
  Future<GoogleSignInAuthentication> get authentication async {
    final error = authError;
    if (error != null) throw error;
    return auth!;
  }
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  _FakeGoogleSignIn({this.account, this.error});

  final GoogleSignInAccount? account;
  final Object? error;
  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    final value = error;
    if (value != null) throw value;
    return account;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls++;
    return null;
  }
}

GoogleSignInGateway _gateway(_FakeGoogleSignIn googleSignIn) =>
    GoogleSignInGateway(googleSignIn: googleSignIn);

void main() {
  group('GoogleSignInGateway', () {
    test('signIn exitoso devuelve tokens y datos del perfil', () async {
      final gateway = _gateway(
        _FakeGoogleSignIn(
          account: _FakeAccount(
            auth: _FakeAuthentication(idToken: 'id', accessToken: 'access'),
          ),
        ),
      );

      final tokens = await gateway.signIn();

      expect(tokens.idToken, 'id');
      expect(tokens.accessToken, 'access');
      expect(tokens.email, 'ana@test.com');
      expect(tokens.displayName, 'Ana');
    });

    test('cerrar el selector (cuenta null) es cancelacion', () async {
      final gateway = _gateway(_FakeGoogleSignIn());

      expect(gateway.signIn(), throwsA(isA<GoogleSignInCancelledException>()));
    });

    test('PlatformException sign_in_canceled es cancelacion, no error', () {
      final gateway = _gateway(
        _FakeGoogleSignIn(
          error: PlatformException(code: GoogleSignIn.kSignInCanceledError),
        ),
      );

      expect(gateway.signIn(), throwsA(isA<GoogleSignInCancelledException>()));
    });

    test(
      'DEVELOPER_ERROR (sign_in_failed) se mapea a no disponible en espanol',
      () async {
        final gateway = _gateway(
          _FakeGoogleSignIn(
            error: PlatformException(
              code: GoogleSignIn.kSignInFailedError,
              message: 'com.google.android.gms.common.api.ApiException: 10: ',
            ),
          ),
        );

        await expectLater(
          gateway.signIn(),
          throwsA(
            isA<GoogleSignInUnavailableException>()
                .having((e) => e.code, 'code', 'sign_in_failed')
                .having(
                  (e) => e.message,
                  'message',
                  googleSignInUnavailableMessage,
                ),
          ),
        );
      },
    );

    test('cliente OAuth faltante (codigo desconocido) es no disponible', () {
      final gateway = _gateway(
        _FakeGoogleSignIn(
          error: PlatformException(code: 'missing-config', message: 'No ID'),
        ),
      );

      expect(
        gateway.signIn(),
        throwsA(isA<GoogleSignInUnavailableException>()),
      );
    });

    test('network_error se mapea a error de red', () {
      final gateway = _gateway(
        _FakeGoogleSignIn(
          error: PlatformException(code: GoogleSignIn.kNetworkError),
        ),
      );

      expect(
        gateway.signIn(),
        throwsA(
          isA<GoogleSignInNetworkException>().having(
            (e) => e.message,
            'message',
            googleSignInNetworkMessage,
          ),
        ),
      );
    });

    test('PlatformException al pedir tokens tambien se mapea', () {
      final gateway = _gateway(
        _FakeGoogleSignIn(
          account: _FakeAccount(
            authError: PlatformException(code: 'failed_to_recover_auth'),
          ),
        ),
      );

      expect(
        gateway.signIn(),
        throwsA(isA<GoogleSignInUnavailableException>()),
      );
    });

    test('tokens vacios son configuracion no disponible', () {
      final gateway = _gateway(
        _FakeGoogleSignIn(
          account: _FakeAccount(
            auth: _FakeAuthentication(idToken: null, accessToken: 'access'),
          ),
        ),
      );

      expect(
        gateway.signIn(),
        throwsA(isA<GoogleSignInUnavailableException>()),
      );
    });

    test('signOut delega en GoogleSignIn', () async {
      final googleSignIn = _FakeGoogleSignIn();
      await _gateway(googleSignIn).signOut();

      expect(googleSignIn.signOutCalls, 1);
    });
  });
}
