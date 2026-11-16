# Auth (Firebase Auth + PostgreSQL)

Si un recurso no pertenece al usuario autenticado, la API responde **404 Not Found**.
No uses 403 para ownership: un 403 confirma que el recurso existe.

## Flujo AUTH-01

1. Flutter autentica con Firebase Auth (email/password).
2. Envía el **ID token** como `Authorization: Bearer …`.
3. `POST /auth/register` crea el `User` en Postgres con `firebaseUid`.
4. `POST /auth/session` resuelve el `User` tras login.
5. `FirebaseAuthGuard` verifica el ID token y adjunta `request.user.sub` (= id Postgres).

## Modos

| `FIREBASE_AUTH_MODE` | Comportamiento |
| --- | --- |
| `admin` (default) | `firebase-admin` con project + service account |
| `mock` | Acepta tokens `mock:<uid>:<email>` (tests/CI) |

Ver checklist manual: `docs/task-planning/firebase-auth-manual-checklist.md`.
