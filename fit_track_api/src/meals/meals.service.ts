import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMealDto } from './dto/create-meal.dto';
import { UpdateMealDto } from './dto/update-meal.dto';
import { MealResponseDto } from './dto/meal-response.dto';

@Injectable()
export class MealsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateMealDto): Promise<MealResponseDto> {
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
    });
    return meals.map((m) => MealResponseDto.fromEntity(m));
  }

  async findOne(userId: string, id: string): Promise<MealResponseDto | null> {
    const meal = await this.prisma.mealLog.findFirst({
      where: { id, userId },
    });
    return meal ? MealResponseDto.fromEntity(meal) : null;
  }

  async update(
    _userId: string,
    id: string,
    dto: UpdateMealDto,
  ): Promise<MealResponseDto> {
    const updated = await this.prisma.mealLog.update({
      where: { id },
      data: {
        eatenAt: dto.eatenAt ? new Date(dto.eatenAt) : undefined,
        mealType: dto.mealType !== undefined ? dto.mealType : undefined,
        notes: dto.notes !== undefined ? dto.notes : undefined,
        photoId: dto.photoId !== undefined ? dto.photoId : undefined,
      },
    });
    return MealResponseDto.fromEntity(updated);
  }

  async remove(_userId: string, id: string): Promise<void> {
    await this.prisma.mealLog.delete({
      where: { id },
    });
  }
}
