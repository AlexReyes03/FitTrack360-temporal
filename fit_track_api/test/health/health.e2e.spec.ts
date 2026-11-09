import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { configureApp } from '../../src/app.setup';
import { DatabaseProbe } from '../../src/health/database.probe';
import { HealthModule } from '../../src/health/health.module';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

/** Sonda falsa con respuesta fija; sustituye a Prisma para no requerir Postgres. */
class StaticDatabaseProbe extends DatabaseProbe {
  constructor(private readonly up: boolean) {
    super();
  }

  isUp(): Promise<boolean> {
    return Promise.resolve(this.up);
  }
}

/** App mínima con HealthModule y la misma configuración HTTP que main.ts. */
async function bootstrapHealthApp(
  probe: DatabaseProbe,
): Promise<INestApplication<App>> {
  const moduleRef = await Test.createTestingModule({
    imports: [HealthModule],
  })
    .overrideProvider(DatabaseProbe)
    .useValue(probe)
    .compile();
  const app = moduleRef.createNestApplication<INestApplication<App>>();
  configureApp(app);
  await app.init();
  return app;
}

describe('Health y request-id (W8-09)', () => {
  describe('con la base de datos disponible', () => {
    let app: INestApplication<App>;

    beforeAll(async () => {
      app = await bootstrapHealthApp(new StaticDatabaseProbe(true));
    });

    afterAll(async () => {
      await app.close();
    });

    it('GET /api/v1/health responde 200 con status ok y db up', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/health')
        .expect(200);

      expect(response.body).toEqual({ status: 'ok', db: 'up' });
    });

    it('no expone health sin el prefijo de versión', async () => {
      await request(app.getHttpServer()).get('/health').expect(404);
    });

    it('documenta el endpoint en el contrato OpenAPI', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/docs-json')
        .expect(200);

      const operation = response.body.paths['/api/v1/health']?.get;
      expect(operation?.tags).toContain('health');
      expect(operation?.responses?.['200']).toBeDefined();
    });

    it('genera un x-request-id UUID cuando la petición no trae uno', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/health')
        .expect(200);

      expect(response.headers['x-request-id']).toMatch(UUID_PATTERN);
    });

    it('refleja el x-request-id entrante cuando es válido', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/health')
        .set('x-request-id', 'cliente-123.abc_DEF')
        .expect(200);

      expect(response.headers['x-request-id']).toBe('cliente-123.abc_DEF');
    });

    it('reemplaza un x-request-id inválido por un UUID nuevo', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/health')
        .set('x-request-id', 'id con espacios;rm -rf')
        .expect(200);

      expect(response.headers['x-request-id']).toMatch(UUID_PATTERN);
    });

    it('incluye x-request-id también en respuestas 404', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/no-existe')
        .set('x-request-id', 'rastreo-404')
        .expect(404);

      expect(response.headers['x-request-id']).toBe('rastreo-404');
    });

    it('incluye x-request-id en la UI de Swagger', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/docs')
        .redirects(1)
        .expect(200);

      expect(response.headers['x-request-id']).toMatch(UUID_PATTERN);
    });
    it('expone x-request-id a clientes CORS', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/health')
        .set('Origin', 'http://localhost:8080')
        .expect(200);

      expect(response.headers['access-control-expose-headers']).toContain(
        'x-request-id',
      );
    });
  });

  describe('con la base de datos caída', () => {
    let app: INestApplication<App>;

    beforeAll(async () => {
      app = await bootstrapHealthApp(new StaticDatabaseProbe(false));
    });

    afterAll(async () => {
      await app.close();
    });

    it('sigue respondiendo 200 y degrada el campo db a down', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/health')
        .expect(200);

      expect(response.body).toEqual({ status: 'ok', db: 'down' });
    });
  });
});
