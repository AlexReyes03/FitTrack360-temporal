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
import { isFutureDate } from './validators/not-future-date.validator';

interface ResolvedDateRange {
  from?: Date;
  to?: Date;
}

const MAX_PROGRESS_RECORDS = 1000;

/** Solo-fecha YYYY-MM-DD; se interpreta y normaliza a límites de día en UTC. */
const DATE_ONLY_REGEX = /^\d{4}-\d{2}-\d{2}$/;

@Injectable()
export class ProgressService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    userId: string,
    dto: CreateBodyMetricDto,
  ): Promise<BodyMetricResponseDto> {
    const measuredAt = this.parseAndValidateMeasuredAt(dto.measuredAt);
    this.validateBiometricValues({
      weightKg: dto.weightKg,
      bodyFatPercent: dto.bodyFatPercent,
      waistCm: dto.waistCm,
    });

    const metric = await this.prisma.bodyMetric.create({
      data: {
        userId,
        measuredAt,
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
      take: MAX_PROGRESS_RECORDS,
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
      take: MAX_PROGRESS_RECORDS,
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
    const measuredAt =
      dto.measuredAt !== undefined
        ? this.parseAndValidateMeasuredAt(dto.measuredAt)
        : undefined;

    this.validateBiometricValues({
      weightKg: dto.weightKg,
      bodyFatPercent: dto.bodyFatPercent,
      waistCm: dto.waistCm,
    });

    const existing = await this.prisma.bodyMetric.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Métrica corporal no encontrada');
    }

    const updated = await this.prisma.bodyMetric.update({
      where: { id },
      data: {
        measuredAt,
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

  private parseAndValidateMeasuredAt(rawDate: unknown): Date {
    if (typeof rawDate !== 'string' || !rawDate.trim()) {
      throw new BadRequestException(
        'measuredAt debe ser una fecha ISO 8601 válida',
      );
    }

    const parsed = new Date(rawDate);
    if (Number.isNaN(parsed.getTime())) {
      throw new BadRequestException(
        'measuredAt debe ser una fecha ISO 8601 válida',
      );
    }
    if (isFutureDate(parsed)) {
      throw new BadRequestException('measuredAt no puede ser una fecha futura');
    }
    return parsed;
  }

  private validateBiometricValues(values: {
    weightKg?: number;
    bodyFatPercent?: number | null;
    waistCm?: number | null;
  }): void {
    if (
      values.weightKg !== undefined &&
      (typeof values.weightKg !== 'number' ||
        !Number.isFinite(values.weightKg) ||
        values.weightKg <= 0)
    ) {
      throw new BadRequestException(
        'weightKg debe ser estrictamente mayor a 0',
      );
    }

    if (
      values.bodyFatPercent !== undefined &&
      values.bodyFatPercent !== null &&
      (typeof values.bodyFatPercent !== 'number' ||
        !Number.isFinite(values.bodyFatPercent) ||
        values.bodyFatPercent < 0 ||
        values.bodyFatPercent > 100)
    ) {
      throw new BadRequestException('bodyFatPercent debe estar entre 0 y 100');
    }

    if (
      values.waistCm !== undefined &&
      values.waistCm !== null &&
      (typeof values.waistCm !== 'number' ||
        !Number.isFinite(values.waistCm) ||
        values.waistCm < 0)
    ) {
      throw new BadRequestException('waistCm debe ser mayor o igual a 0');
    }
  }

  /**
   * Resuelve el rango de fechas de consulta.
   * Las entradas en formato YYYY-MM-DD operan en UTC (inicio/fin del día).
   */
  private resolveDateRange(query: ProgressRangeQueryDto): ResolvedDateRange {
    let fromDate: Date | undefined;
    let toDate: Date | undefined;

    if (query.from) {
      fromDate = new Date(query.from);
      if (Number.isNaN(fromDate.getTime())) {
        throw new BadRequestException('Fecha inicial (from) inválida');
      }
      if (DATE_ONLY_REGEX.test(query.from)) {
        fromDate.setUTCHours(0, 0, 0, 0);
      }
    }

    if (query.to) {
      toDate = new Date(query.to);
      if (Number.isNaN(toDate.getTime())) {
        throw new BadRequestException('Fecha final (to) inválida');
      }
      if (DATE_ONLY_REGEX.test(query.to)) {
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
