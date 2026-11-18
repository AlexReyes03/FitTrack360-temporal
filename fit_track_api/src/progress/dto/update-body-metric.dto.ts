import { IsDateString, IsNumber, IsOptional } from 'class-validator';

export class UpdateBodyMetricDto {
  @IsOptional()
  @IsDateString(
    {},
    { message: 'measuredAt debe ser una fecha ISO 8601 válida' },
  )
  measuredAt?: string;

  @IsOptional()
  @IsNumber({}, { message: 'weightKg debe ser un número válido' })
  weightKg?: number;

  @IsOptional()
  @IsNumber({}, { message: 'bodyFatPercent debe ser un número válido' })
  bodyFatPercent?: number | null;

  @IsOptional()
  @IsNumber({}, { message: 'waistCm debe ser un número válido' })
  waistCm?: number | null;
}
