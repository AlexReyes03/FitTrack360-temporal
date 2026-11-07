import { Controller, Get, INestApplication, Module } from '@nestjs/common';
import type { DynamicModule } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request, { Response } from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/app.setup';
import {
  EXERCISE_IMAGES_ROUTE,
  EXERCISE_VIDEOS_ROUTE,
  ExerciseMediaModule,
  defaultPublicDir,
} from '../../src/static/exercise-media.module';

// Jest corre con cwd = fit_track_api, igual que `pnpm start:dev`.
const REAL_PUBLIC_DIR = join(process.cwd(), 'public');
const SAMPLE_IMAGE = '0001-2gPfomN.jpg';
const SAMPLE_GIF = '0001-2gPfomN.gif';
const ONE_WEEK_SECONDS = 7 * 24 * 60 * 60;

/**
 * Supertest acumula el cuerpo binario en un Buffer; sin este parser los
 * image/* llegarian como objeto vacio y no se podrian comparar en bytes.
 */
function binaryParser(
  res: Response,
  callback: (err: Error | null, body: Buffer) => void,
): void {
  // En Node, superagent entrega aqui el IncomingMessage (un stream legible).
  const stream = res as unknown as NodeJS.ReadableStream;
  const chunks: Buffer[] = [];
  stream.on('data', (chunk: Buffer) => chunks.push(Buffer.from(chunk)));
  stream.on('end', () => callback(null, Buffer.concat(chunks)));
}

@Controller('probes')
class ProbeController {
  @Get()
  list(): string[] {
    return ['ok'];
  }
}

/**
 * App minima (sin Postgres) con la misma config HTTP y el modulo de media.
 * Se arranca con NestFactory, como main.ts: con Test.createTestingModule los
 * providers se crean antes que el adaptador HTTP y ServeStaticModule elige su
 * loader no-op, asi que la prueba no reflejaria produccion.
 */
async function bootstrapMediaApp(
  publicDir: string,
): Promise<INestApplication<App>> {
  @Module({
    imports: [ExerciseMediaModule.register(publicDir)],
    controllers: [ProbeController],
  })
  class MediaProbeModule {}

  const app = await NestFactory.create<INestApplication<App>>(
    MediaProbeModule,
    { logger: false },
  );
  configureApp(app);
  await app.init();
  return app;
}

describe('ExerciseMediaModule (W8-10)', () => {
  it('expone las rutas del plan, fuera de /api/v1', () => {
    expect(EXERCISE_IMAGES_ROUTE).toBe('/static/exercises/images');
    expect(EXERCISE_VIDEOS_ROUTE).toBe('/static/exercises/videos');
  });

  it('usa por defecto <cwd>/public como directorio base', () => {
    expect(defaultPublicDir()).toBe(REAL_PUBLIC_DIR);
  });

  it('queda registrado en AppModule', () => {
    const imports = Reflect.getMetadata('imports', AppModule) as unknown[];
    const registered = imports.some(
      (entry) =>
        typeof entry === 'object' &&
        entry !== null &&
        (entry as DynamicModule).module === ExerciseMediaModule,
    );
    expect(registered).toBe(true);
  });

  describe('con la media versionada en public/', () => {
    let app: INestApplication<App>;

    beforeAll(async () => {
      app = await bootstrapMediaApp(REAL_PUBLIC_DIR);
    });

    afterAll(async () => {
      await app.close();
    });

    it('sirve el JPG de ejemplo como image/jpeg, byte a byte', async () => {
      const response = await request(app.getHttpServer())
        .get(`/static/exercises/images/${SAMPLE_IMAGE}`)
        .buffer(true)
        .parse(binaryParser)
        .expect(200);

      expect(response.headers['content-type']).toBe('image/jpeg');
      const expected = readFileSync(
        join(REAL_PUBLIC_DIR, 'exercises', 'images', SAMPLE_IMAGE),
      );
      expect(Buffer.compare(response.body as Buffer, expected)).toBe(0);
    });

    it('sirve el GIF de ejemplo como image/gif, byte a byte', async () => {
      const response = await request(app.getHttpServer())
        .get(`/static/exercises/videos/${SAMPLE_GIF}`)
        .buffer(true)
        .parse(binaryParser)
        .expect(200);

      expect(response.headers['content-type']).toBe('image/gif');
      const expected = readFileSync(
        join(REAL_PUBLIC_DIR, 'exercises', 'videos', SAMPLE_GIF),
      );
      expect(Buffer.compare(response.body as Buffer, expected)).toBe(0);
    });

    it('marca la media como cacheable al menos 7 dias', async () => {
      const response = await request(app.getHttpServer())
        .get(`/static/exercises/images/${SAMPLE_IMAGE}`)
        .expect(200);

      const cacheControl = response.headers['cache-control'] ?? '';
      const maxAge = Number(/max-age=(\d+)/.exec(cacheControl)?.[1]);
      expect(cacheControl).toContain('public');
      expect(maxAge).toBeGreaterThanOrEqual(ONE_WEEK_SECONDS);
    });

    it('responde 404 a un archivo inexistente', async () => {
      await request(app.getHttpServer())
        .get('/static/exercises/images/no-existe.jpg')
        .expect(404);
      await request(app.getHttpServer())
        .get('/static/exercises/videos/no-existe.gif')
        .expect(404);
    });

    it.each([
      '/static/exercises/images/',
      '/static/exercises/images',
      '/static/exercises/videos/',
      '/static/exercises/',
      '/static/exercises',
      '/static/',
    ])('no lista directorios: %s -> 404', async (path) => {
      await request(app.getHttpServer()).get(path).redirects(0).expect(404);
    });

    it.each([
      '/static/exercises/NOTICE.md',
      '/static/exercises/README.md',
      '/static/NOTICE.md',
      '/static/exercises/exercises/NOTICE.md',
    ])(
      'no sirve archivos fuera de images/ y videos/: %s -> 404',
      async (path) => {
        await request(app.getHttpServer()).get(path).expect(404);
      },
    );

    it.each([
      '/static/exercises/images/..%2fNOTICE.md',
      '/static/exercises/images/..%2f..%2f..%2fpackage.json',
      '/static/exercises/images/%2e%2e/%2e%2e/%2e%2e/package.json',
      '/static/exercises/videos/..%5c..%5c..%5cpackage.json',
      '/static/exercises/images/....//....//package.json',
    ])('bloquea path traversal: %s', async (path) => {
      const response = await request(app.getHttpServer()).get(path);

      expect(response.status).not.toBe(200);
      expect(response.text ?? '').not.toContain('fit_track_api');
      expect(response.text ?? '').not.toContain('Gym visual');
    });

    it('no interfiere con el API bajo /api/v1', async () => {
      await request(app.getHttpServer()).get('/api/v1/probes').expect(200);
    });

    it('no interfiere con Swagger en /api/docs', async () => {
      await request(app.getHttpServer()).get('/api/docs-json').expect(200);
      await request(app.getHttpServer())
        .get('/api/docs')
        .redirects(1)
        .expect(200);
    });

    it('no monta la media bajo /api/v1', async () => {
      await request(app.getHttpServer())
        .get(`/api/v1/static/exercises/images/${SAMPLE_IMAGE}`)
        .expect(404);
    });
  });

  describe('con un directorio base inyectado', () => {
    let app: INestApplication<App>;
    let publicDir: string;

    beforeAll(async () => {
      publicDir = mkdtempSync(join(tmpdir(), 'fittrack-media-'));
      mkdirSync(join(publicDir, 'exercises', 'images'), { recursive: true });
      mkdirSync(join(publicDir, 'exercises', 'videos'), { recursive: true });
      writeFileSync(join(publicDir, 'exercises', 'images', 'probe.jpg'), 'jpg');
      writeFileSync(join(publicDir, 'exercises', 'videos', 'probe.gif'), 'gif');
      writeFileSync(join(publicDir, 'exercises', 'images', '.secret'), 'x');
      writeFileSync(join(publicDir, 'exercises', 'images', 'index.html'), 'x');
      writeFileSync(join(publicDir, 'secret.txt'), 'x');
      app = await bootstrapMediaApp(publicDir);
    });

    afterAll(async () => {
      await app.close();
      rmSync(publicDir, { recursive: true, force: true });
    });

    it('sirve desde el directorio indicado', async () => {
      await request(app.getHttpServer())
        .get('/static/exercises/images/probe.jpg')
        .expect(200);
      await request(app.getHttpServer())
        .get('/static/exercises/videos/probe.gif')
        .expect(200);
    });

    it('ignora dotfiles', async () => {
      await request(app.getHttpServer())
        .get('/static/exercises/images/.secret')
        .expect(404);
    });

    it('no responde el index.html de un directorio', async () => {
      await request(app.getHttpServer())
        .get('/static/exercises/images/')
        .redirects(0)
        .expect(404);
    });

    it('no expone el resto del directorio base', async () => {
      await request(app.getHttpServer()).get('/static/secret.txt').expect(404);
      await request(app.getHttpServer()).get('/secret.txt').expect(404);
    });
  });
});
