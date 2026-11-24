# auth

Autenticación: registro, inicio de sesión, sesión, recuperación de contraseña y Google (AUTH-02).

## Flujo y UX (#230)

- Copy: `domain/auth_messages.dart` (fuente: `docs/copy/auth-strings.md`).
- Errores: `presentation/auth_error_messages.dart` (`describeAuthError`) traduce respuestas de Nest por status y códigos de Firebase (`AuthMessages.forFirebaseCode`); nunca muestra `e.message` crudo.
- ViewModels: `presentation/auth_view_models.dart` (`LoginViewModel`, `RegisterViewModel`, `ForgotPasswordViewModel`) con `AsyncState`.
- Navegación: `backToLogin` hace `pop` o `go('/login')`; login pasa el correo a `/forgot-password` por `extra`; `/aviso-privacidad` es pública.
- Splash: sin sesión va directo a `/login`.

## AUTH-02 Google

- UI: `presentation/widgets/google_sign_in_section.dart` en login/registro.
- Logica: `FirebaseAuthService.loginWithGoogle` + `GoogleSignInGateway`.
- Nest: `POST /auth/session` (existente / conflicto por correo) y `POST /auth/register` para el primer Google con consentimiento.
- Config: `GOOGLE_WEB_CLIENT_ID` via `--dart-define`, SHA en Console, checklist seccion 10.
- `google_sign_in` 7.2.0 (fijo; GoogleSignIn-iOS 9+/AppCheck 12, compatible con firebase-ios-sdk 13). `GoogleSignIn.instance.initialize` se llama una vez por proceso y `authenticate()` solo pide idToken.
- Errores (`GoogleSignInException`): `canceled` es cancelacion silenciosa; `unknownError` de red muestra error de conexion; el resto (configuracion de cliente/SDK, DEVELOPER_ERROR, sin UI) se muestra como "no disponible" en español.
- Flujo por status HTTP de Nest: `classifyAuthApiFailure` (401 no sincronizado vs token invalido, 409 correo/usuario/UID).
- Username: primero el derivado del correo; tras colision, sufijo aleatorio `_NNNN` (hasta 5 intentos, max 30 chars).
- Si el alta falla y el usuario Firebase se creo en este flujo, se borra (igual que AUTH-01).
