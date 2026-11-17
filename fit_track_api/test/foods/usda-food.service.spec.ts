import { jest } from '@jest/globals';
import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  USDA_UNAVAILABLE_CODE,
  USDA_UNAVAILABLE_MESSAGE,
  UsdaFoodService,
} from '../../src/foods/usda-food.service';
import {
  USDA_HTTP_TIMEOUT_MS,
  USDA_SEARCH_PAGE_SIZE,
  type UsdaHttpClient,
  type UsdaHttpResponse,
} from '../../src/foods/usda-http.client';

const API_KEY = 'test-usda-key';

function configWith(key: string | undefined): ConfigService {
  return {
    get: (name: string) => (name === 'USDA_FDC_API_KEY' ? key : undefined),
  } as ConfigService;
}

function jsonResponse(body: unknown, status = 200): UsdaHttpResponse {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: () => Promise.resolve(body),
  };
}

function oatsPayload() {
  return {
    foods: [
      {
        fdcId: 173904,
        description: '  Oats  ',
        foodNutrients: [
          { nutrientId: 1008, nutrientNumber: '208', value: 389.1 },
          { nutrientId: 1003, nutrientNumber: '203', value: 16.89 },
          { nutrientId: 1005, nutrientNumber: '205', value: 66.27 },
          { nutrientId: 1004, nutrientNumber: '204', value: 6.9 },
          { nutrientId: 1062, nutrientNumber: '268', value: 1628 },
        ],
      },
    ],
  };
}

describe('UsdaFoodService', () => {
  it('mapea una búsqueda válida a fdcId y macros por 100 g', async () => {
    const calls: URL[] = [];
    const http: UsdaHttpClient = {
      get: (url) => {
        calls.push(url);
        return Promise.resolve(jsonResponse(oatsPayload()));
      },
    };
    const service = new UsdaFoodService(configWith(API_KEY), http);

    const items = await service.search('  oats  ');

    expect(calls).toHaveLength(1);
    expect(calls[0]?.origin + calls[0]?.pathname).toBe(
      'https://api.nal.usda.gov/fdc/v1/foods/search',
    );
    expect(calls[0]?.searchParams.get('query')).toBe('oats');
    expect(calls[0]?.searchParams.get('pageSize')).toBe(
      String(USDA_SEARCH_PAGE_SIZE),
    );
    expect(calls[0]?.searchParams.get('api_key')).toBe(API_KEY);
    expect(items).toEqual([
      {
        fdcId: 173904,
        description: 'Oats',
        name: 'Oats',
        servingG: 100,
        kcal: 389.1,
        proteinG: 16.89,
        carbsG: 66.27,
        fatG: 6.9,
      },
    ]);
    expect(JSON.stringify(items)).not.toContain(API_KEY);
    expect(JSON.stringify(items)).not.toContain('api_key');
  });

  it('usa el número legado si el nutrientId no viene y limita a 20', async () => {
    const foods = Array.from({ length: 25 }, (_, index) => ({
      fdcId: index + 1,
      description: `Food ${index + 1}`,
      foodNutrients: [
        { nutrientNumber: '208', amount: 10 },
        { nutrientNumber: '203', amount: 1 },
        { nutrientNumber: '205', amount: 2 },
        { nutrientNumber: '204', amount: 3 },
      ],
    }));
    const http: UsdaHttpClient = {
      get: () => Promise.resolve(jsonResponse({ foods })),
    };
    const service = new UsdaFoodService(configWith(API_KEY), http);

    const items = await service.search('food');

    expect(items).toHaveLength(USDA_SEARCH_PAGE_SIZE);
    expect(items[0]).toMatchObject({
      fdcId: 1,
      kcal: 10,
      proteinG: 1,
      carbsG: 2,
      fatG: 3,
      servingG: 100,
    });
  });

  it('devuelve lista vacía si USDA no trae alimentos', async () => {
    const http: UsdaHttpClient = {
      get: () => Promise.resolve(jsonResponse({ foods: [] })),
    };
    const service = new UsdaFoodService(configWith(API_KEY), http);

    await expect(service.search('zzz')).resolves.toEqual([]);
  });

  it('no llama a USDA si la key falta y responde USDA_UNAVAILABLE', async () => {
    const http: UsdaHttpClient = {
      get: () => Promise.reject(new Error('no debía llamarse')),
    };
    const service = new UsdaFoodService(configWith('   '), http);

    await expectUnavailable(service.search('oats'));
  });

  it.each([429, 500, 503])(
    'HTTP %s de USDA responde USDA_UNAVAILABLE sin filtrar la key',
    async (status) => {
      const http: UsdaHttpClient = {
        get: () =>
          Promise.resolve(
            jsonResponse({ error: `api_key=${API_KEY}` }, status),
          ),
      };
      const service = new UsdaFoodService(configWith(API_KEY), http);

      await expectUnavailable(service.search('oats'));
    },
  );

  it('un fallo de red o un timeout del cliente responde USDA_UNAVAILABLE', async () => {
    const http: UsdaHttpClient = {
      get: () =>
        Promise.reject(new Error(`connect ETIMEDOUT api_key=${API_KEY}`)),
    };
    const service = new UsdaFoodService(configWith(API_KEY), http);

    await expectUnavailable(service.search('oats'));
  });

  it('aborta la petición a los 5 s', async () => {
    jest.useFakeTimers();
    try {
      let signal: AbortSignal | undefined;
      const http: UsdaHttpClient = {
        get: (_url, options) => {
          signal = options.signal;
          return new Promise((_resolve, reject) => {
            options.signal.addEventListener('abort', () => {
              reject(new Error('aborted'));
            });
          });
        },
      };
      const service = new UsdaFoodService(configWith(API_KEY), http);
      const pending = service.search('oats');
      const expectation = expectUnavailable(pending);

      await jest.advanceTimersByTimeAsync(USDA_HTTP_TIMEOUT_MS - 1);
      expect(signal?.aborted).toBe(false);

      await jest.advanceTimersByTimeAsync(1);
      expect(signal?.aborted).toBe(true);
      await expectation;
    } finally {
      jest.useRealTimers();
    }
  });
});

async function expectUnavailable(pending: Promise<unknown>): Promise<void> {
  try {
    await pending;
    throw new Error('la búsqueda debía fallar');
  } catch (error) {
    expect(error).toBeInstanceOf(ServiceUnavailableException);
    const body = JSON.stringify(
      (error as ServiceUnavailableException).getResponse(),
    );
    expect(body).toContain(USDA_UNAVAILABLE_CODE);
    expect(body).toContain(USDA_UNAVAILABLE_MESSAGE);
    expect(body).not.toContain(API_KEY);
    expect(body).not.toContain('api_key');
    expect(body).not.toContain('nal.usda.gov');
  }
}
