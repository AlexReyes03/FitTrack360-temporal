import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type { BodyMetric } from '@prisma/client';

export class BodyMetricResponseDto {
  @ApiProperty({
    description: 'Identificador único UUID de la medición biométrica',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  id!: string;

  @ApiProperty({
    description: 'Identificador UUID del usuario propietario de la medición',
    example: 'e2b3c4d5-6789-4abc-def0-123456789abc',
  })
  userId!: string;

  @ApiProperty({
    description: 'Fecha y hora de la medición en formato ISO 8601',
    example: '2026-11-10T07:30:00.000Z',
    format: 'date-time',
  })
  measuredAt!: string;

  @ApiPropertyOptional({
    description: 'Peso corporal registrado en kilogramos',
    example: 74.5,
    nullable: true,
    type: Number,
  })
  weightKg!: number | null;

  @ApiPropertyOptional({
    description: 'Porcentaje de grasa corporal registrado',
    example: 18.2,
    nullable: true,
    type: Number,
  })
  bodyFatPercent!: number | null;

  @ApiPropertyOptional({
    description: 'Medida de cintura registrada en centímetros',
    example: 81.5,
    nullable: true,
    type: Number,
  })
  waistCm!: number | null;

  static fromEntity(metric: BodyMetric): BodyMetricResponseDto {
    const dto = new BodyMetricResponseDto();
    dto.id = metric.id;
    dto.userId = metric.userId;
    dto.measuredAt = metric.measuredAt.toISOString();
    dto.weightKg = metric.weightKg;
    dto.bodyFatPercent = metric.bodyFatPercent;
    dto.waistCm = metric.waistCm;
    return dto;
  }
}
