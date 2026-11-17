import { Injectable } from '@nestjs/common';

export const USDA_SEARCH_ENDPOINT =
  'https://api.nal.usda.gov/fdc/v1/foods/search';

/** Timeout fijo hacia USDA. No es configurable para no alargar la espera de Flutter. */
export const USDA_HTTP_TIMEOUT_MS = 5000;

/** Tope de alimentos que se piden y se devuelven. */
export const USDA_SEARCH_PAGE_SIZE = 20;

export interface UsdaHttpResponse {
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
}

/**
 * Cliente saliente hacia USDA. Si `signal` se aborta, la promesa debe
 * rechazarse. El error no debe incluir la URL: lleva `api_key`.
 */
export abstract class UsdaHttpClient {
  abstract get(
    url: URL,
    options: { signal: AbortSignal },
  ): Promise<UsdaHttpResponse>;
}

/** Error de transporte sin URL ni API key. */
export class UsdaTransportError extends Error {
  constructor() {
    super('USDA request failed');
    this.name = 'UsdaTransportError';
  }
}

@Injectable()
export class FetchUsdaHttpClient extends UsdaHttpClient {
  async get(
    url: URL,
    options: { signal: AbortSignal },
  ): Promise<UsdaHttpResponse> {
    let response: Response;
    try {
      response = await fetch(url, {
        method: 'GET',
        headers: { Accept: 'application/json' },
        signal: options.signal,
      });
    } catch {
      throw new UsdaTransportError();
    }

    return {
      ok: response.ok,
      status: response.status,
      json: async () => {
        try {
          return (await response.json()) as unknown;
        } catch {
          throw new UsdaTransportError();
        }
      },
    };
  }
}
