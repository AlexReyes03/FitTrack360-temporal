import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsDateString, IsNumber, IsOptional, Max, Min } from 'class-validator';

export class CreateMetricDto {
  @ApiProperty({ description: 'Momento de la medición en ISO 8601' })
  @IsDateString()
  measuredAt!: string;

  @ApiPropertyOptional({ description: 'Peso en kilogramos', example: 78.5 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(500)
  weightKg?: number;

  @ApiPropertyOptional({
    description: 'Porcentaje de grasa corporal',
    example: 18.2,
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  bodyFatPercent?: number;

  @ApiPropertyOptional({ description: 'Cintura en centímetros', example: 82 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(300)
  waistCm?: number;
}

export class UpdateMetricDto extends PartialType(CreateMetricDto) {}

export class MetricResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  userId!: string;

  @ApiProperty()
  measuredAt!: Date;

  @ApiPropertyOptional({ nullable: true })
  weightKg!: number | null;

  @ApiPropertyOptional({ nullable: true })
  bodyFatPercent!: number | null;

  @ApiPropertyOptional({ nullable: true })
  waistCm!: number | null;

  static from(row: {
    id: string;
    userId: string;
    measuredAt: Date;
    weightKg: number | null;
    bodyFatPercent: number | null;
    waistCm: number | null;
  }): MetricResponseDto {
    const dto = new MetricResponseDto();
    dto.id = row.id;
    dto.userId = row.userId;
    dto.measuredAt = row.measuredAt;
    dto.weightKg = row.weightKg;
    dto.bodyFatPercent = row.bodyFatPercent;
    dto.waistCm = row.waistCm;
    return dto;
  }
}
