import { BadRequestException, NotFoundException } from '@nestjs/common';
import { MealType, type MealLog } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import type { AuthenticatedRequest } from '../../src/auth/jwt-auth.guard';
import { CreateMealDto } from '../../src/meals/dto/create-meal.dto';
import type { MealItemEntity } from '../../src/meals/dto/meal-response.dto';
import { MealsController } from '../../src/meals/meals.controller';
import {
  MealsService,
  type FrozenMealItemSnapshot,
} from '../../src/meals/meals.service';
import { PrismaService } from '../../src/prisma/prisma.service';

interface StoredMeal extends MealLog {
  items: MealItemEntity[];
}

function createInMemoryMealsPrisma() {
  const meals: StoredMeal[] = [];
  let mealSeq = 1;
  let itemSeq = 1;

  return {
    meals,
    mealLog: {
      create: ({
        data,
      }: {
        data: {
          userId: string;
          eatenAt: Date;
          mealType: MealType;
          notes: string | null;
          photoId: string | null;
          items?: { create: FrozenMealItemSnapshot[] };
        };
      }): Promise<StoredMeal> => {
        const now = new Date('2026-11-11T10:00:00.000Z');
        const mealId = `meal-${mealSeq++}`;
        const createdItems: MealItemEntity[] = (data.items?.create ?? []).map(
          (item) => ({
            id: `item-${itemSeq++}`,
            mealLogId: mealId,
            fdcId: item.fdcId,
            name: item.name,
            servingG: item.servingG,
            kcal: item.kcal,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
            createdAt: now,
            updatedAt: now,
          }),
        );

        const record: StoredMeal = {
          id: mealId,
          userId: data.userId,
          eatenAt: data.eatenAt,
          mealType: data.mealType,
          notes: data.notes,
          photoId: data.photoId,
          createdAt: now,
          updatedAt: now,
          items: createdItems,
        };
        meals.push(record);
        return Promise.resolve(record);
      },

      findMany: ({
        where,
      }: {
        where?: {
          userId?: string;
          eatenAt?: { gte?: Date; lte?: Date };
        };
      }): Promise<StoredMeal[]> => {
        const filtered = meals.filter((m) => {
          if (where?.userId && m.userId !== where.userId) return false;
          if (where?.eatenAt?.gte && m.eatenAt < where.eatenAt.gte) {
            return false;
          }
          if (where?.eatenAt?.lte && m.eatenAt > where.eatenAt.lte) {
            return false;
          }
          return true;
        });
        return Promise.resolve(filtered);
      },

      findFirst: ({
        where,
      }: {
        where: { id?: string; userId?: string };
      }): Promise<StoredMeal | null> => {
        const found =
          meals.find(
            (m) =>
              (!where.id || m.id === where.id) &&
              (!where.userId || m.userId === where.userId),
          ) ?? null;
        return Promise.resolve(found);
      },

      update: ({
        where,
        data,
      }: {
        where: { id: string };
        data: {
          eatenAt?: Date;
          mealType?: MealType;
          notes?: string | null;
          photoId?: string | null;
          items?: {
            deleteMany: Record<string, never>;
            create: FrozenMealItemSnapshot[];
          };
        };
      }): Promise<StoredMeal> => {
        const record = meals.find((m) => m.id === where.id);
        if (!record) {
          throw new Error('Record not found');
        }
        const now = new Date('2026-11-11T11:00:00.000Z');
        if (data.eatenAt !== undefined) record.eatenAt = data.eatenAt;
        if (data.mealType !== undefined) record.mealType = data.mealType;
        if (data.notes !== undefined) record.notes = data.notes;
        if (data.photoId !== undefined) record.photoId = data.photoId;
        if (data.items !== undefined) {
          record.items = data.items.create.map((item) => ({
            id: `item-${itemSeq++}`,
            mealLogId: record.id,
            fdcId: item.fdcId,
            name: item.name,
            servingG: item.servingG,
            kcal: item.kcal,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
            createdAt: now,
            updatedAt: now,
          }));
        }
        record.updatedAt = now;
        return Promise.resolve(record);
      },

      delete: ({ where }: { where: { id: string } }): Promise<StoredMeal> => {
        const idx = meals.findIndex((m) => m.id === where.id);
        if (idx === -1) {
          throw new Error('Record not found');
        }
        const [removed] = meals.splice(idx, 1);
        return Promise.resolve(removed);
      },
    },
  };
}

describe('MealsModule · Macros, Resumen Diario y Aislamiento (Task W11-04)', () => {
  let service: MealsService;
  let controller: MealsController;
  let store: ReturnType<typeof createInMemoryMealsPrisma>;

  beforeEach(() => {
    store = createInMemoryMealsPrisma();
    service = new MealsService(store as unknown as PrismaService);
    controller = new MealsController(service);
  });

  describe('1. Validación de DTOs y números no negativos', () => {
    it('acepta un arreglo válido de MealItems con porciones y macros no negativos', async () => {
      const dto = plainToInstance(CreateMealDto, {
        eatenAt: '2026-11-04T08:30:00.000Z',
        mealType: MealType.BREAKFAST,
        items: [
          {
            name: 'Avena cocida',
            servingG: 100,
            kcal: 389,
            proteinG: 16.9,
            carbsG: 66.3,
            fatG: 6.9,
          },
        ],
      });

      const errors = await validate(dto);
      expect(errors).toHaveLength(0);
    });

    it('rechaza valores negativos en servingG, kcal, proteinG, carbsG o fatG mediante class-validator', async () => {
      const dto = plainToInstance(CreateMealDto, {
        eatenAt: '2026-11-04T08:30:00.000Z',
        mealType: MealType.BREAKFAST,
        items: [
          {
            name: 'Alimento inválido',
            servingG: -10,
            kcal: -100,
            proteinG: -5,
            carbsG: -20,
            fatG: -2,
          },
        ],
      });

      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      expect(errors[0].property).toBe('items');
      const nestedErrors = errors[0].children?.[0]?.children ?? [];
      const failedProps = nestedErrors.map((e) => e.property);
      expect(failedProps).toEqual(
        expect.arrayContaining([
          'servingG',
          'kcal',
          'proteinG',
          'carbsG',
          'fatG',
        ]),
      );
    });

    it('lanza BadRequestException en el servicio si algún macro o porción es negativo', async () => {
      await expect(
        service.create('user-1', {
          eatenAt: '2026-11-04T08:30:00.000Z',
          mealType: MealType.BREAKFAST,
          items: [
            {
              name: 'Pollo',
              servingG: 150,
              kcal: -50,
              proteinG: 30,
              carbsG: 0,
              fatG: 3,
            },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('2. Creación anidada, congelamiento de macros y cálculo de totales', () => {
    it('congela los macros al guardar y calcula correctamente los totales sumados de la comida', async () => {
      const mutableInputItem = {
        name: 'Pechuga de pollo',
        fdcId: '171077',
        servingG: 150,
        kcal: 247.5,
        proteinG: 46.5,
        carbsG: 0,
        fatG: 5.4,
      };
      const secondItem = {
        name: 'Arroz blanco cocido',
        servingG: 200,
        kcal: 260,
        proteinG: 5.4,
        carbsG: 56.4,
        fatG: 0.6,
      };

      const created = await service.create('user-1', {
        eatenAt: '2026-11-04T14:00:00.000Z',
        mealType: MealType.LUNCH,
        notes: 'Almuerzo post-entreno',
        items: [mutableInputItem, secondItem],
      });

      // Mutar la fuente original después de guardar no debe alterar lo persistido (Regla M-02)
      mutableInputItem.kcal = 9999;
      mutableInputItem.proteinG = 0;

      expect(created.items).toHaveLength(2);
      expect(created.items[0].kcal).toBe(247.5);
      expect(created.items[0].proteinG).toBe(46.5);
      expect(created.totals).toEqual({
        kcal: 507.5,
        proteinG: 51.9,
        carbsG: 56.4,
        fatG: 6,
      });

      const fetched = await service.findOne('user-1', created.id);
      expect(fetched.items[0].kcal).toBe(247.5);
      expect(fetched.totals.kcal).toBe(507.5);
    });

    it('recalcula los totales al actualizar los alimentos de un MealLog existente', async () => {
      const created = await service.create('user-1', {
        eatenAt: '2026-11-04T20:00:00.000Z',
        mealType: MealType.DINNER,
        items: [
          {
            name: 'Atún en agua',
            servingG: 120,
            kcal: 140,
            proteinG: 30,
            carbsG: 0,
            fatG: 1.2,
          },
        ],
      });

      const updated = await service.update('user-1', created.id, {
        items: [
          {
            name: 'Salmón a la plancha',
            servingG: 180,
            kcal: 360,
            proteinG: 39,
            carbsG: 0,
            fatG: 22,
          },
        ],
      });

      expect(updated.items).toHaveLength(1);
      expect(updated.items[0].name).toBe('Salmón a la plancha');
      expect(updated.totals).toEqual({
        kcal: 360,
        proteinG: 39,
        carbsG: 0,
        fatG: 22,
      });
    });
  });

  describe('3. Resumen diario de nutrición desglosado por tipo de comida', () => {
    it('agrupa y suma macros por BREAKFAST, LUNCH, DINNER y SNACK filtrando por fecha y userId', async () => {
      const reqUser1 = {
        user: { sub: 'user-1', email: 'u1@fittrack.com' },
      } as AuthenticatedRequest;

      await controller.create(reqUser1, {
        eatenAt: '2026-11-04T08:00:00.000Z',
        mealType: MealType.BREAKFAST,
        items: [
          {
            name: 'Huevos revueltos',
            servingG: 120,
            kcal: 180,
            proteinG: 14,
            carbsG: 1.5,
            fatG: 13,
          },
        ],
      });

      await controller.create(reqUser1, {
        eatenAt: '2026-11-04T14:30:00.000Z',
        mealType: MealType.LUNCH,
        items: [
          {
            name: 'Pollo con arroz',
            servingG: 300,
            kcal: 500,
            proteinG: 45,
            carbsG: 55,
            fatG: 8,
          },
        ],
      });

      // Comida de otro día (no debe incluirse en el resumen del 2026-11-04)
      await controller.create(reqUser1, {
        eatenAt: '2026-11-05T09:00:00.000Z',
        mealType: MealType.BREAKFAST,
        items: [
          {
            name: 'Hotcakes',
            servingG: 200,
            kcal: 600,
            proteinG: 12,
            carbsG: 90,
            fatG: 20,
          },
        ],
      });

      // Comida de otro usuario el mismo día (no debe filtrarse en el resumen de user-1)
      await service.create('user-2', {
        eatenAt: '2026-11-04T13:00:00.000Z',
        mealType: MealType.LUNCH,
        items: [
          {
            name: 'Pizza ajena',
            servingG: 400,
            kcal: 1200,
            proteinG: 40,
            carbsG: 140,
            fatG: 50,
          },
        ],
      });

      const summary = await controller.getDailySummary(reqUser1, {
        date: '2026-11-04',
      });

      expect(summary.date).toBe('2026-11-04');
      expect(summary.totals).toEqual({
        kcal: 680,
        proteinG: 59,
        carbsG: 56.5,
        fatG: 21,
      });
      expect(summary.byMealType[MealType.BREAKFAST]).toEqual({
        kcal: 180,
        proteinG: 14,
        carbsG: 1.5,
        fatG: 13,
        mealsCount: 1,
        itemsCount: 1,
      });
      expect(summary.byMealType[MealType.LUNCH]).toEqual({
        kcal: 500,
        proteinG: 45,
        carbsG: 55,
        fatG: 8,
        mealsCount: 1,
        itemsCount: 1,
      });
      expect(summary.byMealType[MealType.DINNER].kcal).toBe(0);
      expect(summary.byMealType[MealType.SNACK].kcal).toBe(0);
    });

    it('lanza BadRequestException cuando el rango de fechas es inválido (from > to)', async () => {
      await expect(
        service.getDailySummary('user-1', {
          from: '2026-11-10T00:00:00.000Z',
          to: '2026-11-04T00:00:00.000Z',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('4. Aislamiento estricto entre usuarios (Regla S4 · 404 Not Found)', () => {
    it('retorna 404 NotFoundException al consultar, actualizar o borrar una comida de otro usuario', async () => {
      const ownerMeal = await service.create('user-owner', {
        eatenAt: '2026-11-04T08:30:00.000Z',
        mealType: MealType.SNACK,
        items: [
          {
            name: 'Yogurt griego',
            servingG: 150,
            kcal: 130,
            proteinG: 15,
            carbsG: 6,
            fatG: 4,
          },
        ],
      });

      await expect(
        service.findOne('user-intruder', ownerMeal.id),
      ).rejects.toThrow(NotFoundException);

      await expect(
        service.update('user-intruder', ownerMeal.id, {
          notes: 'Intento de modificación ajena',
        }),
      ).rejects.toThrow(NotFoundException);

      await expect(
        service.remove('user-intruder', ownerMeal.id),
      ).rejects.toThrow(NotFoundException);

      const intruderMeals = await service.findAll('user-intruder');
      expect(intruderMeals).toHaveLength(0);
    });
  });
});
