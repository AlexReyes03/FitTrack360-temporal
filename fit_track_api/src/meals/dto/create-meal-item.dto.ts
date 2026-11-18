import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateMealItemDto {
  @ApiProperty({
    description: 'Nombre del alimento consumido',
    example: 'Pechuga de pollo asada',
  })
  @IsNotEmpty({ message: 'name es obligatorio' })
  @IsString({ message: 'name debe ser una cadena de texto' })
  name!: string;

  @ApiPropertyOptional({
    description: 'Identificador opcional en USDA FoodData Central (FDC)',
    example: '171077',
  })
  @IsOptional()
  @IsString({ message: 'fdcId debe ser una cadena de texto' })
  fdcId?: string;

  @ApiProperty({
    description: 'Tamaño de la porción en gramos (>= 0)',
    example: 150,
    minimum: 0,
  })
  @IsNumber({}, { message: 'servingG debe ser un número válido' })
  @Min(0, { message: 'servingG debe ser un número no negativo' })
  servingG!: number;

  @ApiProperty({
    description: 'Calorías totales de la porción en kcal (>= 0)',
    example: 247.5,
    minimum: 0,
  })
  @IsNumber({}, { message: 'kcal debe ser un número válido' })
  @Min(0, { message: 'kcal debe ser un número no negativo' })
  kcal!: number;

  @ApiProperty({
    description: 'Proteínas en gramos (>= 0)',
    example: 46.5,
    minimum: 0,
  })
  @IsNumber({}, { message: 'proteinG debe ser un número válido' })
  @Min(0, { message: 'proteinG debe ser un número no negativo' })
  proteinG!: number;

  @ApiProperty({
    description: 'Carbohidratos en gramos (>= 0)',
    example: 0,
    minimum: 0,
  })
  @IsNumber({}, { message: 'carbsG debe ser un número válido' })
  @Min(0, { message: 'carbsG debe ser un número no negativo' })
  carbsG!: number;

  @ApiProperty({
    description: 'Grasas en gramos (>= 0)',
    example: 5.4,
    minimum: 0,
  })
  @IsNumber({}, { message: 'fatG debe ser un número válido' })
  @Min(0, { message: 'fatG debe ser un número no negativo' })
  fatG!: number;
}
