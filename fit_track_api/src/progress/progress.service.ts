import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateMetricDto,
  MetricResponseDto,
  UpdateMetricDto,
} from './dto/metric.dto';

@Injectable()
export class ProgressService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    userId: string,
    dto: CreateMetricDto,
  ): Promise<MetricResponseDto> {
    const row = await this.prisma.bodyMetric.create({
      data: {
        userId,
        measuredAt: new Date(dto.measuredAt),
        weightKg: dto.weightKg ?? null,
        bodyFatPercent: dto.bodyFatPercent ?? null,
        waistCm: dto.waistCm ?? null,
      },
    });
    return MetricResponseDto.from(row);
  }

  async findAll(userId: string): Promise<MetricResponseDto[]> {
    const rows = await this.prisma.bodyMetric.findMany({
      where: { userId },
      orderBy: { measuredAt: 'desc' },
    });
    return rows.map((row) => MetricResponseDto.from(row));
  }

  async findOne(userId: string, id: string): Promise<MetricResponseDto> {
    return MetricResponseDto.from(await this.owned(userId, id));
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateMetricDto,
  ): Promise<MetricResponseDto> {
    await this.owned(userId, id);
    const row = await this.prisma.bodyMetric.update({
      where: { id },
      data: {
        measuredAt:
          dto.measuredAt !== undefined ? new Date(dto.measuredAt) : undefined,
        weightKg: dto.weightKg,
        bodyFatPercent: dto.bodyFatPercent,
        waistCm: dto.waistCm,
      },
    });
    return MetricResponseDto.from(row);
  }

  async remove(userId: string, id: string): Promise<void> {
    await this.owned(userId, id);
    await this.prisma.bodyMetric.delete({ where: { id } });
  }

  private async owned(userId: string, id: string) {
    const row = await this.prisma.bodyMetric.findFirst({
      where: { id, userId },
    });
    if (!row) {
      throw new NotFoundException('Métrica no encontrada');
    }
    return row;
  }
}
