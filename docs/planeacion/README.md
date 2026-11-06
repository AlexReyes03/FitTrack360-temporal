# Planeación de FitTrack360

Este directorio centraliza la documentación de planeación de FitTrack360, incluyendo el caso de estudio, la estrategia de versionamiento y la arquitectura de alto nivel. Su contenido sirve como referencia para el desarrollo y seguimiento del proyecto, así como para las evidencias correspondientes a la Unidad I.

## Índice

- [Caso de estudio](#caso-de-estudio)
- [Versionamiento](#versionamiento)
- [Arquitectura de alto nivel](#arquitectura-de-alto-nivel)
- [Plan maestro](#plan-maestro)
- [Planeación de la semana W9](#planeación-de-la-semana-w9)

## Caso de estudio

FitTrack360 atiende una necesidad concreta: que una persona que entrena y cuida su alimentación tenga en un solo lugar el registro de sus sesiones, el control de calorías y macros, y la consulta de la técnica de cada ejercicio con apoyo visual, sin sustituir la atención médica o nutricional. La solución propuesta es una aplicación Flutter acompañada de una API NestJS, organizada en tres pilares de MVP: entrenamientos, alimentación y guía de ejercicios. El alcance, las fases y la trazabilidad se mantienen en el plan maestro.

## Versionamiento

El proyecto se trabaja con Git y pnpm sobre un monorepo. Los cambios se desarrollan en una rama distinta de `main` / `master` (`feat/...`, `fix/...`, `docs/...`, `chore/...`, entre otras) y se integran mediante Pull Request hacia `main`; se recomienda Squash and merge. Los mensajes de commit siguen el formato `<type>(<scope>): <mensaje>` con los tipos permitidos por el repositorio. Los hooks de Husky bloquean commits y pushes directos a las ramas protegidas, y validan formato, lint, tipos y mensaje de commit. No se deben omitir los hooks con `--no-verify`.

## Arquitectura de alto nivel

El repositorio es un monorepo gestionado con pnpm que contiene dos proyectos:

- `fit_track_360`: aplicación cliente en Flutter (Dart). En el estado versionado actual incluye el arranque de la app, el almacenamiento de sesión y las pantallas de inicio de sesión y registro.
- `fit_track_api`: API en NestJS (TypeScript) con prefijo global `/api/v1` y documentación Swagger en `/api/docs`. Persiste en PostgreSQL mediante Prisma e incluye el módulo de autenticación.

El cliente consume la API por HTTP. La arquitectura objetivo completa (módulos de entrenamientos, alimentación y catálogo de ejercicios, entre otros) se describe en el plan maestro; no debe confundirse con lo ya implementado, que en el estado actual se limita a los módulos versionados en `fit_track_api/src/`.

## Plan maestro

El plan maestro versionado está en [`../plans/plan-maestro-fittrack360.md`](../plans/plan-maestro-fittrack360.md). Define dominio, modelo de datos, arquitectura objetivo, fases, epics y trazabilidad; es la referencia para derivar tareas del tablero Scrumban.

## Planeación de la semana W9

El lote W9 (#47–#64) se detalla en [`semana-w9.md`](semana-w9.md): objetivo, tareas y responsables, dependencias, riesgos y seguimiento del cierre de F1 y del arranque de F2/P1.
