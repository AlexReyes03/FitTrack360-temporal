import {
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
} from 'class-validator';

export class CreateBodyMetricDto {
  @IsNotEmpty({ message: 'measuredAt es obligatorio' })
  @IsDateString(
    {},
    { message: 'measuredAt debe ser una fecha ISO 8601 válida' },
  )
  measuredAt!: string;

  @IsNumber({}, { message: 'weightKg debe ser un número válido' })
  weightKg!: number;

  @IsOptional()
  @IsNumber({}, { message: 'bodyFatPercent debe ser un número válido' })
  bodyFatPercent?: number;

  @IsOptional()
  @IsNumber({}, { message: 'waistCm debe ser un número válido' })
  waistCm?: number;
}
