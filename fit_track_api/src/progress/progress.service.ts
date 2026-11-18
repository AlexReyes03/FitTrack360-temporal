import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BodyMetricResponseDto } from './dto/body-metric-response.dto';
import { CreateBodyMetricDto } from './dto/create-body-metric.dto';
import { UpdateBodyMetricDto } from './dto/update-body-metric.dto';

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

  async findAll(userId: string): Promise<BodyMetricResponseDto[]> {
    const metrics = await this.prisma.bodyMetric.findMany({
      where: { userId },
      orderBy: { measuredAt: 'desc' },
    });

    return metrics.map((metric) => BodyMetricResponseDto.fromEntity(metric));
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
}
