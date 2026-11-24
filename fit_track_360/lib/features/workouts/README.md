# workouts

Sesiones de entrenamiento, tracker en vivo e historial (data/domain/presentation).

## Flujo único (#228)

- **Entrenar ahora → tracker** (`/app/tracker`, `TrackerSessionPage`). Se llega
  desde la pestaña Entrenamientos, la tarjeta «Entrenar ahora» de Inicio, el
  detalle de una rutina (`StartSessionButton`) y «Repetir entrenamiento» en el
  detalle de una sesión. `TrackerSessionArgs` lleva un `draft` (rutina o
  sesión repetida, varios ejercicios) o un `exercise` del catálogo. Sin
  argumentos el tracker pide elegir un ejercicio; ya no toma el primero del
  catálogo.
- **Registrar entrenamiento pasado → formulario** (`WorkoutFormPage`, botón
  «Nuevo» del historial). Pide inicio y duración y guarda la sesión
  finalizada (`endedAt = inicio + duración`). El mismo formulario edita una
  sesión.
- El tracker solo persiste la sesión al finalizar, así que ninguna sesión del
  API está «en curso»: Inicio nunca ofrece «Continuar entrenamiento» y una
  sesión antigua sin `endedAt` muestra «Duración: Sin registrar».

## Decisiones

- Lógica en ViewModels: `TrackerViewModel` (ahora con varios ejercicios),
  `WorkoutFormViewModel`, `SessionEditorViewModel` y
  `ExercisePickerViewModel`.
- Validación por campo: cada campo guarda el texto tal cual y muestra su
  error; no se convierte a 0 o -1. Los errores aparecen al tocar el campo o al
  intentar guardar.
- El descanso del perfil solo se aplica si la persona no editó el campo.
- El selector de ejercicios es una hoja glass con búsqueda (espera de 350 ms)
  y carga incremental al llegar al final de la lista.
- Etiquetas e imagen del ejercicio en el tracker usan `exercise_labels.dart` y
  `ExerciseMediaView` del catálogo.
- `PopScope` con «¿Descartar cambios?» en el formulario y «¿Descartar la
  sesión?» en el tracker activo, también con el gesto de volver del sistema.

## Pendiente de migrar al DS (#222)

- `WorkoutNumberField` y `WorkoutStepperField` (`DsTextField` aún no acepta
  `inputFormatters`).
- `showWorkoutConfirmDialog` (diálogo glass con acción destructiva).
- `showExercisePickerSheet` (hoja glass).
- `TrackerGlassButton`, `TrackerIconControl` y `TrackerTagChip`.
