# auth

Autenticacion: registro, login, sesion, recuperacion de contraseña y Google (AUTH-02).

## AUTH-02 Google

- UI: `presentation/widgets/google_sign_in_section.dart` en login/registro.
- Logica: `FirebaseAuthService.loginWithGoogle` + `GoogleSignInGateway`.
- Nest: `POST /auth/session` (existente / conflicto por correo) y `POST /auth/register` para el primer Google con consentimiento.
- Config: `GOOGLE_WEB_CLIENT_ID` via `--dart-define`, SHA en Console, checklist seccion 10.
- Errores nativos de `google_sign_in` (`PlatformException`): `sign_in_canceled` es cancelacion silenciosa; `network_error` y el resto (DEVELOPER_ERROR, cliente OAuth faltante) se muestran con mensaje en español.
- Flujo por status HTTP de Nest: `classifyAuthApiFailure` (401 no sincronizado vs token invalido, 409 correo/usuario/UID).
- Username: primero el derivado del correo; tras colision, sufijo aleatorio `_NNNN` (hasta 5 intentos, max 30 chars).
- Si el alta falla y el usuario Firebase se creo en este flujo, se borra (igual que AUTH-01).
