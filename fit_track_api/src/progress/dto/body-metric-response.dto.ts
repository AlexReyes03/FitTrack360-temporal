import type { BodyMetric } from '@prisma/client';

export class BodyMetricResponseDto {
  id!: string;
  userId!: string;
  measuredAt!: string;
  weightKg!: number | null;
  bodyFatPercent!: number | null;
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
