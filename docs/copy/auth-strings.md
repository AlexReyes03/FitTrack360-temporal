# Textos de autenticación — FitTrack360 (es-MX)

> **Tarea:** W8-29 (#30) · **Épica:** E2
>
> **Estado:** propuesta de textos para revisión e integración.
>
> **Alcance:** inicio de sesión, registro y recuperación de contraseña. No implementa pantallas, servicios ni localización ARB.
>
> **Privacidad:** alineado con el aviso de privacidad versión 1 (2026-11-02, W8-28).

## Convenciones

- Las claves son identificadores estables con formato `pantalla.elemento`; los errores usan `pantalla.error.caso`.
- Los valores son texto final en español, sin formato ni etiquetas.
- No se proponen campos ni reglas nuevas. Las reglas mencionadas son las vigentes en `login_page.dart`, `register_page.dart` y los DTO de autenticación.
- Los textos de recuperación y los enlaces que aún no existen en las pantallas se identifican como pendientes de integración.

## Inicio de sesión

| Clave | Texto en español |
| --- | --- |
| `login.title` | Inicia sesión |
| `login.emailLabel` | Correo electrónico |
| `login.emailHint` | tu@correo.com |
| `login.passwordLabel` | Contraseña |
| `login.submitButton` | Iniciar sesión |
| `login.forgotPasswordLink` | ¿Olvidaste tu contraseña? |
| `login.error.requiredFields` | Completa los campos obligatorios. |
| `login.error.invalidEmail` | Ingresa un correo electrónico válido. |
| `login.error.invalidCredentials` | El correo o la contraseña no son correctos. |
| `login.error.generic` | No pudimos iniciar sesión. Inténtalo de nuevo. |

**Notas de integración**

- La pantalla actual usa `Iniciar sesion` en la barra superior, `Correo`, `Entrar` y `Olvidaste tu contrasena?`; estos textos deben reemplazarse por las claves de la tabla.
- `login.error.invalidCredentials` debe mostrarse ante una respuesta 401, sin indicar cuál campo falló. Hoy la pantalla muestra el mensaje del API (`Credenciales incorrectas`).
- `login.error.generic` cubre fallos de red o del servicio. Hoy se muestra `No se pudo conectar`.
- El enlace de recuperación existe, pero hoy muestra `Disponible en una semana siguiente`. La pantalla de recuperación todavía no está integrada.

## Registro

| Clave | Texto en español |
| --- | --- |
| `register.title` | Crea tu cuenta |
| `register.usernameLabel` | Usuario |
| `register.emailLabel` | Correo electrónico |
| `register.emailHint` | tu@correo.com |
| `register.passwordLabel` | Contraseña |
| `register.confirmPasswordLabel` | Confirmar contraseña |
| `register.nameLabel` | Nombre |
| `register.submitButton` | Crear cuenta |
| `register.privacyConsentLabel` | He leído el aviso de privacidad y acepto el tratamiento de mis datos personales descrito en él. |
| `register.error.requiredFields` | Completa los campos obligatorios. |
| `register.error.invalidUsername` | El usuario debe tener entre 3 y 30 caracteres y solo puede incluir letras, números y guion bajo. |
| `register.error.invalidEmail` | Ingresa un correo electrónico válido. |
| `register.error.passwordTooShort` | La contraseña debe tener al menos 8 caracteres. |
| `register.error.passwordMismatch` | Las contraseñas no coinciden. |
| `register.error.emailAlreadyRegistered` | Ya existe una cuenta con este correo electrónico. |
| `register.error.usernameAlreadyRegistered` | Ese nombre de usuario ya está en uso. |
| `register.error.generic` | No pudimos crear tu cuenta. Inténtalo de nuevo. |

**Notas de integración**

- Los campos existentes son Usuario, Correo, Contraseña, Confirmar contraseña y Nombre. No se añaden campos.
- `register.error.invalidUsername` documenta la regla vigente: entre 3 y 30 caracteres, solo letras, números y guion bajo.
- `register.error.passwordTooShort` documenta la regla vigente de mínimo 8 caracteres; no propone una regla nueva.
- `register.error.emailAlreadyRegistered` y `register.error.usernameAlreadyRegistered` corresponden a los conflictos 409 del API. Hoy la pantalla muestra el mensaje del servidor sin adaptarlo.
- La casilla de consentimiento no debe aparecer marcada por defecto. La versión del aviso se envía actualmente como `privacyNoticeVersion: '1'` en el registro.
- El aviso exige consentimiento expreso e independiente para datos personales sensibles. Esta casilla no debe interpretarse como consentimiento para datos de salud, medidas corporales o fotografías; ese consentimiento debe solicitarse cuando el usuario decida proporcionarlos.

## Recuperación de contraseña

> **Pendiente de integración:** no existe una pantalla de recuperación en `fit_track_360/`. Los textos siguientes son la propuesta para cuando se implemente el flujo.

| Clave | Texto en español |
| --- | --- |
| `recovery.title` | Recupera tu contraseña |
| `recovery.instructions` | Ingresa tu correo electrónico. Si existe una cuenta asociada, te enviaremos instrucciones para restablecer tu contraseña. |
| `recovery.emailLabel` | Correo electrónico |
| `recovery.emailHint` | tu@correo.com |
| `recovery.submitButton` | Enviar instrucciones |
| `recovery.backToLoginLink` | Volver a iniciar sesión |
| `recovery.success` | Si existe una cuenta asociada a ese correo, recibirás instrucciones para restablecer tu contraseña. |
| `recovery.error.requiredEmail` | Ingresa tu correo electrónico. |
| `recovery.error.invalidEmail` | Ingresa un correo electrónico válido. |
| `recovery.error.generic` | No pudimos procesar tu solicitud. Inténtalo de nuevo. |

**Notas de seguridad**

- `recovery.instructions`, `recovery.success` y `recovery.error.generic` no confirman si el correo está registrado.
- No debe agregarse un mensaje como `El correo no está registrado` ni variantes que permitan descubrir qué cuentas existen.
- Para correos registrados y no registrados, mostrar el mismo mensaje de confirmación (`recovery.success`). Reservar `recovery.error.generic` para fallos técnicos y evitar respuestas que revelen si una cuenta existe.

## Claves pendientes de integración

| Clave | Texto propuesto | Motivo |
| --- | --- | --- |
| `register.privacyNoticeLink` | Consultar aviso de privacidad | La casilla actual no enlaza al aviso. |
| `register.loginPrompt` | ¿Ya tienes una cuenta? | El Registro actual no tiene enlace de inicio de sesión. |
| `register.loginLink` | Inicia sesión | Requiere agregar el enlace en Registro. |
| `register.error.consentRequired` | Acepta el aviso de privacidad para crear tu cuenta. | Hoy el botón se deshabilita; solo aplica si se muestra un error. |
| `login.registerPrompt` | ¿Todavía no tienes una cuenta? | El Inicio de sesión actual no tiene enlace de registro. |
| `login.registerLink` | Crear cuenta | Requiere agregar el enlace en Inicio de sesión. |

## Diferencias con las pantallas actuales

| Pantalla | Archivo | Situación actual |
| --- | --- | --- |
| Inicio de sesión | `fit_track_360/lib/features/auth/presentation/login_page.dart` | Título `Iniciar sesion`, campos `Correo` y `Contraseña`, botón `Entrar`, enlace `Olvidaste tu contrasena?` con aviso de disponibilidad futura y errores sin tildes. |
| Registro | `fit_track_360/lib/features/auth/presentation/register_page.dart` | Campos Usuario, Correo, Contraseña, Confirmar contraseña y Nombre; casilla `Acepto el aviso de privacidad`; botón `Crear cuenta`; sin enlace a Inicio de sesión; errores sin tildes. |
| Recuperación | No existe | El enlace de Inicio de sesión solo muestra `Disponible en una semana siguiente`. |

## Fuera de alcance

- Modificar pantallas Flutter, endpoints NestJS, autenticación, dependencias o archivos ARB.
- Implementar la recuperación de contraseña, el enlace al aviso o el enlace entre Registro e Inicio de sesión.
- Definir reglas de contraseña, campos nuevos o el mecanismo legal definitivo del consentimiento.
