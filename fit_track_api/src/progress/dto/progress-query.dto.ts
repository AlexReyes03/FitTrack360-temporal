import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional } from 'class-validator';

/**
 * Filtros de rango para historial y series biométricas.
 * Nota: las fechas en formato solo-fecha (YYYY-MM-DD) operan en UTC
 * (from -> 00:00:00.000Z, to -> 23:59:59.999Z).
 */
export class ProgressRangeQueryDto {
  @ApiPropertyOptional({
    description:
      'Fecha inicial opcional en formato ISO 8601 (YYYY-MM-DD o date-time). El formato YYYY-MM-DD opera en UTC (inicio del día 00:00:00.000Z).',
    example: '2026-10-01',
  })
  @IsOptional()
  @IsDateString(
    { strict: true },
    { message: 'from debe ser una fecha ISO 8601 válida' },
  )
  from?: string;

  @ApiPropertyOptional({
    description:
      'Fecha final opcional en formato ISO 8601 (YYYY-MM-DD o date-time). El formato YYYY-MM-DD opera en UTC (fin del día 23:59:59.999Z).',
    example: '2026-11-10',
  })
  @IsOptional()
  @IsDateString(
    { strict: true },
    { message: 'to debe ser una fecha ISO 8601 válida' },
  )
  to?: string;
}
