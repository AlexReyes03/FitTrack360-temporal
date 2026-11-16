# Evidencias Nivelación T3

Capturas **reales desde Chrome** (`flutter run -d chrome -t lib/main.dart`),
ruta `/#/app/nivelacion-t3`. Texto legible (no `toImage` de tests: ese método
fallaba al cargar fuentes y producía rectángulos negros).

| Archivo | Estado |
|---------|--------|
| `01-cargando.png` | Título + `CircularProgressIndicator` |
| `02-error-reintentar.png` | Mensaje en español + botón **Reintentar** |
| `03-lista-exito.png` | Lista de 6 comidas (nombre, tipo, kcal) |

## Regenerar

1. `flutter run -d chrome -t lib/main.dart --web-port=7357`
2. Abrir `http://localhost:7357/#/app/nivelacion-t3` (hash routing)
3. Capturar Cargando → Error → Reintentar → Éxito
4. Opcional: `python docs/evidencia-t3/_capture_chrome.py`

## Navegación en la app

- Botón **Nivelacion T3** en el Home (tras sesión).
- URL directa sin sesión (demo/defensa): `/#/app/nivelacion-t3`
