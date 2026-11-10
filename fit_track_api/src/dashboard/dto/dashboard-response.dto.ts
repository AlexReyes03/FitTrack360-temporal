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

  @ApiProperty({ type: NutrientsDto })
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

export class DashboardTodayDto {
  @ApiProperty({ example: '2026-11-10' })
  date!: string;

  @ApiProperty({ example: -360 })
  utcOffsetMinutes!: number;

  @ApiProperty({ type: DayNutritionDto })
  nutrition!: DayNutritionDto;

  @ApiPropertyOptional({ type: DaySessionDto, nullable: true })
  session!: DaySessionDto | null;

  @ApiProperty({
    nullable: true,
    type: Object,
    description:
      'Última métrica corporal. Siempre null hasta que exista el módulo de progreso (#122)',
  })
  latestMetric!: null;
}
