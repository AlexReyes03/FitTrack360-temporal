# INTEGRACIONES · Servicios Externos y APIs · FitTrack360

## 1. Propósito

Este documento describe los servicios externos, APIs de terceros y mecanismos de integración del ecosistema FitTrack360. Define el orden de incorporación de cada servicio, los protocolos de seguridad para resguardo de credenciales y la arquitectura de tolerancia a fallos ante caídas o degradación de proveedores externos.

---

## 2. Tabla de decisiones de integración

| # | Decisión | Alternativa descartada | Por qué | Fecha |
| :--- | :--- | :--- | :--- | :--- |
| **I-01** | **Proxy centralizado para APIs de terceros:** Todas las llamadas a servicios externos (ej. USDA FoodData Central) son realizadas exclusivamente por el backend NestJS; la app Flutter nunca contacta directamente a terceros. | Consumir USDA FDC directamente desde Flutter utilizando la API key en la app móvil. | Previene la extracción de llaves privadas mediante ingeniería inversa del binario móvil (principio S3), reduce el consumo de datos móviles mediante normalización de payloads y permite cambiar de proveedor sin actualizar la app en tiendas. | 2026-10-22 |
| **I-02** | **Gestión estricta de secretos en `.env`:** Ningún secreto, token o clave de API se versiona en Git. En el repositorio solo habita `.env.example` con valores de plantilla no funcionales. | Incrustar credenciales de desarrollo o llaves de prueba públicas en el código fuente. | Evita filtraciones de seguridad y garantiza portabilidad entre entornos locales, de staging y de producción. | 2026-10-22 |
| **I-03** | **Almacenamiento de medios con abstracción desacoplada:** El manejo de fotos de progreso y comida se programa contra una interfaz `StorageService` implementando driver de disco local en el MVP, extensible a S3/R2 en producción. | Acoplar el código directamente a un SDK propietario como AWS S3 o Cloudinary desde el día uno. | Facilita el desarrollo y pruebas locales sin costos en la nube ni dependencias de internet en los tests de CI. | 2026-10-22 |
| **I-04** | **Emulación de correo en desarrollo con Mailpit:** El envío de códigos de restablecimiento de contraseña utiliza SMTP local capturado por Mailpit en Docker. | Usar credenciales reales de Gmail / SendGrid en las máquinas de los desarrolladores. | Elimina bloqueos por filtros antispam, evita costos de consumo y permite inspeccionar correos visualmente en `http://localhost:8025` durante pruebas. | 2026-10-22 |

---

## 3. Familias de integraciones y orden en el roadmap

| Orden | Familia | Integración / Herramienta | Para qué se usa | Fase del SOW |
| :---: | :--- | :--- | :--- | :---: |
| **1** | **Base de Datos** | PostgreSQL 16 + Prisma ORM | Almacenamiento persistente relacional de usuarios, sesiones, comidas y catálogo de ejercicios. | Fase 0 |
| **2** | **Autenticación** | JWT (jsonwebtoken) + Argon2id (`@node-rs/argon2`) | Emisión y verificación de tokens de acceso (15 min) y refresco (7 días); cifrado robusto de contraseñas. | Fase 1 |
| **3** | **Correo Local** | Nodemailer + Mailpit | Envío y visualización de correos de recuperación de contraseña con código de un solo uso de 6 dígitos. | Fase 1 |
| **4** | **Almacenamiento** | `StorageService` (Disco local / `uploads/`) | Almacenamiento de fotos de progreso corporal y comidas capturadas por el usuario (P1). | Fase 1–2 |
| **5** | **Media Estática** | NestJS Serve-Static (`public/exercises/`) | Entrega de 1324 imágenes JPG y 1324 GIFs animados de ejercicios Gym Visual bajo `/static/exercises/...`. | Fase 2–3 |
| **6** | **API de Terceros** | USDA FoodData Central (FDC) | Búsqueda de catálogo nutricional público de alimentos y extracción de calorías y macronutrientes. | Fase 3 |

---

## 4. Detalle de integraciones críticas

### 4.1 USDA FoodData Central (FDC)

USDA FDC es la base de datos oficial del Departamento de Agricultura de los Estados Unidos que ofrece información nutricional de alimentos en formato abierto y gratuito.

- **Proveedor y documentación:** United States Department of Agriculture (`https://fdc.nal.usda.gov/api-guide.html`).
- **Endpoint consumido:** `GET https://api.nal.usda.gov/fdc/v1/foods/search`.
- **Credencial requerida:** `USDA_FDC_API_KEY`, configurada únicamente en `fit_track_api/.env`.
- **Flujo de integración:**
  1. La aplicación móvil solicita búsqueda mediante `GET /api/v1/foods/search?q={termino}` incluyendo Bearer token JWT.
  2. El módulo `MealsModule` de NestJS recibe la petición y delega a `UsdaFoodService`.
  3. `UsdaFoodService` ejecuta una petición HTTP con Axios aplicando un timeout estricto de **5000 ms**.
  4. La respuesta de USDA se normaliza extrayendo únicamente los identificadores de nutrientes requeridos:
     - `Nutrient ID 1008`: Energía / Calorías (`kcal`).
     - `Nutrient ID 1003`: Proteínas (`proteinG`).
     - `Nutrient ID 1004`: Grasas totales (`fatG`).
     - `Nutrient ID 1005`: Carbohidratos disponibles (`carbsG`).
  5. Se retorna al cliente Flutter una lista simplificada de DTOs (`FoodItemDto`).
- **Degradación ante fallos:**
  - Si la llamada a USDA arroja timeout (>5 s), error 500 o límite de cuota (HTTP 429), la API devuelve un error tipado `{ code: 'USDA_UNAVAILABLE', message: 'Servicio nutricional no disponible temporalmente' }`.
  - La aplicación móvil captura este estado y despliega inmediatamente la opción de **Captura manual**, donde el usuario puede registrar su alimento digitando los macros sin perder su flujo de alimentación.
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
