import { IsDateString, IsOptional } from 'class-validator';

export class ProgressRangeQueryDto {
  @IsOptional()
  @IsDateString({}, { message: 'from debe ser una fecha ISO 8601 válida' })
  from?: string;

  @IsOptional()
  @IsDateString({}, { message: 'to debe ser una fecha ISO 8601 válida' })
  to?: string;
}
