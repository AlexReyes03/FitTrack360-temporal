# home

Aqui va el resumen del dia: workout, macros y pasos (data/domain/presentation).

## Decisiones (UX-13, #233)

- **Recarga al volver a Inicio.** `StatefulShellRoute` conserva el estado de
  cada rama, así que `AppShellPage` publica la pestaña activa con
  `AppShellTabScope`. Cuando el usuario vuelve a Inicio desde otra pestaña,
  `HomeShellPage` llama a `HomeDashboardViewModel.refresh()` y actualiza el
  saludo. También hay `RefreshIndicator` (color `AppColors.accentWhite`, fondo
  `AppColors.bgMid`).
- **`refresh()` frente a `load()`.** `refresh()` deja a la vista los bloques con
  datos o vacíos mientras llega la respuesta (sin esqueletos que parpadeen);
  un bloque en error sí vuelve a cargar. `load()` sigue reiniciando todo.
- **Refrescar no sincroniza FCM.** Solo la carga inicial sincroniza el token;
  el ciclo de vida de notificaciones lo controla Perfil.
- **Estados vacíos con acción.** `DashboardBlockShell` acepta
  `emptyActionLabel`/`onEmptyAction` (mismo criterio que `RemoteEmptyView`: el
  botón aparece solo con etiqueta y callback). Nutrición → Comidas, Sesión →
  Entrenos, Métrica → Progreso.
- **Accesos rápidos sin palabras partidas.** Las etiquetas son cortas
  («Entrenar», «Comida», «Foto progreso»). Si la palabra más larga no cabe
  entera en la columna (pantallas estrechas o texto grande), el bloque pasa
  de cuadrícula de tres columnas a una fila por acceso.
