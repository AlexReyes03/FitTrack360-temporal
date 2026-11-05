import type { MealLog, MealType } from '@prisma/client';

export class MealResponseDto {
  id!: string;
  userId!: string;
  eatenAt!: Date;
  mealType!: MealType;
  notes!: string | null;
  photoId!: string | null;
  createdAt!: Date;
  updatedAt!: Date;

  static fromEntity(meal: MealLog): MealResponseDto {
    const dto = new MealResponseDto();
    dto.id = meal.id;
    dto.userId = meal.userId;
    dto.eatenAt = meal.eatenAt;
    dto.mealType = meal.mealType;
    dto.notes = meal.notes;
    dto.photoId = meal.photoId;
    dto.createdAt = meal.createdAt;
    dto.updatedAt = meal.updatedAt;
    return dto;
  }
}
