import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class CreateWorkoutSetDto {
  @ApiProperty({
    description: 'Identificador del ejercicio en el catálogo (ej. 0001)',
    example: '0001',
  })
  @IsNotEmpty({ message: 'exerciseId es obligatorio' })
  @IsString({ message: 'exerciseId debe ser una cadena de texto' })
  exerciseId!: string;

  @ApiProperty({
    description: 'Orden de la serie dentro de la sesión, empezando en 1',
    example: 1,
    minimum: 1,
  })
  @IsInt({ message: 'order debe ser un número entero' })
  @Min(1, { message: 'order debe ser mayor o igual a 1' })
  order!: number;

  @ApiProperty({
    description: 'Peso movilizado en kilogramos. Cero representa sin carga.',
    example: 80,
    minimum: 0,
  })
  @IsNumber({}, { message: 'weight debe ser un número válido' })
  @Min(0, { message: 'weight debe ser un número no negativo' })
  weight!: number;

  @ApiProperty({
    description: 'Repeticiones ejecutadas en la serie',
    example: 10,
    minimum: 1,
  })
  @IsInt({ message: 'reps debe ser un número entero' })
  @Min(1, { message: 'reps debe ser mayor o igual a 1' })
  reps!: number;

  @ApiPropertyOptional({
    description: 'Esfuerzo percibido RPE opcional, de 1 a 10',
    example: 8,
    minimum: 1,
    maximum: 10,
  })
  @IsOptional()
  @IsNumber({}, { message: 'rpe debe ser un número válido' })
  @Min(1, { message: 'rpe debe ser mayor o igual a 1' })
  @Max(10, { message: 'rpe no puede exceder 10' })
  rpe?: number;

  @ApiPropertyOptional({
    description: 'Repeticiones en reserva RIR opcionales, de 0 a 10',
    example: 2,
    minimum: 0,
    maximum: 10,
  })
  @IsOptional()
  @IsInt({ message: 'rir debe ser un número entero' })
  @Min(0, { message: 'rir debe ser un número no negativo' })
  @Max(10, { message: 'rir no puede exceder 10' })
  rir?: number;
}
