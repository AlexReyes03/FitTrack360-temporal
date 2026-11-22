import { jest } from '@jest/globals';
import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { APP_HTTP_OPTIONS, configureApp } from '../../src/app.setup';
import { JwtAuthGuard } from '../../src/auth/jwt-auth.guard';
import { PrismaService } from '../../src/prisma/prisma.service';
import {
  USDA_SEARCH_PAGE_SIZE,
  UsdaHttpClient,
  type UsdaHttpResponse,
} from '../../src/foods/usda-http.client';

jest.unstable_mockModule('firebase-admin/auth', () => ({ getAuth: jest.fn() }));

const API_KEY = 'test-usda-key';

class FakeUsdaHttpClient extends UsdaHttpClient {
  readonly urls: URL[] = [];
  mode: 'ok' | 'down' = 'ok';

  get(url: URL): Promise<UsdaHttpResponse> {
    this.urls.push(url);
    if (this.mode === 'down') {
      return Promise.resolve({
        ok: false,
        status: 503,
        json: () => Promise.resolve({ api_key: API_KEY }),
      });
    }
    return Promise.resolve({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          foods: [
            {
              fdcId: 173904,
              description: 'Oats',
              brandOwner: 'Generic',
              foodNutrients: [
                { nutrientId: 1008, value: 389 },
                { nutrientId: 1003, value: 16.9 },
                { nutrientId: 1005, value: 66.3 },
                { nutrientId: 1004, value: 6.9 },
              ],
            },
          ],
        }),
    });
  }
}

async function bootstrap(options: {
  apiKey?: string;
  guard: boolean;
  http: UsdaHttpClient;
}): Promise<INestApplication<App>> {
  const modulePath: string = '../../src/foods/foods.module';
  const { FoodsModule } = (await import(
    modulePath
  )) as typeof import('../../src/foods/foods.module');
  const builder = Test.createTestingModule({
    imports: [
      ConfigModule.forRoot({
        isGlobal: true,
        ignoreEnvFile: true,
        load: [() => ({ USDA_FDC_API_KEY: options.apiKey })],
      }),
      FoodsModule,
    ],
  })
    .overrideProvider(PrismaService)
    .useValue({})
    .overrideProvider(UsdaHttpClient)
    .useValue(options.http);

  const moduleRef = await (
    options.guard
      ? builder
      : builder
          .overrideGuard(JwtAuthGuard)
          .useValue({ canActivate: () => true })
  ).compile();

  const app = moduleRef.createNestApplication<INestApplication<App>>(
    APP_HTTP_OPTIONS,
  );
  configureApp(app);
  await app.init();
  return app;
}

describe('GET /api/v1/foods/search', () => {
  const http = new FakeUsdaHttpClient();
  let app: INestApplication<App>;

  beforeAll(async () => {
    jest.spyOn(global, 'fetch').mockImplementation(() => {
      throw new Error('las pruebas no deben llamar a USDA');
    });
    app = await bootstrap({ apiKey: API_KEY, guard: false, http });
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    await app.close();
  });

  beforeEach(() => {
    http.mode = 'ok';
    http.urls.length = 0;
  });

  it('devuelve alimentos con macros y documenta el contrato en Swagger', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/v1/foods/search')
      .query({ q: 'oats' })
      .expect(200);

    expect(response.body).toEqual([
      {
        fdcId: 173904,
        description: 'Oats',
        name: 'Oats',
        servingG: 100,
        kcal: 389,
        proteinG: 16.9,
        carbsG: 66.3,
        fatG: 6.9,
        brandOwner: 'Generic',
      },
    ]);
    expect(JSON.stringify(response.body)).not.toContain(API_KEY);
    expect(http.urls[0]?.searchParams.get('pageSize')).toBe(
      String(USDA_SEARCH_PAGE_SIZE),
    );
    expect(http.urls[0]?.searchParams.get('api_key')).toBe(API_KEY);

    const docs = await request(app.getHttpServer())
      .get('/api/docs-json')
      .expect(200);
    const operation = docs.body.paths?.['/api/v1/foods/search']?.get as
      | {
          responses?: Record<string, unknown>;
          parameters?: { name: string }[];
        }
      | undefined;
    expect(operation?.responses?.['200']).toBeDefined();
    expect(operation?.responses?.['400']).toBeDefined();
    expect(operation?.responses?.['401']).toBeDefined();
    expect(operation?.responses?.['503']).toBeDefined();
    expect(
      operation?.parameters?.some((parameter) => parameter.name === 'q'),
    ).toBe(true);
    expect(JSON.stringify(docs.body)).not.toContain(API_KEY);
  });

  it('503 USDA_UNAVAILABLE cuando USDA falla, sin filtrar la key', async () => {
    http.mode = 'down';

    const response = await request(app.getHttpServer())
      .get('/api/v1/foods/search')
      .query({ q: 'oats' })
      .expect(503);

    expect(response.body).toEqual({
      code: 'USDA_UNAVAILABLE',
      message: 'Servicio nutricional no disponible temporalmente',
    });
    expect(JSON.stringify(response.body)).not.toContain(API_KEY);
    expect(JSON.stringify(response.body)).not.toContain('api_key');
  });

  it('400 si q viene vacío o con campos fuera de la whitelist', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/foods/search')
      .query({ q: '   ' })
      .expect(400);

    await request(app.getHttpServer())
      .get('/api/v1/foods/search')
      .query({ q: 'oats', api_key: API_KEY })
      .expect(400);

    expect(http.urls).toHaveLength(0);
  });
});

describe('GET /api/v1/foods/search sin sesión', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    app = await bootstrap({
      apiKey: API_KEY,
      guard: true,
      http: new FakeUsdaHttpClient(),
    });
  });

  afterAll(async () => {
    await app.close();
  });

  it('responde 401 y no consulta USDA', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/foods/search')
      .query({ q: 'oats' })
      .expect(401);
  });
});

describe('GET /api/v1/foods/search sin API key', () => {
  let app: INestApplication<App>;
  const http = new FakeUsdaHttpClient();

  beforeAll(async () => {
    app = await bootstrap({ apiKey: '', guard: false, http });
  });

  afterAll(async () => {
    await app.close();
  });

  it('responde 503 y no llama al cliente HTTP', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/v1/foods/search')
      .query({ q: 'oats' })
      .expect(503);

    expect(response.body.code).toBe('USDA_UNAVAILABLE');
    expect(http.urls).toHaveLength(0);
  });
});
