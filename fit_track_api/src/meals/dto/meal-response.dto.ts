import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MealType, type MealLog } from '@prisma/client';

export interface MealItemEntity {
  id: string;
  mealLogId: string;
  fdcId: string | null;
  name: string;
  servingG: number;
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  createdAt: Date;
  updatedAt: Date;
}

export class MacroTotalsDto {
  @ApiProperty({ description: 'Total de calorías (kcal)', example: 247.5 })
  kcal!: number;

  @ApiProperty({ description: 'Total de proteínas (g)', example: 46.5 })
  proteinG!: number;

  @ApiProperty({ description: 'Total de carbohidratos (g)', example: 0 })
  carbsG!: number;

  @ApiProperty({ description: 'Total de grasas (g)', example: 5.4 })
  fatG!: number;
}

export class MealItemResponseDto {
  @ApiProperty({
    description: 'Identificador UUID del alimento registrado',
    example: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
  })
  id!: string;

  @ApiProperty({
    description: 'Identificador UUID del MealLog asociado',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  mealLogId!: string;

  @ApiPropertyOptional({
    description: 'Identificador en USDA FoodData Central (si aplica)',
    example: '171077',
    nullable: true,
  })
  fdcId!: string | null;

  @ApiProperty({
    description: 'Nombre del alimento congelado al momento del registro',
    example: 'Pechuga de pollo asada',
  })
  name!: string;

  @ApiProperty({
    description: 'Porción consumida en gramos',
    example: 150,
  })
  servingG!: number;

  @ApiProperty({
    description: 'Calorías congeladas (kcal)',
    example: 247.5,
  })
  kcal!: number;

  @ApiProperty({
    description: 'Proteínas congeladas (g)',
    example: 46.5,
  })
  proteinG!: number;

  @ApiProperty({
    description: 'Carbohidratos congelados (g)',
    example: 0,
  })
  carbsG!: number;

  @ApiProperty({
    description: 'Grasas congeladas (g)',
    example: 5.4,
  })
  fatG!: number;

  @ApiProperty({
    description: 'Fecha de creación del ítem',
    example: '2026-11-04T08:30:00.000Z',
  })
  createdAt!: Date;

  @ApiProperty({
    description: 'Fecha de actualización del ítem',
    example: '2026-11-04T08:30:00.000Z',
  })
  updatedAt!: Date;

  static fromEntity(item: MealItemEntity): MealItemResponseDto {
    const dto = new MealItemResponseDto();
    dto.id = item.id;
    dto.mealLogId = item.mealLogId;
    dto.fdcId = item.fdcId;
    dto.name = item.name;
    dto.servingG = item.servingG;
    dto.kcal = item.kcal;
    dto.proteinG = item.proteinG;
    dto.carbsG = item.carbsG;
    dto.fatG = item.fatG;
    dto.createdAt = item.createdAt;
    dto.updatedAt = item.updatedAt;
    return dto;
  }
}

export class MealResponseDto {
  @ApiProperty({
    description: 'Identificador único UUID del registro de comida',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  id!: string;

  @ApiProperty({
    description: 'Identificador UUID del usuario propietario del registro',
    example: 'e2b3c4d5-6789-4abc-def0-123456789abc',
  })
  userId!: string;

  @ApiProperty({
    description:
      'Fecha y hora en que se consumió la comida en formato ISO 8601',
    example: '2026-11-04T08:30:00.000Z',
  })
  eatenAt!: Date;

  @ApiProperty({
    description: 'Tipo de comida registrado',
    enum: MealType,
    example: MealType.BREAKFAST,
  })
  mealType!: MealType;

  @ApiPropertyOptional({
    description: 'Notas u observaciones personales sobre la comida',
    example: 'Tazón de avena con frutas y frutos secos.',
    nullable: true,
  })
  notes!: string | null;

  @ApiPropertyOptional({
    description: 'Identificador de la fotografía asociada a la comida',
    example: 'photo-12345',
    nullable: true,
  })
  photoId!: string | null;

  @ApiProperty({
    description:
      'Lista de alimentos (MealItems) con macronutrientes congelados',
    type: [MealItemResponseDto],
  })
  items!: MealItemResponseDto[];

  @ApiProperty({
    description:
      'Totales acumulados de calorías y macronutrientes de la comida',
    type: MacroTotalsDto,
  })
  totals!: MacroTotalsDto;

  @ApiProperty({
    description: 'Fecha de creación del registro en el sistema',
    example: '2026-11-04T08:30:00.000Z',
  })
  createdAt!: Date;

  @ApiProperty({
    description: 'Fecha de última actualización del registro',
    example: '2026-11-04T08:35:00.000Z',
  })
  updatedAt!: Date;

  static calculateTotals(
    items: Array<Pick<MealItemEntity, 'kcal' | 'proteinG' | 'carbsG' | 'fatG'>>,
  ): MacroTotalsDto {
    const round2 = (value: number): number => Math.round(value * 100) / 100;
    const raw = items.reduce(
      (acc, item) => ({
        kcal: acc.kcal + item.kcal,
        proteinG: acc.proteinG + item.proteinG,
        carbsG: acc.carbsG + item.carbsG,
        fatG: acc.fatG + item.fatG,
      }),
      { kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 },
    );

    return {
      kcal: round2(raw.kcal),
      proteinG: round2(raw.proteinG),
      carbsG: round2(raw.carbsG),
      fatG: round2(raw.fatG),
    };
  }

  static fromEntity(
    meal: MealLog & { items?: MealItemEntity[] },
  ): MealResponseDto {
    const dto = new MealResponseDto();
    dto.id = meal.id;
    dto.userId = meal.userId;
    dto.eatenAt = meal.eatenAt;
    dto.mealType = meal.mealType;
    dto.notes = meal.notes;
    dto.photoId = meal.photoId;
    const rawItems = meal.items ?? [];
    dto.items = rawItems.map((item) => MealItemResponseDto.fromEntity(item));
    dto.totals = MealResponseDto.calculateTotals(rawItems);
    dto.createdAt = meal.createdAt;
    dto.updatedAt = meal.updatedAt;
    return dto;
  }
}
