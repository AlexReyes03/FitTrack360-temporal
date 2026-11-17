import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class FoodSearchQueryDto {
  @ApiProperty({
    description:
      'Término de búsqueda contra USDA FoodData Central. El catálogo está en inglés. Vacío o mayor a 120 caracteres responde 400 y Flutter abre captura manual.',
    example: 'oats',
    maxLength: 120,
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString({ message: 'q debe ser una cadena de texto' })
  @IsNotEmpty({ message: 'q es obligatorio para la búsqueda de alimentos' })
  @MaxLength(120, { message: 'q no puede exceder 120 caracteres' })
  q!: string;
}
