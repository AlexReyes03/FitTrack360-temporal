import 'package:fit_track_360/features/auth/data/google_auth_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeAccount extends Fake implements GoogleSignInAccount {
  _FakeAccount({this.idToken = 'id'});

  final String? idToken;

  @override
  String get email => 'ana@test.com';

  @override
  String? get displayName => 'Ana';

  @override
  GoogleSignInAuthentication get authentication =>
      GoogleSignInAuthentication(idToken: idToken);
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  _FakeGoogleSignIn({
    GoogleSignInAccount? account,
    this.error,
    this.initError,
    this.supportsAuth = true,
  }) : account = account ?? _FakeAccount();

  final GoogleSignInAccount account;
  final Object? error;
  Object? initError;
  final bool supportsAuth;
  int initializeCalls = 0;
  int authenticateCalls = 0;
  int signOutCalls = 0;
  String? lastServerClientId;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializeCalls++;
    lastServerClientId = serverClientId;
    final value = initError;
    if (value != null) throw value;
  }

  @override
  bool supportsAuthenticate() => supportsAuth;

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    authenticateCalls++;
    final value = error;
    if (value != null) throw value;
    return account;
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

GoogleSignInGateway _gateway(
  _FakeGoogleSignIn googleSignIn, {
  String? serverClientId,
}) => GoogleSignInGateway(
  googleSignIn: googleSignIn,
  serverClientId: serverClientId,
);

GoogleSignInException _googleError(
  GoogleSignInExceptionCode code, [
  String? description,
]) => GoogleSignInException(code: code, description: description);

void main() {
  group('GoogleSignInGateway (google_sign_in 7.x)', () {
    test('authenticate exitoso devuelve idToken y datos del perfil', () async {
      final google = _FakeGoogleSignIn();

      final tokens = await _gateway(google, serverClientId: 'web-id').signIn();

      expect(tokens.idToken, 'id');
      expect(tokens.email, 'ana@test.com');
      expect(tokens.displayName, 'Ana');
      expect(google.lastServerClientId, 'web-id');
    });

    test(
      'initialize se llama una sola vez por instancia de GoogleSignIn',
      () async {
        final google = _FakeGoogleSignIn();

        await _gateway(google).signIn();
        await _gateway(google).signIn();
        await _gateway(google).signOut();

        expect(google.initializeCalls, 1);
        expect(google.authenticateCalls, 2);
      },
    );

    test('initialize fallido se mapea y permite reintentar', () async {
      final google = _FakeGoogleSignIn(
        initError: PlatformException(code: 'missing-config'),
      );

      await expectLater(
        _gateway(google).signIn(),
        throwsA(isA<GoogleSignInUnavailableException>()),
      );

      google.initError = null;
      await _gateway(google).signIn();
      expect(google.initializeCalls, 2);
    });

    test('canceled es cancelacion, no error', () {
      final google = _FakeGoogleSignIn(
        error: _googleError(GoogleSignInExceptionCode.canceled),
      );

      expect(
        _gateway(google).signIn(),
        throwsA(isA<GoogleSignInCancelledException>()),
      );
    });

    test(
      'clientConfigurationError (DEVELOPER_ERROR / client ID) es no disponible',
      () async {
        final google = _FakeGoogleSignIn(
          error: _googleError(
            GoogleSignInExceptionCode.clientConfigurationError,
            'serverClientId must be provided on Android',
          ),
        );

        await expectLater(
          _gateway(google).signIn(),
          throwsA(
            isA<GoogleSignInUnavailableException>()
                .having((e) => e.code, 'code', 'clientConfigurationError')
                .having(
                  (e) => e.message,
                  'message',
                  googleSignInUnavailableMessage,
                ),
          ),
        );
      },
    );

    test(
      'providerConfigurationError y uiUnavailable son no disponible',
      () async {
        for (final code in [
          GoogleSignInExceptionCode.providerConfigurationError,
          GoogleSignInExceptionCode.uiUnavailable,
          GoogleSignInExceptionCode.interrupted,
        ]) {
          await expectLater(
            _gateway(_FakeGoogleSignIn(error: _googleError(code))).signIn(),
            throwsA(isA<GoogleSignInUnavailableException>()),
            reason: code.name,
          );
        }
      },
    );

    test('unknownError de red se mapea a error de red', () {
      final google = _FakeGoogleSignIn(
        error: _googleError(
          GoogleSignInExceptionCode.unknownError,
          'A network error occurred',
        ),
      );

      expect(
        _gateway(google).signIn(),
        throwsA(
          isA<GoogleSignInNetworkException>().having(
            (e) => e.message,
            'message',
            googleSignInNetworkMessage,
          ),
        ),
      );
    });

    test('PlatformException nativa residual es no disponible', () {
      final google = _FakeGoogleSignIn(
        error: PlatformException(code: 'sign_in_failed', message: '10: '),
      );

      expect(
        _gateway(google).signIn(),
        throwsA(isA<GoogleSignInUnavailableException>()),
      );
    });

    test('plataforma sin authenticate es no disponible', () async {
      final google = _FakeGoogleSignIn(supportsAuth: false);

      await expectLater(
        _gateway(google).signIn(),
        throwsA(isA<GoogleSignInUnavailableException>()),
      );
      expect(google.authenticateCalls, 0);
    });

    test('idToken vacio es configuracion no disponible', () {
      final google = _FakeGoogleSignIn(account: _FakeAccount(idToken: null));

      expect(
        _gateway(google).signIn(),
        throwsA(isA<GoogleSignInUnavailableException>()),
      );
    });

    test('signOut delega en GoogleSignIn', () async {
      final google = _FakeGoogleSignIn();
      await _gateway(google).signOut();

      expect(google.signOutCalls, 1);
    });
  });
}
