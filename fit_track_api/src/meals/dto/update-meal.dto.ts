import { MealType } from '@prisma/client';

export class UpdateMealDto {
  eatenAt?: string;
  mealType?: MealType;
  notes?: string;
  photoId?: string;
}
