import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type { BodyMetric } from '@prisma/client';
import { BodyMetricResponseDto } from './body-metric-response.dto';

export class LatestBodyMetricResponseDto {
  @ApiPropertyOptional({
    description:
      'Última métrica biométrica registrada por el usuario, o null si aún no tiene registros',
    type: BodyMetricResponseDto,
    nullable: true,
  })
  metric!: BodyMetricResponseDto | null;
}

export class ProgressSeriesPointDto {
  @ApiProperty({
    description: 'Identificador UUID de la medición',
    example: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  })
  id!: string;

  @ApiProperty({
    description:
      'Fecha calendario en UTC (YYYY-MM-DD) lista para etiquetar ejes en Flutter',
    example: '2026-11-10',
  })
  date!: string;

  @ApiProperty({
    description: 'Marca temporal exacta de la medición en formato ISO 8601',
    example: '2026-11-10T07:30:00.000Z',
    format: 'date-time',
  })
  measuredAt!: string;

  @ApiPropertyOptional({
    description: 'Peso corporal en kilogramos',
    example: 74.5,
    nullable: true,
    type: Number,
  })
  weightKg!: number | null;

  @ApiPropertyOptional({
    description: 'Porcentaje de grasa corporal',
    example: 18.2,
    nullable: true,
    type: Number,
  })
  bodyFatPercent!: number | null;

  @ApiPropertyOptional({
    description: 'Medida de cintura en centímetros',
    example: 81.5,
    nullable: true,
    type: Number,
  })
  waistCm!: number | null;

  static fromEntity(metric: BodyMetric): ProgressSeriesPointDto {
    const iso = metric.measuredAt.toISOString();
    const point = new ProgressSeriesPointDto();
    point.id = metric.id;
    point.date = iso.slice(0, 10);
    point.measuredAt = iso;
    point.weightKg = metric.weightKg;
    point.bodyFatPercent = metric.bodyFatPercent;
    point.waistCm = metric.waistCm;
    return point;
  }
}

export class ProgressSeriesResponseDto {
  @ApiPropertyOptional({
    description:
      'Inicio del rango aplicado en ISO 8601, o null si no se filtró',
    example: '2026-10-01T00:00:00.000Z',
    nullable: true,
    type: String,
  })
  from!: string | null;

  @ApiPropertyOptional({
    description: 'Fin del rango aplicado en ISO 8601, o null si no se filtró',
    example: '2026-11-10T23:59:59.999Z',
    nullable: true,
    type: String,
  })
  to!: string | null;

  @ApiProperty({
    description: 'Cantidad total de puntos incluidos en la serie',
    example: 3,
  })
  count!: number;

  @ApiPropertyOptional({
    description:
      'Última medición dentro del rango consultado, o null si está vacío',
    type: BodyMetricResponseDto,
    nullable: true,
  })
  latest!: BodyMetricResponseDto | null;

  @ApiProperty({
    description:
      'Puntos biométricos ordenados cronológicamente (ascendente) listos para graficar en Flutter',
    type: [ProgressSeriesPointDto],
  })
  points!: ProgressSeriesPointDto[];
}
