# auth

Autenticacion: registro, login, sesion, recuperacion de contraseña y Google (AUTH-02).

## AUTH-02 Google

- UI: `presentation/widgets/google_sign_in_section.dart` en login/registro.
- Logica: `FirebaseAuthService.loginWithGoogle` + `GoogleSignInGateway`.
- Nest: `POST /auth/session` (existente / conflicto por correo) y `POST /auth/register` para el primer Google con consentimiento.
- Config: `GOOGLE_WEB_CLIENT_ID` via `--dart-define`, SHA en Console, checklist seccion 10.
