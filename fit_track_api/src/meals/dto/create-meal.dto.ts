import { MealType } from '@prisma/client';

export class CreateMealDto {
  eatenAt!: string;
  mealType!: MealType;
  notes?: string;
  photoId?: string;
}
