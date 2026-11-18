import type { BodyMetric } from '@prisma/client';
import { BodyMetricResponseDto } from './body-metric-response.dto';

export class LatestBodyMetricResponseDto {
  metric!: BodyMetricResponseDto | null;
}

export class ProgressSeriesPointDto {
  id!: string;
  date!: string;
  measuredAt!: string;
  weightKg!: number | null;
  bodyFatPercent!: number | null;
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
  from!: string | null;
  to!: string | null;
  count!: number;
  latest!: BodyMetricResponseDto | null;
  points!: ProgressSeriesPointDto[];
}
