import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BodyMetricResponseDto } from './dto/body-metric-response.dto';
import { CreateBodyMetricDto } from './dto/create-body-metric.dto';
import { ProgressRangeQueryDto } from './dto/progress-query.dto';
import {
  LatestBodyMetricResponseDto,
  ProgressSeriesPointDto,
  ProgressSeriesResponseDto,
} from './dto/progress-series-response.dto';
import { UpdateBodyMetricDto } from './dto/update-body-metric.dto';

interface ResolvedDateRange {
  from?: Date;
  to?: Date;
}

@Injectable()
export class ProgressService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    userId: string,
    dto: CreateBodyMetricDto,
  ): Promise<BodyMetricResponseDto> {
    const metric = await this.prisma.bodyMetric.create({
      data: {
        userId,
        measuredAt: new Date(dto.measuredAt),
        weightKg: dto.weightKg,
        bodyFatPercent: dto.bodyFatPercent ?? null,
        waistCm: dto.waistCm ?? null,
      },
    });

    return BodyMetricResponseDto.fromEntity(metric);
  }

  async findAll(
    userId: string,
    query: ProgressRangeQueryDto = {},
  ): Promise<BodyMetricResponseDto[]> {
    const range = this.resolveDateRange(query);

    const metrics = await this.prisma.bodyMetric.findMany({
      where: {
        userId,
        measuredAt: this.buildMeasuredAtFilter(range),
      },
      orderBy: { measuredAt: 'desc' },
    });

    return metrics.map((metric) => BodyMetricResponseDto.fromEntity(metric));
  }

  async findLatest(userId: string): Promise<LatestBodyMetricResponseDto> {
    const metric = await this.prisma.bodyMetric.findFirst({
      where: { userId },
      orderBy: { measuredAt: 'desc' },
    });

    return {
      metric: metric ? BodyMetricResponseDto.fromEntity(metric) : null,
    };
  }

  async getSeries(
    userId: string,
    query: ProgressRangeQueryDto = {},
  ): Promise<ProgressSeriesResponseDto> {
    const range = this.resolveDateRange(query);

    const metrics = await this.prisma.bodyMetric.findMany({
      where: {
        userId,
        measuredAt: this.buildMeasuredAtFilter(range),
      },
      orderBy: { measuredAt: 'asc' },
    });

    const points = metrics.map((metric) =>
      ProgressSeriesPointDto.fromEntity(metric),
    );
    const lastEntity = metrics.length > 0 ? metrics[metrics.length - 1] : null;

    return {
      from: range.from ? range.from.toISOString() : null,
      to: range.to ? range.to.toISOString() : null,
      count: points.length,
      latest: lastEntity ? BodyMetricResponseDto.fromEntity(lastEntity) : null,
      points,
    };
  }

  async findOne(userId: string, id: string): Promise<BodyMetricResponseDto> {
    const metric = await this.prisma.bodyMetric.findFirst({
      where: { id, userId },
    });

    if (!metric) {
      throw new NotFoundException('Métrica corporal no encontrada');
    }

    return BodyMetricResponseDto.fromEntity(metric);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateBodyMetricDto,
  ): Promise<BodyMetricResponseDto> {
    const existing = await this.prisma.bodyMetric.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Métrica corporal no encontrada');
    }

    const updated = await this.prisma.bodyMetric.update({
      where: { id },
      data: {
        measuredAt:
          dto.measuredAt !== undefined ? new Date(dto.measuredAt) : undefined,
        weightKg: dto.weightKg !== undefined ? dto.weightKg : undefined,
        bodyFatPercent:
          dto.bodyFatPercent !== undefined ? dto.bodyFatPercent : undefined,
        waistCm: dto.waistCm !== undefined ? dto.waistCm : undefined,
      },
    });

    return BodyMetricResponseDto.fromEntity(updated);
  }

  async remove(userId: string, id: string): Promise<void> {
    const existing = await this.prisma.bodyMetric.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Métrica corporal no encontrada');
    }

    await this.prisma.bodyMetric.delete({
      where: { id },
    });
  }

  private resolveDateRange(query: ProgressRangeQueryDto): ResolvedDateRange {
    let fromDate: Date | undefined;
    let toDate: Date | undefined;

    if (query.from) {
      fromDate = new Date(query.from);
      if (Number.isNaN(fromDate.getTime())) {
        throw new BadRequestException('Fecha inicial (from) inválida');
      }
      if (!query.from.includes('T')) {
        fromDate.setUTCHours(0, 0, 0, 0);
      }
    }

    if (query.to) {
      toDate = new Date(query.to);
      if (Number.isNaN(toDate.getTime())) {
        throw new BadRequestException('Fecha final (to) inválida');
      }
      if (!query.to.includes('T')) {
        toDate.setUTCHours(23, 59, 59, 999);
      }
    }

    if (fromDate && toDate && fromDate > toDate) {
      throw new BadRequestException(
        'La fecha inicial (from) no puede ser posterior a la fecha final (to)',
      );
    }

    return { from: fromDate, to: toDate };
  }

  private buildMeasuredAtFilter(
    range: ResolvedDateRange,
  ): { gte?: Date; lte?: Date } | undefined {
    if (!range.from && !range.to) {
      return undefined;
    }

    return {
      ...(range.from ? { gte: range.from } : {}),
      ...(range.to ? { lte: range.to } : {}),
    };
  }
}
