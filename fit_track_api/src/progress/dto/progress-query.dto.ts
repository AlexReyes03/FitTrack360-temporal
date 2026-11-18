import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional } from 'class-validator';

export class ProgressRangeQueryDto {
  @ApiPropertyOptional({
    description:
      'Fecha inicial opcional en formato ISO 8601 (YYYY-MM-DD o date-time) para filtrar el historial o la serie',
    example: '2026-10-01',
  })
  @IsOptional()
  @IsDateString({}, { message: 'from debe ser una fecha ISO 8601 válida' })
  from?: string;

  @ApiPropertyOptional({
    description:
      'Fecha final opcional en formato ISO 8601 (YYYY-MM-DD o date-time) para filtrar el historial o la serie',
    example: '2026-11-10',
  })
  @IsOptional()
  @IsDateString({}, { message: 'to debe ser una fecha ISO 8601 válida' })
  to?: string;
}
