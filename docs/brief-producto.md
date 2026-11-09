# Brief de producto: FitTrack360

> **Versión:** v1, entrega del cuatrimestre. **Corte:** 2026-11-06. **Audiencia:** equipo, docente y revisores del proyecto integrador. **Fuentes:** `docs/specs/01-alcance.md`, `docs/specs/02-prd.md`, `docs/plans/plan-maestro-fittrack360.md`, `docs/permisos.md` y `docs/estado.md`.

## Qué es

FitTrack360 es una app móvil con API propia para registrar entrenamientos de fuerza, comidas y macronutrientes, y consultar la técnica de cada ejercicio con una guía visual, sin sustituir la asesoría médica o nutricional.

## Para quién y qué problema resuelve

Para personas que entrenan y cuidan su alimentación, y que hoy reparten el registro entre una app para la rutina, otra para las calorías y otra para buscar cómo se ejecuta un ejercicio. Esa dispersión hace que el registro se abandone durante el entrenamiento y que el conteo de macros quede incompleto. FitTrack360 concentra las tres tareas en una sola app: captura rápida de series en la pantalla activa (decisión P-01), búsqueda nutricional con captura manual cuando el alimento no existe o la red falla (P-02) y consentimiento explícito de privacidad desde el registro (P-03).

No es una app clínica: no calcula dietas terapéuticas ni emite prescripciones.

## Qué sí hace la primera versión

- **Cuenta y sesión:** registro con consentimiento de privacidad, login, logout, restauración de sesión al reabrir y recuperación de contraseña con código de 6 dígitos. Los tokens viven en almacenamiento cifrado del dispositivo.
- **Entrenamientos:** CRUD de sesiones con series, repeticiones y carga; historial por usuario; rutinas como plantilla.
- **Alimentación:** CRUD de comidas con alimentos, porciones y macros; búsqueda en USDA FoodData Central a través del proxy de NestJS; captura manual como respaldo. Los macros se copian y congelan en cada registro.
- **Catálogo:** 1324 ejercicios con filtros por grupo muscular, equipamiento y objetivo; instrucciones en español, GIF de 180x180 y atribución a Gym Visual.
- **Dispositivo:** foto de progreso o comida comprimida y con acceso solo del dueño (P1); ubicación aproximada al cerrar una sesión (P2); recordatorio local (P3); biometría (O1), pasos del día (O5), envío por WhatsApp o SMS (O7) y hoja de compartir (O10).
- **Privacidad:** aviso de privacidad, exportación de datos en JSON y borrado de cuenta en cascada.
- **Entrega:** APK y AAB firmados para Android; iOS y AppGallery solo con expediente documental.

## Qué no hace todavía

**Fuera de alcance de la v1:**

- Pagos, suscripciones o compras dentro de la app (D-06).
- Diagnóstico, dietas terapéuticas o prescripción médica y nutricional.
- Generación automática de rutinas con IA o modelos de lenguaje.
- Sincronización en tiempo real entre dispositivos o funciones sociales de chat.
- Versión web o de escritorio.
- IPA para iOS; solo se documenta la arquitectura y el expediente.

**Pendiente de implementar o verificar:**

- El destino de nube sigue sin decidirse. El almacenamiento actual usa disco local y no cumple el criterio de nube con ACL del proveedor.
- P1 no tiene selector de cámara o galería ni compresión implementada. La subida existe con aislamiento por `userId`, pero falta la prueba entre dos cuentas.
- Mailpit no está en `fit_track_api/docker-compose.yml`; sin SMTP configurado, la recuperación responde 200 sin enviar el código, así que la recepción real no está verificada.
- No existe la suite de 8 pruebas unitarias, 4 de widget y 1 de integración. Hoy solo hay pruebas de `AsyncState`, del banner offline y del endpoint raíz del API.
- No se ha ejecutado una prueba de extremo a extremo contra el API y PostgreSQL reales, ni la prueba de P1 y P2 en dispositivo físico.

## Cómo sabremos que funciona

1. Una persona completa el registro o el login en menos de 3 segundos con conexión 4G o Wi-Fi, y los tokens quedan cifrados en el dispositivo.
2. El catálogo carga en menos de 500 ms y permite filtrar al mismo tiempo por `bodyPart` y `equipment`, con GIF y atribución visibles.
3. Una sesión con 3 ejercicios y 4 series por ejercicio se guarda y aparece en el historial; otro usuario recibe 404 al intentar leerla.
4. La búsqueda en USDA responde en menos de 2 segundos. Si falla, la captura manual guarda calorías, proteínas, carbohidratos y grasas en menos de 1 minuto.
5. El registro exige el consentimiento de privacidad, y Ajustes permite exportar los datos en JSON y borrar la cuenta en cascada.
6. Un solo comando ejecuta 8 pruebas unitarias, 4 de widget y 1 de integración, todas en verde.
7. La app se instala desde un APK o AAB firmado.

## Tres preguntas abiertas

1. **Nube y almacenamiento.** El destino sigue sin decidirse y la fecha límite del 27 de octubre de 2026 ya pasó. ¿Qué opción se elige y cómo se garantiza que las fotos de P1 solo las vea su dueño?
2. **Dónde se comprime la foto.** `docs/permisos.md` ubica la reducción en el cliente con `maxWidth` e `imageQuality`, y el plan maestro también pide re-encode con `sharp` en el servidor. ¿La compresión vive en Flutter, en el API o en ambos, y qué evidencia se acepta?
3. **Qué cuenta como "funciona" en la entrega.** ¿Bastan los criterios de aceptación y la suite en verde, o se exige además una corrida de extremo a extremo contra API y PostgreSQL reales y la prueba de P1 y P2 en dispositivo físico?
