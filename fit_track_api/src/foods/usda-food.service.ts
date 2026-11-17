import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FoodItemDto } from './dto/food-item.dto';
import {
  USDA_HTTP_TIMEOUT_MS,
  USDA_SEARCH_ENDPOINT,
  USDA_SEARCH_PAGE_SIZE,
  UsdaHttpClient,
} from './usda-http.client';

export const USDA_UNAVAILABLE_CODE = 'USDA_UNAVAILABLE';
export const USDA_UNAVAILABLE_MESSAGE =
  'Servicio nutricional no disponible temporalmente';

interface UsdaNutrientRaw {
  nutrientId?: number;
  nutrientNumber?: string;
  value?: number;
  amount?: number;
}

interface UsdaFoodRaw {
  fdcId?: unknown;
  description?: unknown;
  brandOwner?: unknown;
  foodNutrients?: UsdaNutrientRaw[];
}

interface UsdaSearchRaw {
  foods?: unknown;
}

const NUTRIENT = {
  kcal: { id: 1008, number: '208' },
  proteinG: { id: 1003, number: '203' },
  fatG: { id: 1004, number: '204' },
  carbsG: { id: 1005, number: '205' },
} as const;

@Injectable()
export class UsdaFoodService {
  constructor(
    private readonly config: ConfigService,
    private readonly http: UsdaHttpClient,
  ) {}

  async search(query: string): Promise<FoodItemDto[]> {
    const trimmed = query.trim();
    if (!trimmed) {
      return [];
    }

    const apiKey = this.config.get<string>('USDA_FDC_API_KEY')?.trim();
    if (!apiKey) {
      throw unavailable();
    }

    const url = new URL(USDA_SEARCH_ENDPOINT);
    url.searchParams.set('query', trimmed);
    url.searchParams.set('pageSize', String(USDA_SEARCH_PAGE_SIZE));
    url.searchParams.set('api_key', apiKey);

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), USDA_HTTP_TIMEOUT_MS);

    try {
      const response = await this.http.get(url, { signal: controller.signal });
      if (!response.ok) {
        throw unavailable();
      }
      const payload = (await response.json()) as UsdaSearchRaw;
      return normalizeFoods(payload).slice(0, USDA_SEARCH_PAGE_SIZE);
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }
      throw unavailable();
    } finally {
      clearTimeout(timer);
    }
  }
}

function unavailable(): ServiceUnavailableException {
  return new ServiceUnavailableException({
    code: USDA_UNAVAILABLE_CODE,
    message: USDA_UNAVAILABLE_MESSAGE,
  });
}

function normalizeFoods(payload: UsdaSearchRaw): FoodItemDto[] {
  if (!Array.isArray(payload.foods)) {
    return [];
  }
  const items: FoodItemDto[] = [];
  for (const food of payload.foods) {
    const item = normalizeFood(food);
    if (item) items.push(item);
  }
  return items;
}

function normalizeFood(food: unknown): FoodItemDto | null {
  if (!food || typeof food !== 'object') {
    return null;
  }
  const raw = food as UsdaFoodRaw;
  const fdcId = readFdcId(raw.fdcId);
  if (fdcId === null) {
    return null;
  }

  const nutrients = Array.isArray(raw.foodNutrients) ? raw.foodNutrients : [];
  const label = readLabel(raw.description);
  const brandOwner = readBrand(raw.brandOwner);

  return {
    fdcId,
    description: label,
    name: label,
    servingG: 100,
    kcal: nutrientAmount(nutrients, NUTRIENT.kcal.id, NUTRIENT.kcal.number),
    proteinG: nutrientAmount(
      nutrients,
      NUTRIENT.proteinG.id,
      NUTRIENT.proteinG.number,
    ),
    carbsG: nutrientAmount(
      nutrients,
      NUTRIENT.carbsG.id,
      NUTRIENT.carbsG.number,
    ),
    fatG: nutrientAmount(nutrients, NUTRIENT.fatG.id, NUTRIENT.fatG.number),
    ...(brandOwner ? { brandOwner } : {}),
  };
}

function readFdcId(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    return null;
  }
  return value;
}

function readLabel(value: unknown): string {
  if (typeof value === 'string' && value.trim()) {
    return value.trim();
  }
  return 'Alimento sin nombre';
}

function readBrand(value: unknown): string | null {
  if (typeof value === 'string' && value.trim()) {
    return value.trim();
  }
  return null;
}

function nutrientAmount(
  nutrients: UsdaNutrientRaw[],
  id: number,
  number: string,
): number {
  const byId = nutrients.find((nutrient) => nutrient.nutrientId === id);
  const match =
    byId ?? nutrients.find((nutrient) => nutrient.nutrientNumber === number);
  const raw = match?.value ?? match?.amount;
  if (typeof raw !== 'number' || !Number.isFinite(raw) || raw < 0) {
    return 0;
  }
  return Math.round(raw * 100) / 100;
}
