import { Body, Controller, Get, INestApplication, Post } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { IsInt, IsString, Min } from 'class-validator';
import request from 'supertest';
import { App } from 'supertest/types';
import { API_DOCS_PATH, configureApp } from '../../src/app.setup';

class CreateProbeDto {
  @IsString()
  name: string;

  @IsInt()
  @Min(1)
  reps: number;
}

@Controller('probes')
class ProbeController {
  @Get()
  list(): string[] {
    return ['ok'];
  }

  @Post()
  create(@Body() dto: CreateProbeDto): { isDto: boolean; reps: number } {
    return { isDto: dto instanceof CreateProbeDto, reps: dto.reps };
  }
}

/** Levanta una app minima con la misma configuracion que main.ts; sin Postgres. */
async function bootstrapProbeApp(): Promise<INestApplication<App>> {
  const moduleRef = await Test.createTestingModule({
    controllers: [ProbeController],
  }).compile();
  const app = moduleRef.createNestApplication<INestApplication<App>>();
  configureApp(app);
  await app.init();
  return app;
}

describe('configureApp (W8-08)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    app = await bootstrapProbeApp();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('prefijo de versión', () => {
    it('monta los controllers de negocio bajo /api/v1', async () => {
      await request(app.getHttpServer()).get('/api/v1/probes').expect(200);
    });

    it('no responde la ruta sin prefijo', async () => {
      await request(app.getHttpServer()).get('/probes').expect(404);
    });
  });

  describe('ValidationPipe global', () => {
    it('rechaza con 400 un payload que no cumple el DTO', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/probes')
        .send({ name: 'sentadilla', reps: 0 })
        .expect(400);
    });

    it('rechaza con 400 campos que el DTO no declara (forbidNonWhitelisted)', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/probes')
        .send({ name: 'sentadilla', reps: 10, isAdmin: true })
        .expect(400);

      expect(JSON.stringify(response.body)).toContain('isAdmin');
    });

    it('entrega al controller una instancia del DTO (transform)', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/probes')
        .send({ name: 'sentadilla', reps: 10 })
        .expect(201);

      expect(response.body).toEqual({ isDto: true, reps: 10 });
    });
  });

  describe('Swagger', () => {
    it('publica la UI en /api/docs, fuera del prefijo', async () => {
      expect(API_DOCS_PATH).toBe('api/docs');

      const response = await request(app.getHttpServer())
        .get('/api/docs')
        .redirects(1)
        .expect(200);

      expect(response.headers['content-type']).toContain('text/html');
      expect(response.text).toContain('swagger');
    });

    it('expone el contrato OpenAPI con el título y el prefijo correctos', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/docs-json')
        .expect(200);

      expect(response.body.info.title).toBe('FitTrack360 API');
      expect(Object.keys(response.body.paths)).toContain('/api/v1/probes');
    });

    it('no queda montado bajo /api/v1/api/docs', async () => {
      await request(app.getHttpServer()).get('/api/v1/api/docs').expect(404);
    });
  });
});
