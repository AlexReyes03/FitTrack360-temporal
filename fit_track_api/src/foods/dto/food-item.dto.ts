import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** Cuerpo 503. No incluye la API key ni la URL de USDA. */
export class UsdaUnavailableDto {
  @ApiProperty({ example: 'USDA_UNAVAILABLE' })
  code!: 'USDA_UNAVAILABLE';

  @ApiProperty({
    example: 'Servicio nutricional no disponible temporalmente',
  })
  message!: string;
}

/**
 * Alimento normalizado por 100 g. Flutter acepta este objeto dentro de un
 * arreglo o de `{ items }` y, si el HTTP no es 200, abre captura manual.
 */
export class FoodItemDto {
  @ApiProperty({
    description: 'Identificador en USDA FoodData Central',
    example: 173904,
  })
  fdcId!: number;

  @ApiProperty({
    description: 'Descripción del alimento en USDA FDC',
    example: 'Oats',
  })
  description!: string;

  @ApiProperty({
    description: 'Nombre mostrado. Coincide con description.',
    example: 'Oats',
  })
  name!: string;

  @ApiProperty({
    description: 'Porción de referencia en gramos. Los macros son por 100 g.',
    example: 100,
  })
  servingG!: number;

  @ApiProperty({
    description: 'Energía en kcal por 100 g (nutriente 1008)',
    example: 389,
  })
  kcal!: number;

  @ApiProperty({
    description: 'Proteína en gramos por 100 g (nutriente 1003)',
    example: 16.9,
  })
  proteinG!: number;

  @ApiProperty({
    description: 'Carbohidratos en gramos por 100 g (nutriente 1005)',
    example: 66.3,
  })
  carbsG!: number;

  @ApiProperty({
    description: 'Grasa total en gramos por 100 g (nutriente 1004)',
    example: 6.9,
  })
  fatG!: number;

  @ApiPropertyOptional({
    description: 'Marca, solo si USDA la trae en alimentos branded',
    example: null,
    nullable: true,
  })
  brandOwner?: string | null;
}
