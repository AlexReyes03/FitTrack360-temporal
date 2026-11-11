import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MealType, type MealLog } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMealItemDto } from './dto/create-meal-item.dto';
import { CreateMealDto } from './dto/create-meal.dto';
import { UpdateMealDto } from './dto/update-meal.dto';
import { MealResponseDto, type MealItemEntity } from './dto/meal-response.dto';

export interface FrozenMealItemSnapshot {
  name: string;
  fdcId: string | null;
  servingG: number;
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}

export type MealLogWithItems = MealLog & { items?: MealItemEntity[] };

interface MealLogDelegate {
  create(args: {
    data: {
      userId: string;
      eatenAt: Date;
      mealType: MealType;
      notes: string | null;
      photoId: string | null;
      items?: { create: FrozenMealItemSnapshot[] };
    };
    include?: { items: boolean };
  }): Promise<MealLogWithItems>;
  findMany(args: {
    where: {
      userId: string;
      eatenAt?: { gte: Date; lte: Date };
    };
    include?: { items: boolean };
    orderBy?: { eatenAt: 'asc' | 'desc' };
  }): Promise<MealLogWithItems[]>;
  findFirst(args: {
    where: { id: string; userId: string };
    include?: { items: boolean };
  }): Promise<MealLogWithItems | null>;
  update(args: {
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
    include?: { items: boolean };
  }): Promise<MealLogWithItems>;
  delete(args: { where: { id: string } }): Promise<MealLog>;
}

@Injectable()
export class MealsService {
  constructor(private readonly prisma: PrismaService) {}

  private get mealLog(): MealLogDelegate {
    return this.prisma.mealLog as unknown as MealLogDelegate;
  }

  async create(userId: string, dto: CreateMealDto): Promise<MealResponseDto> {
    if (!dto.mealType || !Object.values(MealType).includes(dto.mealType)) {
      throw new BadRequestException(
        `mealType inválido. Debe ser uno de: ${Object.values(MealType).join(', ')}`,
      );
    }

    const frozenItems = this.freezeMealItems(dto.items ?? []);

    const meal = await this.mealLog.create({
      data: {
        userId,
        eatenAt: new Date(dto.eatenAt),
        mealType: dto.mealType,
        notes: dto.notes ?? null,
        photoId: dto.photoId ?? null,
        items:
          frozenItems.length > 0
            ? {
                create: frozenItems,
              }
            : undefined,
      },
      include: { items: true },
    });

    return MealResponseDto.fromEntity(meal);
  }

  async findAll(userId: string): Promise<MealResponseDto[]> {
    const meals = await this.mealLog.findMany({
      where: { userId },
      include: { items: true },
      orderBy: { eatenAt: 'desc' },
    });

    return meals.map((m) => MealResponseDto.fromEntity(m));
  }

  async findOne(userId: string, id: string): Promise<MealResponseDto> {
    const meal = await this.mealLog.findFirst({
      where: { id, userId },
      include: { items: true },
    });

    if (!meal) {
      throw new NotFoundException('Comida no encontrada');
    }

    return MealResponseDto.fromEntity(meal);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateMealDto,
  ): Promise<MealResponseDto> {
    if (
      dto.mealType !== undefined &&
      !Object.values(MealType).includes(dto.mealType)
    ) {
      throw new BadRequestException(
        `mealType inválido. Debe ser uno de: ${Object.values(MealType).join(', ')}`,
      );
    }

    const existing = await this.mealLog.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Comida no encontrada');
    }

    const frozenItems =
      dto.items !== undefined ? this.freezeMealItems(dto.items) : undefined;

    const updated = await this.mealLog.update({
      where: { id },
      data: {
        eatenAt: dto.eatenAt ? new Date(dto.eatenAt) : undefined,
        mealType: dto.mealType !== undefined ? dto.mealType : undefined,
        notes:
          dto.notes !== undefined ? (dto.notes ? dto.notes : null) : undefined,
        photoId:
          dto.photoId !== undefined
            ? dto.photoId
              ? dto.photoId
              : null
            : undefined,
        items:
          frozenItems !== undefined
            ? {
                deleteMany: {},
                create: frozenItems,
              }
            : undefined,
      },
      include: { items: true },
    });

    return MealResponseDto.fromEntity(updated);
  }

  async remove(userId: string, id: string): Promise<void> {
    const existing = await this.mealLog.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Comida no encontrada');
    }

    await this.mealLog.delete({
      where: { id },
    });
  }

  /**
   * Copia y congela explícitamente los valores nutricionales de cada alimento (Regla M-02),
   * validando que porciones y macronutrientes sean números no negativos.
   */
  private freezeMealItems(
    items: CreateMealItemDto[],
  ): FrozenMealItemSnapshot[] {
    return items.map((item, index) => {
      const numericFields: Array<
        keyof Pick<
          CreateMealItemDto,
          'servingG' | 'kcal' | 'proteinG' | 'carbsG' | 'fatG'
        >
      > = ['servingG', 'kcal', 'proteinG', 'carbsG', 'fatG'];

      for (const field of numericFields) {
        const value = item[field];
        if (typeof value !== 'number' || Number.isNaN(value) || value < 0) {
          throw new BadRequestException(
            `items[${index}].${field} debe ser un número no negativo`,
          );
        }
      }

      if (!item.name || typeof item.name !== 'string' || !item.name.trim()) {
        throw new BadRequestException(`items[${index}].name es obligatorio`);
      }

      return Object.freeze({
        name: String(item.name).trim(),
        fdcId: item.fdcId ? String(item.fdcId) : null,
        servingG: Number(item.servingG),
        kcal: Number(item.kcal),
        proteinG: Number(item.proteinG),
        carbsG: Number(item.carbsG),
        fatG: Number(item.fatG),
      });
    });
  }
}
