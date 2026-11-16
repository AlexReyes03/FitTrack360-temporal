# Declaración de uso de IA — Nivelación T3

**Estudiante:** Martín Antonio Joaquín Landa  
**Matrícula:** I20233tn170  
**Grupo:** 10.º C  
**Herramienta:** Cursor (agente Composer / Auto)  
**Nivel de política:** 2 (IA como herramienta declarada)

## Prompts principales

1. Revisar la consigna `nivelacion-t3-lista-tres-estados` y el repo FitTrack360-temporal.
2. Planificar entrega completa (código, evidencias, `ia-t3.md`, DOCX, commits).
3. Ejecutar el plan en la rama `feat/lista-tres-estados` sin push/PR.

## Qué se aceptó

- Feature aislada `nivelacion_t3/` con entidad `ComidaDemo` (dominio comidas).
- Clase sellada `Resultado<T>` (`Cargando`, `Exito`, `Error`) en `lib/core/resultado.dart`.
- Repositorio falso que falla la 1.ª llamada y entrega ≥5 ítems en la 2.ª.
- Pantalla `StatefulWidget` con `setState`, `switch` exhaustivo y `mounted`.
- Ruta `/app/nivelacion-t3` y botón visible en el shell.
- Corrección mínima de sintaxis en `router.dart` y `home_shell_page.dart` (rutas/botones mal fusionados en `main`, que impedían compilar).

## Qué se modificó respecto a la sugerencia inicial

- No se reutilizó `AsyncState` ni se refactorizó `MealsPage` (la consigna pide `Resultado` + `setState`).
- Entidad demo propia en lugar de acoplar `MealEntry`/HTTP.
- Autoinjectable de repositorio opcional en la página para facilitar tests widget.

## Qué se rechazó

- Firmar commits como Daniela / `@danielita05`.
- Reemplazar pantallas productivas que ya usan `AsyncState`.
- Inventar capturas PNG o resultados de `flutter analyze`/`flutter test` sin ejecutarlos.
- Push, merge o apertura de PR.

## Pruebas realmente ejecutadas

| Prueba | Resultado |
|--------|-----------|
| Creación de rama y 3+ commits locales | Sí (ver `git log` en `feat/lista-tres-estados`) |
| `flutter pub get` / `flutter analyze` / `flutter test` / `flutter run` | **No ejecutados:** el SDK configurado (`C:\src\flutter`) no existe en esta máquina |
| Capturas de los tres estados | **Pendientes** (ver `docs/evidencia-t3/INSTRUCCIONES.md`) |
| Revisión estática del código T3 en el editor | Sí (archivos creados y cableados) |

## Bloques marcados con `// IA:`

- `fit_track_360/lib/features/nivelacion_t3/presentation/lista_tres_estados_page.dart` — comentario sobre la estructura de pantalla generada/ajustada con asistencia.

El estudiante es responsable de explicar en defensa oral: `Resultado`, el `switch` sin `default`, el ciclo `setState` → `build`, y el uso de `mounted` tras `await`.
