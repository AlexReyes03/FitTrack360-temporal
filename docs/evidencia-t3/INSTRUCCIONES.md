# Evidencias Nivelación T3

En el entorno de generación de esta entrega **no estaba disponible el SDK de Flutter**
(`flutter.sdk=C:\src\flutter` en `android/local.properties`, pero esa ruta no existe).
Por eso **no se generaron capturas PNG reales** desde esta sesión.

## Cómo obtener las evidencias

1. Instala o restaura Flutter y apunta `flutter.sdk` a la ruta correcta.
2. En `fit_track_360/`:
   - `flutter pub get`
   - `flutter run` (emulador o dispositivo)
3. Inicia sesión y en el Home pulsa **Nivelacion T3**.
4. Captura:
   - `01-cargando.png` — spinner durante los ~2 s de la primera carga (o al pulsar Reintentar).
   - `02-error-reintentar.png` — mensaje en español + botón **Reintentar** (primera llamada).
   - `03-lista-exito.png` — lista de tarjetas con ≥5 comidas tras reintentar.

Guarda los tres PNG en este mismo directorio (`docs/evidencia-t3/`).
