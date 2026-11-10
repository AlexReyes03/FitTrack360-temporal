import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Matches, Max, Min } from 'class-validator';
import { UTC_OFFSET_MAX, UTC_OFFSET_MIN } from '../domain/day-summary';

/** Query de GET /dashboard/today. */
export class DashboardQueryDto {
  @ApiPropertyOptional({
    example: '2026-11-10',
    description: 'Día local del usuario; por defecto, hoy en utcOffsetMinutes',
  })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date debe ser YYYY-MM-DD' })
  date?: string;

  @ApiPropertyOptional({
    example: -360,
    default: 0,
    minimum: UTC_OFFSET_MIN,
    maximum: UTC_OFFSET_MAX,
    description:
      'Desplazamiento del reloj del usuario respecto de UTC, en minutos (UTC-6 = -360)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(UTC_OFFSET_MIN)
  @Max(UTC_OFFSET_MAX)
  utcOffsetMinutes?: number;
}
