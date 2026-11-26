# INTEGRACIONES · Servicios Externos y APIs · FitTrack360

## 1. Propósito

Este documento describe los servicios externos, APIs de terceros y mecanismos de integración del ecosistema FitTrack360. Define el orden de incorporación de cada servicio, los protocolos de seguridad para resguardo de credenciales y la arquitectura de tolerancia a fallos ante caídas o degradación de proveedores externos.

---

## 2. Tabla de decisiones de integración

| #        | Decisión                                                                                                                                                                                                                            | Alternativa descartada                                                                         | Por qué                                                                                                                                                                                                                                        | Fecha      |
| :------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------- |
| **I-01** | **Proxy centralizado para APIs de terceros:** Todas las llamadas a servicios externos (ej. USDA FoodData Central) son realizadas exclusivamente por el backend NestJS; la app Flutter nunca contacta directamente a terceros.       | Consumir USDA FDC directamente desde Flutter utilizando la API key en la app móvil.            | Previene la extracción de llaves privadas mediante ingeniería inversa del binario móvil (principio S3), reduce el consumo de datos móviles mediante normalización de payloads y permite cambiar de proveedor sin actualizar la app en tiendas. | 2026-10-22 |
| **I-02** | **Gestión estricta de secretos en `.env`:** Ningún secreto, token o clave de API se versiona en Git. En el repositorio solo habita `.env.example` con valores de plantilla no funcionales.                                          | Incrustar credenciales de desarrollo o llaves de prueba públicas en el código fuente.          | Evita filtraciones de seguridad y garantiza portabilidad entre entornos locales, de staging y de producción.                                                                                                                                   | 2026-10-22 |
| **I-03** | **Almacenamiento de medios con abstracción desacoplada:** El manejo de fotos de progreso y comida se programa contra una interfaz `StorageService` implementando driver de disco local en el MVP, extensible a S3/R2 en producción. | Acoplar el código directamente a un SDK propietario como AWS S3 o Cloudinary desde el día uno. | Facilita el desarrollo y pruebas locales sin costos en la nube ni dependencias de internet en los tests de CI.                                                                                                                                 | 2026-10-22 |
| **I-04** | **Emulación de correo en desarrollo con Mailpit:** SMTP local para correos del producto (histórico de reset Nest). El reset de contraseña de Auth pasa a Firebase Auth.                                                             | Usar credenciales reales de Gmail / SendGrid en las máquinas de los desarrolladores.           | Elimina bloqueos por filtros antispam en flujos SMTP locales.                                                                                                                                                                                  | 2026-10-22 |
| **I-05** | **Identidad con Firebase Auth; dominio en PostgreSQL:** Flutter autentica con Firebase Auth (email/password). Nest verifica el ID token con `firebase-admin` y mapea `firebaseUid` a `User` en Prisma. Sin Firestore.               | Mantener JWT/Argon2 propios o migrar el dominio a Firestore.                                   | Separa identidad de datos relacionales (D-03); elimina doble sistema de sesión (decisión 1A AUTH-01).                                                                                                                                          | 2026-11-15 |
| **I-06** | La exportación y eliminación de cuenta operan en la API autenticada; la eliminación prepara archivos, elimina la identidad Firebase y aplica cascadas en PostgreSQL. | Tratar la eliminación como una operación exclusivamente local. | La identidad y los archivos están fuera de PostgreSQL y deben gestionarse junto con los registros. | 2026-11-16 |
| **I-07** | La cancelación prepara archivos, confirma la cascada PostgreSQL y después solicita el borrado en Firebase, fuera de la transacción. `GET /users/me/export` y `DELETE /users/me` son canónicos; las rutas `/privacy/:userId` correspondientes quedan obsoletas y conservan aislamiento 404. | Mantener una llamada de red dentro de la transacción SQL. | Evita retener locks durante I/O externo. Si Firebase falla tras el commit quedan datos e identidad desincronizados: los archivos se eliminan y la identidad residual requiere limpieza administrativa; no se restauran los datos ya borrados. Si falla SQL, se restauran los archivos y no se toca Firebase. | 2026-11-22 |
| **I-08** | Las notificaciones in-app usan `/api/v1/notifications` con Bearer, filtro por propietario y paginación `page`/`pageSize` (20 por defecto, máximo 100); tipos HTTP `new_login`, `password_changed`, `reminder` y `system`. | Exponer IDs ajenos o cargar el historial completo en una sola solicitud. | Preserva el aislamiento S4 y un contrato compatible con el cliente móvil. La app actual consume solo la primera página; requiere paginación adicional para mostrar el resto. | 2026-11-25 |
| **I-09** | Push con `firebase-admin` Messaging detrás de `PUSH_MESSAGING_CLIENT` (`admin`/`mock`/`disabled` con `FIREBASE_MESSAGING_MODE`; si no se define, hereda `FIREBASE_AUTH_MODE`). El despacho nunca rompe el flujo padre, aplica el gate `notificationsEnabled` solo a notificaciones que no son de seguridad y borra los tokens `not-registered`/`invalid`. | Llamar a FCM directo desde los servicios de eventos, o enviar push desde Flutter. | CI sin credenciales Google, un solo punto de logging seguro y tokens huérfanos limpiados en PostgreSQL. | 2026-11-24 |

---

## 3. Familias de integraciones y orden en el roadmap

| Orden | Familia             | Integración / Herramienta                   | Para qué se usa                                                                                          |   Fase del SOW   |
| :---: | :------------------ | :------------------------------------------ | :------------------------------------------------------------------------------------------------------- | :--------------: |
| **1** | **Base de Datos**   | PostgreSQL 16 + Prisma ORM                  | Almacenamiento persistente relacional de usuarios, sesiones, comidas y catálogo de ejercicios.           |      Fase 0      |
| **2** | **Autenticación**   | Firebase Auth + `firebase-admin`            | Identidad y sesión (ID token); Nest sincroniza `User` por `firebaseUid`.                                 | Fase 1 / AUTH-01 |
| **3** | **Correo Local**    | Nodemailer + Mailpit                        | Correos locales opcionales; el reset de contraseña lo envía Firebase.                                    |      Fase 1      |
| **4** | **Almacenamiento**  | `StorageService` (Disco local / `uploads/`) | Almacenamiento de fotos de progreso corporal y comidas capturadas por el usuario (P1).                   |     Fase 1–2     |
| **5** | **Media Estática**  | NestJS Serve-Static (`public/exercises/`)   | Entrega de 1324 imágenes JPG y 1324 GIFs animados de ejercicios Gym Visual bajo `/static/exercises/...`. |     Fase 2–3     |
| **6** | **API de Terceros** | USDA FoodData Central (FDC)                 | Búsqueda de catálogo nutricional público de alimentos y extracción de calorías y macronutrientes.        |      Fase 3      |

---

## 4. Detalle de integraciones críticas

### 4.1 USDA FoodData Central (FDC)

USDA FDC es la base de datos oficial del Departamento de Agricultura de los Estados Unidos que ofrece información nutricional de alimentos en formato abierto y gratuito.

- **Proveedor y documentación:** United States Department of Agriculture (`https://fdc.nal.usda.gov/api-guide.html`).
- **Endpoint consumido por el servidor:** `GET https://api.nal.usda.gov/fdc/v1/foods/search`.
- **Contrato hacia Flutter:** `GET /api/v1/foods/search?q={termino}` con Bearer JWT. Flutter no llama a USDA. Una respuesta 200 es un arreglo de hasta 20 alimentos `{ fdcId, description, name, servingG, kcal, proteinG, carbsG, fatG }` por 100 g (`brandOwner` solo si USDA lo trae). Cualquier otro estado abre captura manual.
- **Credencial requerida:** `USDA_FDC_API_KEY`, solo en el entorno del servidor (`fit_track_api/.env`, no versionado). `.env.example` documenta el nombre con valor vacío. La key viaja únicamente en la petición saliente del API. No se escribe en logs, en el cuerpo HTTP, en Swagger ni en el repositorio.
- **Flujo de integración:**
  1. La aplicación móvil solicita búsqueda mediante `GET /api/v1/foods/search?q={termino}` incluyendo Bearer token JWT.
  2. `FoodsModule` (`FoodsController`) valida `q` con el `ValidationPipe` global (`whitelist`, `forbidNonWhitelisted`). `q` vacío o de más de 120 caracteres responde 400.
  3. `UsdaFoodService` lee `USDA_FDC_API_KEY`. Si falta o está en blanco, no llama a USDA.
  4. `FetchUsdaHttpClient` (`fetch`, cliente inyectable) ejecuta la petición con timeout de abort de **5000 ms** y `pageSize=20`.
  5. La respuesta de USDA se normaliza por 100 g. Se prefiere el id de nutriente y, si no viene, el número legado:
     - `1008` / `208`: Energía / Calorías (`kcal`).
     - `1003` / `203`: Proteínas (`proteinG`).
     - `1004` / `204`: Grasas totales (`fatG`).
     - `1005` / `205`: Carbohidratos (`carbsG`).
  6. Se retorna al cliente Flutter un arreglo de `FoodItemDto`. Una búsqueda sin coincidencias es 200 con `[]`.
- **Degradación ante fallos:**
  - Timeout (>5 s), fallo de red, HTTP no exitoso de USDA (incluye 429 y 5xx) o key ausente: la API responde HTTP 503 `{ code: 'USDA_UNAVAILABLE', message: 'Servicio nutricional no disponible temporalmente' }`. Ese cuerpo no incluye la key ni la URL.
  - La aplicación móvil trata cualquier respuesta distinta de 200 como **Captura manual**: el usuario registra nombre, porción y macros sin salir del flujo.
- **Limitación documentada:** La base de datos de USDA contiene registros primordialmente en idioma inglés. La interfaz de usuario documenta este comportamiento y ofrece traducción de términos comunes en la guía de uso.

---

### 4.2 Catálogo Multimedia y Atribución Gym Visual

Para proveer guías visuales animadas de ejecución de ejercicios sin incurrir en costos de ancho de banda a plataformas externas ni exponer la aplicación a enlaces rotos, se incluye el catálogo de medios local.

- **Fuente y licencia:** Gym Visual (<https://gymvisual.com/>).
- **Ubicación en el repositorio:**
  - Miniaturas: `fit_track_api/public/exercises/images/` (1324 archivos `.jpg` de 180x180 px).
  - Animaciones: `fit_track_api/public/exercises/videos/` (1324 archivos `.gif` de 180x180 px).
  - Archivo de aviso de licencia: `fit_track_api/public/exercises/NOTICE.md`.
- **Entrega estática:**
  - El servidor NestJS expone las carpetas mediante `@nestjs/serve-static` bajo las rutas públicas:
    - `/static/exercises/images/{imageFile}`
    - `/static/exercises/videos/{gifFile}`
  - Los archivos se empaquetan en la imagen de Docker en modo solo lectura (`RO`).
- **Términos de uso y atribución obligatoria:**
  - La licencia no comercial exige mostrar explícitamente el origen del material.
  - En la vista de detalle de cada ejercicio (`ExerciseDetailPage` en Flutter), se muestra de forma visible e inalterable la leyenda:
    > **© Gym visual — https://gymvisual.com/**
  - La resolución se mantiene estrictamente en 180x180 px para cumplir con los lineamientos de distribución gratuita del titular de los derechos.

---

### 4.3 Servicio de Correo Transaccional (Nodemailer y Mailpit)

- **Propósito:** Envío de códigos numéricos de 6 dígitos para recuperación y reseteo de contraseñas olvidadas (`POST /api/v1/auth/password/forgot`).
- **Variables de configuración:**
  ```env
  SMTP_HOST=127.0.0.1
  SMTP_PORT=1025
  SMTP_SECURE=false
  SMTP_USER=
  SMTP_PASS=
  SMTP_FROM=no-reply@fittrack360.local
  ```
- **Comportamiento seguro (Privacidad de usuario):**
  - La API siempre responde HTTP 200 `{ message: 'Si el correo existe, se ha enviado un código' }`, independientemente de si el correo está registrado en la base de datos o si el servidor SMTP está temporalmente inaccesible. Esto mitiga ataques de enumeración de usuarios.
  - El código de verificación generado se almacena en PostgreSQL hasheado con un tiempo de expiración de 15 minutos (`PasswordResetCode.expiresAt`).


### 4.4 Notificaciones in-app

Todas las rutas requieren Bearer y usan el usuario autenticado. `GET /api/v1/notifications` acepta `isRead`, `type`, `page` y `pageSize` y devuelve `{ items, total, page, pageSize }`, ordenado por fecha descendente. `GET /unread-count` devuelve `{ count }`. `GET /:id` obtiene un aviso propio; `PATCH /:id/read` recibe `{ isRead: boolean }`; `PATCH /read-all` marca los pendientes y devuelve `{ count }`. `DELETE /:id` responde 204 y `DELETE /` devuelve `{ count }`; las operaciones masivas son idempotentes. Un ID ajeno o inexistente responde 404. La aplicación actual aún no solicita páginas adicionales y representa el tipo `system` como recordatorio hasta ampliar su enum de presentación. El parámetro `page` admite hasta 1000000.
