# PRD / Documento de Requisitos de Producto · FitTrack360

## 1. Visión del producto

FitTrack360 es una aplicación móvil diseñada para deportistas y personas activas que buscan autogestionar de manera estructurada su progreso físico y hábitos nutricionales. A diferencia de las aplicaciones genéricas saturadas de publicidad o modelos de suscripción opacos, FitTrack360 prioriza la privacidad de los datos, la rapidez en la captura durante el entrenamiento y la transparencia nutricional con soporte visual de técnica en cada ejercicio.

---

## 2. Tabla de decisiones de producto

| # | Decisión | Alternativa descartada | Por qué | Fecha |
| :--- | :--- | :--- | :--- | :--- |
| **P-01** | **Captura rápida de series en una sola pantalla:** Registro de repeticiones y peso dentro de la vista activa del entrenamiento con teclado numérico optimizado y retroalimentación táctil. | Flujo de múltiples pantallas modales emergentes por cada serie realizada. | La fricción durante el levantamiento de peso provoca abandono de la app; la captura debe realizarse en menos de 10 segundos entre pausas de descanso. | 2026-10-22 |
| **P-02** | **Degradación manual obligatoria para nutrición:** Toda búsqueda de alimentos permite alternar a captura manual directa de calorías y macronutrientes si el alimento no existe o la red falla. | Bloquear el registro de comida hasta que el usuario encuentre una coincidencia exacta en la base de datos externa de USDA. | Los deportistas consumen preparaciones caseras o marcas locales no listadas en bases internacionales; la app no debe impedir el conteo calórico diario. | 2026-10-22 |
| **P-03** | **Consentimiento de privacidad explícito al registrarse:** La casilla de aceptación del aviso de privacidad es obligatoria para habilitar el botón de creación de cuenta, guardando timestamp y versión del aviso. | Aceptación implícita mediante textos del tipo "Al continuar aceptas los términos y condiciones". | Garantiza el cumplimiento normativo con la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP) y estándares de Google Play Store. | 2026-10-22 |
| **P-04** | **Tema visual exclusivamente oscuro (Liquid Glass):** Interfaz basada en fondos oscuros profundos y superficies traslúcidas de vidrio esmerilado con acentos plata. | Implementación de selector dinámico de tema claro/oscuro en la versión inicial. | Los entornos de gimnasio con iluminación artificial intensa se benefician de pantallas oscuras de alto contraste; además reduce el consumo energético en pantallas OLED y focaliza el esfuerzo de diseño. | 2026-10-22 |

---

## 3. Historias de usuario

### Historia 1: Registro e inicio de sesión con consentimiento informado
- **Enunciado:** Como persona interesada en mejorar mi condición física, quiero crear una cuenta segura con mi correo y contraseña aceptando el aviso de privacidad, para acceder a mi historial personalizado de entrenamientos y proteger mis datos personales.
- **Módulo del SOW:** Módulo 2 (Autenticación y Sesión) · **Fase:** 1 · **Prioridad:** Alta.
- **Criterios de aceptación:**
  1. *Dado* que me encuentro en la pantalla de registro y he llenado mi correo, nombre y contraseña válida, *cuando* la casilla de aceptación del aviso de privacidad no está marcada, *entonces* el botón de registro permanece inactivo y muestra una advertencia visual indicando que el consentimiento es obligatorio.
  2. *Dado* que confirmo el registro con credenciales válidas y consentimiento marcado, *cuando* el servidor responde exitosamente (HTTP 201), *entonces* la aplicación navega directamente a la pantalla principal (Home), almacenando el token de acceso y de refresco en el almacenamiento seguro del sistema sin requerir un login adicional.

### Historia 2: Registro de sesión de entrenamiento con técnica asistida
- **Enunciado:** Como deportista en el gimnasio, quiero registrar una sesión de entrenamiento añadiendo ejercicios de la guía visual con sus series, repeticiones y peso levantado, para llevar el control exacto de mi sobrecarga progresiva.
- **Módulo del SOW:** Módulo 3 (Entrenamientos) · **Fase:** 2 · **Prioridad:** Alta.
- **Criterios de aceptación:**
  1. *Dado* que inicio un entrenamiento y selecciono un ejercicio del catálogo (por ejemplo, press de banca), *cuando* pulso en el botón de información técnica, *entonces* la app despliega en menos de 300 ms la vista de detalle con la animación GIF correspondiente, instrucciones en español y la leyenda de atribución a Gym Visual.
  2. *Dado* que añado 4 series con valores de peso y repeticiones y pulso en "Finalizar entrenamiento", *cuando* el dispositivo tiene conexión a internet, *entonces* la sesión se persiste en la base de datos PostgreSQL mediante `POST /api/v1/workouts` y queda reflejada inmediatamente en el historial y en el resumen diario de Home.

### Historia 3: Registro de comidas con búsqueda nutricional y fallback manual
- **Enunciado:** Como persona que monitorea su nutrición deportiva, quiero buscar alimentos para registrar mis comidas diarias o introducir los macronutrientes manualmente, para contabilizar mis calorías, proteínas, carbohidratos y grasas acumuladas en el día.
- **Módulo del SOW:** Módulo 4 (Nutrición y Catálogo) · **Fase:** 3 · **Prioridad:** Media.
- **Criterios de aceptación:**
  1. *Dado* que escribo un término de búsqueda (ej. "chicken breast") en el buscador de alimentos, *cuando* transcurre el debounce de 400 ms, *entonces* el sistema consulta la API de USDA FDC vía proxy y lista los alimentos coincidentes mostrando gramos de porción, calorías y macros calculados.
  2. *Dado* que la búsqueda no arroja resultados o la conexión de red falla, *cuando* selecciono la opción "Captura manual", *entonces* se habilita un formulario donde puedo ingresar nombre del alimento, gramos, calorías (kcal), proteínas (g), carbohidratos (g) y grasas (g), guardando el registro local y remotamente de forma exitosa.

---

## 4. Requisitos no funcionales (NFR)

### NFR-01: Seguridad y protección de credenciales (S1, S3)
- **Condición:** Los tokens de sesión JWT (Access Token de 15 minutos y Refresh Token de 7 días) deben guardarse exclusivamente en almacenamiento cifrado del dispositivo (`flutter_secure_storage` respaldado por Android KeyStore y Apple Keychain). En ningún caso se deben escribir tokens, contraseñas o datos personales en `SharedPreferences`, `UserDefaults` ni en registros de consola (`print` o `console.log`).
- **Verificación:** Inspección de almacenamiento en emulador y validación de filtros en la API para garantizar que las respuestas de error omitan volcados de pila o variables de entorno.

### NFR-02: Rendimiento y tiempo de respuesta (F3, F6)
- **Condición:** El tiempo de respuesta de la API para endpoints de lectura local (catálogo de ejercicios, listado de entrenamientos del usuario) debe ser inferior a 300 milisegundos en el percentil 95 (P95). Las consultas hacia la API de terceros (USDA FDC) deben contar con un timeout estricto de 5000 milisegundos en el backend de NestJS, devolviendo un error controlado y recuperable si el servicio externo no responde.
- **Verificación:** Pruebas de carga controladas y medición de telemetría de red con Axios/HttpService en NestJS.

### NFR-03: Disponibilidad y resiliencia ante pérdida de red (F7)
- **Condición:** La aplicación móvil debe detectar el cambio en la conectividad en menos de 1000 milisegundos mediante `connectivity_plus`. Al perder la conexión, se debe mostrar un banner superior informativo con botón "Reintentar" sin bloquear la navegación de la app ni provocar excepciones no controladas (*crashes*), manteniendo la información ingresada en los formularios en memoria local.
- **Verificación:** Prueba manual en modo avión y prueba de widget automatizada que simula desconexión y valida la visibilidad del banner `OfflineBanner`.

---

## 5. Fuera de alcance

En concordancia con el SOW (`docs/specs/01-alcance.md`), los siguientes elementos quedan formalmente excluidos de esta versión:
1. Pasarelas de pago, suscripciones premium y procesamiento de tarjetas de crédito o débito.
2. Planes de alimentación terapéuticos, diagnóstico de patologías metabólicas y asesoramiento médico prescriptivo.
3. Recomendaciones automatizadas generadas por modelos de lenguaje grande (LLM / IA generativa).
4. Sincronización colaborativa o funciones sociales de chat en tiempo real entre múltiples usuarios.
5. Versión web de escritorio y binario ejecutable para sistemas operativos de escritorio.
