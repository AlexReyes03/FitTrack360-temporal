import { DynamicModule, Module } from '@nestjs/common';
import {
  ServeStaticModule,
  ServeStaticModuleOptions,
} from '@nestjs/serve-static';
import { join } from 'node:path';

/** URL pública de las miniaturas 180x180 (JPG) de ejercicios. */
export const EXERCISE_IMAGES_ROUTE = '/static/exercises/images';

/** URL pública de las animaciones 180x180 (GIF) de ejercicios. */
export const EXERCISE_VIDEOS_ROUTE = '/static/exercises/videos';

/** La media es inmutable (el nombre incluye el id), así que se cachea 7 días. */
const MEDIA_MAX_AGE = '7d';

/**
 * Directorio base de la media: `<cwd>/public`. Con `pnpm start:dev` el cwd es
 * fit_track_api y en Docker es /app, así que en ambos casos apunta a public/.
 */
export function defaultPublicDir(): string {
  return join(process.cwd(), 'public');
}

function mediaFolder(
  rootPath: string,
  serveRoot: string,
): ServeStaticModuleOptions {
  return {
    rootPath,
    serveRoot,
    // Sin fallback SPA: ServeStatic respondería el index.html de rootPath para
    // cualquier ruta bajo serveRoot. Excluir todo deja que lo inexistente
    // termine en el 404 normal de Nest.
    exclude: /.*/,
    serveStaticOptions: {
      index: false,
      redirect: false,
      dotfiles: 'ignore',
      fallthrough: true,
      maxAge: MEDIA_MAX_AGE,
      immutable: true,
    },
  };
}

/**
 * Sirve solo `exercises/images` y `exercises/videos` (no NOTICE.md, README.md
 * ni el resto de public/) fuera del prefijo /api/v1, en modo solo lectura.
 */
@Module({})
export class ExerciseMediaModule {
  static register(publicDir: string = defaultPublicDir()): DynamicModule {
    const exercisesDir = join(publicDir, 'exercises');
    return {
      module: ExerciseMediaModule,
      imports: [
        ServeStaticModule.forRoot(
          mediaFolder(join(exercisesDir, 'images'), EXERCISE_IMAGES_ROUTE),
          mediaFolder(join(exercisesDir, 'videos'), EXERCISE_VIDEOS_ROUTE),
        ),
      ],
    };
  }
}
