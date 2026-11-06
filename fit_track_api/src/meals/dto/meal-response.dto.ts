import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MealType, type MealLog } from '@prisma/client';

export class MealResponseDto {
  @ApiProperty({
    description: 'Identificador único UUID del registro de comida',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  id!: string;

  @ApiProperty({
    description: 'Identificador UUID del usuario propietario del registro',
    example: 'e2b3c4d5-6789-4abc-def0-123456789abc',
  })
  userId!: string;

  @ApiProperty({
    description:
      'Fecha y hora en que se consumió la comida en formato ISO 8601',
    example: '2026-11-04T08:30:00.000Z',
  })
  eatenAt!: Date;

  @ApiProperty({
    description: 'Tipo de comida registrado',
    enum: MealType,
    example: MealType.BREAKFAST,
  })
  mealType!: MealType;

  @ApiPropertyOptional({
    description: 'Notas u observaciones personales sobre la comida',
    example: 'Tazón de avena con frutas y frutos secos.',
    nullable: true,
  })
  notes!: string | null;

  @ApiPropertyOptional({
    description: 'Identificador de la fotografía asociada a la comida',
    example: 'photo-12345',
    nullable: true,
  })
  photoId!: string | null;

  @ApiProperty({
    description: 'Fecha de creación del registro en el sistema',
    example: '2026-11-04T08:30:00.000Z',
  })
  createdAt!: Date;

  @ApiProperty({
    description: 'Fecha de última actualización del registro',
    example: '2026-11-04T08:35:00.000Z',
  })
  updatedAt!: Date;

  static fromEntity(meal: MealLog): MealResponseDto {
    const dto = new MealResponseDto();
    dto.id = meal.id;
    dto.userId = meal.userId;
    dto.eatenAt = meal.eatenAt;
    dto.mealType = meal.mealType;
    dto.notes = meal.notes;
    dto.photoId = meal.photoId;
    dto.createdAt = meal.createdAt;
    dto.updatedAt = meal.updatedAt;
    return dto;
  }
}
