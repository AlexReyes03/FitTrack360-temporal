import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/data/firebase_auth_service.dart';
import 'package:fit_track_360/features/auth/data/google_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser extends Fake implements User {
  _FakeUser({this.email});

  @override
  final String? email;

  @override
  String? get displayName => null;

  int deleteCalls = 0;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'id-token';

  @override
  Future<void> delete() async => deleteCalls++;
}

class _FakeCredential extends Fake implements UserCredential {
  _FakeCredential(this.user, {required bool isNewUser})
    : additionalUserInfo = AdditionalUserInfo(isNewUser: isNewUser);

  @override
  final User user;

  @override
  final AdditionalUserInfo additionalUserInfo;
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth(this.user, {this.isNewUser = true});

  final _FakeUser user;
  final bool isNewUser;
  bool signedIn = false;
  int signInCalls = 0;
  AuthCredential? lastCredential;
  int signOutCalls = 0;

  @override
  User? get currentUser => signedIn ? user : null;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signInCalls++;
    lastCredential = credential;
    signedIn = true;
    return _FakeCredential(user, isNewUser: isNewUser);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedIn = false;
  }
}

class _FakeGoogle implements GoogleAuthGateway {
  _FakeGoogle({this.error, this.email = 'ana.torres@gmail.com'});

  final Object? error;
  final String? email;
  int signOutCalls = 0;

  @override
  Future<GoogleAuthTokens> signIn() async {
    final value = error;
    if (value != null) throw value;
    return GoogleAuthTokens(
      idToken: 'g-id',
      email: email,
      displayName: 'Ana Torres',
    );
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

/// Random determinista: devuelve 1, 2, 3... para sufijos predecibles.
class _SeqRandom implements Random {
  int _next = 1;

  @override
  int nextInt(int max) => _next++ % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

const _user = AuthUser(
  id: 'u1',
  email: 'ana.torres@gmail.com',
  username: 'ana_torres',
  displayName: 'Ana Torres',
  firebaseUid: 'uid-1',
);

const _notSynced = AuthApiException('Usuario no sincronizado', statusCode: 401);
const _usernameTaken = AuthApiException(
  'El usuario ya esta registrado',
  statusCode: 409,
);

class _RegisterCall {
  _RegisterCall(this.username, this.displayName, this.consent, this.version);

  final String username;
  final String displayName;
  final bool consent;
  final String version;
}

class _Harness {
  _Harness({
    Object? googleError,
    String? googleEmail = 'ana.torres@gmail.com',
    String? firebaseEmail,
    bool isNewUser = true,
    this.sessionResult,
    this.sessionError = _notSynced,
    List<Object>? registerErrors,
  }) : firebaseUser = _FakeUser(email: firebaseEmail),
       registerErrors = [...?registerErrors] {
    google = _FakeGoogle(error: googleError, email: googleEmail);
    auth = _FakeFirebaseAuth(firebaseUser, isNewUser: isNewUser);
    service = FirebaseAuthService(
      auth: auth,
      googleAuth: google,
      random: _SeqRandom(),
      syncSessionFn: ({required String idToken}) async {
        sessionCalls++;
        final result = sessionResult;
        if (result != null) return result;
        throw sessionError;
      },
      syncRegisterFn:
          ({
            required String idToken,
            required String username,
            required String displayName,
            required bool privacyConsent,
            required String privacyNoticeVersion,
          }) async {
            registerCalls.add(
              _RegisterCall(
                username,
                displayName,
                privacyConsent,
                privacyNoticeVersion,
              ),
            );
            if (this.registerErrors.isNotEmpty) {
              throw this.registerErrors.removeAt(0);
            }
            return _user;
          },
    );
  }

  final _FakeUser firebaseUser;
  late final _FakeGoogle google;
  late final _FakeFirebaseAuth auth;
  late final FirebaseAuthService service;
  final AuthUser? sessionResult;
  final Object sessionError;
  final List<Object> registerErrors;
  int sessionCalls = 0;
  final List<_RegisterCall> registerCalls = [];

  Future<AuthUser> register() => service.loginWithGoogle(
    allowAutoRegister: true,
    privacyConsent: true,
    privacyNoticeVersion: '2',
  );

  void expectRolledBack({required bool deleted}) {
    expect(google.signOutCalls, greaterThanOrEqualTo(1));
    expect(auth.signOutCalls, greaterThanOrEqualTo(1));
    expect(firebaseUser.deleteCalls, deleted ? 1 : 0);
  }
}

Matcher _apiError(String message) =>
    throwsA(isA<AuthApiException>().having((e) => e.message, 'msg', message));

void main() {
  group('loginWithGoogle', () {
    test(
      'usuario existente: session devuelve el perfil sin registrar',
      () async {
        final h = _Harness(sessionResult: _user);

        final user = await h.service.loginWithGoogle();

        expect(user.id, 'u1');
        final credential = h.auth.lastCredential as OAuthCredential;
        expect(credential.providerId, 'google.com');
        expect(credential.idToken, 'g-id');
        expect(h.registerCalls, isEmpty);
        expect(h.firebaseUser.deleteCalls, 0);
      },
    );

    test(
      'fallback a register con consentimiento usa username del correo',
      () async {
        final h = _Harness();

        final user = await h.register();

        expect(user.username, 'ana_torres');
        expect(h.registerCalls, hasLength(1));
        final call = h.registerCalls.single;
        expect(call.username, 'ana_torres');
        expect(call.displayName, 'Ana Torres');
        expect(call.consent, isTrue);
        expect(call.version, '2');
      },
    );

    test('login sin cuenta vinculada: error claro y rollback', () async {
      final h = _Harness();

      await expectLater(
        h.service.loginWithGoogle(),
        _apiError(googleAccountNotLinkedMessage),
      );
      expect(h.registerCalls, isEmpty);
      h.expectRolledBack(deleted: true);
    });

    test('registro sin consentimiento no inventa aceptacion', () async {
      final h = _Harness();

      await expectLater(
        h.service.loginWithGoogle(allowAutoRegister: true),
        _apiError(googleAccountNotLinkedMessage),
      );
      expect(h.registerCalls, isEmpty);
      h.expectRolledBack(deleted: true);
    });

    test('colision de username reintenta con sufijo numerico', () async {
      final h = _Harness(registerErrors: [_usernameTaken, _usernameTaken]);

      await h.register();

      final names = h.registerCalls.map((c) => c.username).toList();
      expect(names, ['ana_torres', 'ana_torres_1001', 'ana_torres_1002']);
      for (final name in names) {
        expect(name.length, inInclusiveRange(3, 30));
        expect(RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name), isTrue);
      }
    });

    test('sufijo respeta el maximo de 30 caracteres del DTO', () async {
      final h = _Harness(
        googleEmail: 'nombre.muy.largo.para.un.usuario@gmail.com',
        registerErrors: [_usernameTaken],
      );

      await h.register();

      final retry = h.registerCalls[1].username;
      expect(retry.length, lessThanOrEqualTo(30));
      expect(retry, endsWith('_1001'));
    });

    test('colisiones agotadas: intentos acotados y rollback', () async {
      final h = _Harness(registerErrors: List.filled(10, _usernameTaken));

      await expectLater(h.register(), throwsA(isA<AuthApiException>()));

      expect(h.registerCalls, hasLength(6));
      h.expectRolledBack(deleted: true);
    });

    test(
      '409 en session (correo de otra cuenta) se mapea y no registra',
      () async {
        final h = _Harness(
          isNewUser: false,
          sessionError: const AuthApiException(
            'El correo ya esta registrado con otra cuenta',
            statusCode: 409,
          ),
        );

        await expectLater(h.register(), _apiError(googleEmailTakenMessage));
        expect(h.registerCalls, isEmpty);
        h.expectRolledBack(deleted: false);
      },
    );

    test('409 de correo en register borra el usuario Firebase nuevo', () async {
      final h = _Harness(
        registerErrors: [
          const AuthApiException(
            'El correo ya esta registrado',
            statusCode: 409,
          ),
        ],
      );

      await expectLater(h.register(), _apiError(googleEmailTakenMessage));
      expect(h.registerCalls, hasLength(1));
      h.expectRolledBack(deleted: true);
    });

    test('401 Token invalido no dispara registro', () async {
      final h = _Harness(
        sessionError: const AuthApiException('Token invalido', statusCode: 401),
      );

      await expectLater(h.register(), _apiError('Token invalido'));
      expect(h.registerCalls, isEmpty);
      h.expectRolledBack(deleted: true);
    });

    test('fallo inesperado en register hace rollback y relanza', () async {
      final h = _Harness(registerErrors: [Exception('socket')]);

      await expectLater(h.register(), throwsA(isA<Exception>()));
      h.expectRolledBack(deleted: true);
    });

    test('usuario Firebase previo no se borra si falla el registro', () async {
      final h = _Harness(
        isNewUser: false,
        registerErrors: [
          const AuthApiException('Error interno', statusCode: 500),
        ],
      );

      await expectLater(h.register(), throwsA(isA<AuthApiException>()));
      h.expectRolledBack(deleted: false);
    });

    test(
      'cuenta Google sin correo no se registra con correo inventado',
      () async {
        final h = _Harness(googleEmail: null);

        await expectLater(h.register(), throwsA(isA<AuthApiException>()));
        expect(h.registerCalls, isEmpty);
        h.expectRolledBack(deleted: true);
      },
    );

    test('Google no disponible se expone como mensaje en espanol', () async {
      final h = _Harness(
        googleError: const GoogleSignInUnavailableException(
          code: 'sign_in_failed',
        ),
      );

      await expectLater(
        h.service.loginWithGoogle(),
        _apiError(googleSignInUnavailableMessage),
      );
      expect(h.auth.signInCalls, 0);
    });

    test('cancelar el selector relanza la cancelacion', () async {
      final h = _Harness(googleError: const GoogleSignInCancelledException());

      await expectLater(
        h.service.loginWithGoogle(),
        throwsA(isA<GoogleSignInCancelledException>()),
      );
      expect(h.auth.signInCalls, 0);
    });
  });
}
