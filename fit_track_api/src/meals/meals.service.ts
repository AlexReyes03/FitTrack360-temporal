import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MealType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMealDto } from './dto/create-meal.dto';
import { UpdateMealDto } from './dto/update-meal.dto';
import { MealResponseDto } from './dto/meal-response.dto';

@Injectable()
export class MealsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateMealDto): Promise<MealResponseDto> {
    if (!dto.mealType || !Object.values(MealType).includes(dto.mealType)) {
      throw new BadRequestException(
        `mealType inválido. Debe ser uno de: ${Object.values(MealType).join(', ')}`,
      );
    }

    const meal = await this.prisma.mealLog.create({
      data: {
        userId,
        eatenAt: new Date(dto.eatenAt),
        mealType: dto.mealType,
        notes: dto.notes ?? null,
        photoId: dto.photoId ?? null,
      },
    });

    return MealResponseDto.fromEntity(meal);
  }

  async findAll(userId: string): Promise<MealResponseDto[]> {
    const meals = await this.prisma.mealLog.findMany({
      where: { userId },
      orderBy: { eatenAt: 'desc' },
    });

    return meals.map((m) => MealResponseDto.fromEntity(m));
  }

  async findOne(userId: string, id: string): Promise<MealResponseDto> {
    const meal = await this.prisma.mealLog.findFirst({
      where: { id, userId },
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

    const existing = await this.prisma.mealLog.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Comida no encontrada');
    }

    const updated = await this.prisma.mealLog.update({
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
      },
    });

    return MealResponseDto.fromEntity(updated);
  }

  async remove(userId: string, id: string): Promise<void> {
    const existing = await this.prisma.mealLog.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Comida no encontrada');
    }

    await this.prisma.mealLog.delete({
      where: { id },
    });
  }
}
