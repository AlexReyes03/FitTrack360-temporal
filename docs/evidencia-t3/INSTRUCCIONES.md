# Evidencias Nivelación T3

Capturas auténticas generadas con el widget real `ListaTresEstadosPage`
(`RepaintBoundary.toImage` vía `captura_evidencia_t3_test.dart`).

| Archivo | Estado |
|---------|--------|
| `01-cargando.png` | Cargando (`CircularProgressIndicator`) |
| `02-error-reintentar.png` | Error legible + botón **Reintentar** |
| `03-lista-exito.png` | Lista de `Card` (≥5 comidas) |

## Cómo regenerar

```bat
cd fit_track_360
flutter test test/features/nivelacion_t3/captura_evidencia_t3_test.dart
```

## Demo en Chrome

```bat
flutter run -d chrome -t lib/main_t3_demo.dart
```

En la app completa (tras login o sin sesión): ruta `/app/nivelacion-t3`
o botón **Nivelacion T3** en el Home.
