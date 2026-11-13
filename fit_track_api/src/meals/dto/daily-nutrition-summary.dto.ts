import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MealType } from '@prisma/client';
import { IsDateString, IsOptional } from 'class-validator';
import { MacroTotalsDto } from './meal-response.dto';

export class DailySummaryQueryDto {
  @ApiPropertyOptional({
    description:
      'Fecha específica en formato ISO 8601 (YYYY-MM-DD) para consultar el resumen del día',
    example: '2026-11-04',
  })
  @IsOptional()
  @IsDateString({}, { message: 'date debe ser una fecha ISO 8601 válida' })
  date?: string;

  @ApiPropertyOptional({
    description: 'Fecha inicial opcional en formato ISO 8601 para rango',
    example: '2026-11-04T00:00:00.000Z',
  })
  @IsOptional()
  @IsDateString({}, { message: 'from debe ser una fecha ISO 8601 válida' })
  from?: string;

  @ApiPropertyOptional({
    description: 'Fecha final opcional en formato ISO 8601 para rango',
    example: '2026-11-04T23:59:59.999Z',
  })
  @IsOptional()
  @IsDateString({}, { message: 'to debe ser una fecha ISO 8601 válida' })
  to?: string;
}

export class MealTypeMacroBreakdownDto extends MacroTotalsDto {
  @ApiProperty({
    description: 'Cantidad de registros de comida en este tiempo de alimento',
    example: 1,
  })
  mealsCount!: number;

  @ApiProperty({
    description: 'Cantidad de alimentos registrados en este tiempo de alimento',
    example: 2,
  })
  itemsCount!: number;
}

export class DailyNutritionSummaryDto {
  @ApiProperty({
    description: 'Fecha de referencia del resumen (YYYY-MM-DD)',
    example: '2026-11-04',
  })
  date!: string;

  @ApiProperty({
    description: 'Inicio del intervalo consultado en UTC ISO 8601',
    example: '2026-11-04T00:00:00.000Z',
  })
  from!: string;

  @ApiProperty({
    description: 'Fin del intervalo consultado en UTC ISO 8601',
    example: '2026-11-04T23:59:59.999Z',
  })
  to!: string;

  @ApiProperty({
    description: 'Totales acumulados del día o rango consultado',
    type: MacroTotalsDto,
  })
  totals!: MacroTotalsDto;

  @ApiProperty({
    description:
      'Desglose de macronutrientes agrupado por tipo de comida (BREAKFAST, LUNCH, DINNER, SNACK)',
  })
  byMealType!: Record<MealType, MealTypeMacroBreakdownDto>;
}
