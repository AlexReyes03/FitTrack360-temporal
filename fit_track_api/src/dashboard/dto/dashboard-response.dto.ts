import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { UserGoalsDto } from '../../users/dto/user-response.dto';

/** Calorías (kcal) y macros (g) consumidos o restantes. */
export class NutrientsDto {
  @ApiProperty({ example: 0 })
  calories!: number;

  @ApiProperty({ example: 0 })
  proteinG!: number;

  @ApiProperty({ example: 0 })
  carbsG!: number;

  @ApiProperty({ example: 0 })
  fatG!: number;
}

export class DayNutritionDto {
  @ApiProperty({ description: 'Comidas registradas en el día' })
  mealsLogged!: number;

  @ApiProperty({
    type: NutrientsDto,
    description:
      'Suma de los MealItem (macros congelados) de las comidas del día, a 2 decimales',
  })
  consumed!: NutrientsDto;

  @ApiProperty({ type: UserGoalsDto })
  goals!: UserGoalsDto;

  @ApiProperty({
    type: NutrientsDto,
    description: 'Meta menos consumido; negativo si se excedió la meta',
  })
  remaining!: NutrientsDto;
}

/** Sesión realizada hoy, o la última registrada. Nunca una rutina planeada. */
export class DaySessionDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ format: 'date-time' })
  startedAt!: string;

  @ApiProperty({ format: 'date-time', nullable: true, type: String })
  endedAt!: string | null;

  @ApiProperty({ nullable: true, type: String })
  notes!: string | null;

  @ApiProperty({ description: 'true si la sesión empezó en el día consultado' })
  isToday!: boolean;
}

/** Última métrica corporal (BodyMetric) medida hasta el día consultado. */
export class LatestMetricDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ format: 'date-time' })
  measuredAt!: string;

  @ApiProperty({ nullable: true, type: Number, example: 71.8 })
  weightKg!: number | null;

  @ApiProperty({ nullable: true, type: Number, example: 18.5 })
  bodyFatPercent!: number | null;

  @ApiProperty({ nullable: true, type: Number, example: 82 })
  waistCm!: number | null;
}

export class DashboardTodayDto {
  @ApiProperty({ example: '2026-11-10' })
  date!: string;

  @ApiProperty({ example: -360 })
  utcOffsetMinutes!: number;

  @ApiProperty({ type: DayNutritionDto })
  nutrition!: DayNutritionDto;

  @ApiPropertyOptional({ type: DaySessionDto, nullable: true })
  session!: DaySessionDto | null;

  @ApiPropertyOptional({
    type: LatestMetricDto,
    nullable: true,
    description:
      'Última BodyMetric del usuario medida antes del fin del día; null si no hay',
  })
  latestMetric!: LatestMetricDto | null;
}
