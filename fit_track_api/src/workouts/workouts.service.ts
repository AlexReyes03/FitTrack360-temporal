import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateWorkoutDto } from './dto/create-workout.dto';
import { UpdateWorkoutDto } from './dto/update-workout.dto';
import { WorkoutResponseDto } from './dto/workout-response.dto';

@Injectable()
export class WorkoutsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    userId: string,
    dto: CreateWorkoutDto,
  ): Promise<WorkoutResponseDto> {
    const session = await this.prisma.workoutSession.create({
      data: {
        userId,
        startedAt: new Date(dto.startedAt),
        endedAt: dto.endedAt ? new Date(dto.endedAt) : null,
        notes: dto.notes ?? null,
      },
    });

    return WorkoutResponseDto.fromEntity(session);
  }

  async findAll(userId: string): Promise<WorkoutResponseDto[]> {
    const sessions = await this.prisma.workoutSession.findMany({
      where: { userId },
      orderBy: { startedAt: 'desc' },
    });

    return sessions.map((s) => WorkoutResponseDto.fromEntity(s));
  }

  async findOne(userId: string, id: string): Promise<WorkoutResponseDto> {
    const session = await this.prisma.workoutSession.findFirst({
      where: { id, userId },
    });

    if (!session) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada');
    }

    return WorkoutResponseDto.fromEntity(session);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateWorkoutDto,
  ): Promise<WorkoutResponseDto> {
    const existing = await this.prisma.workoutSession.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada');
    }

    const updated = await this.prisma.workoutSession.update({
      where: { id },
      data: {
        startedAt: dto.startedAt ? new Date(dto.startedAt) : undefined,
        endedAt:
          dto.endedAt !== undefined
            ? dto.endedAt
              ? new Date(dto.endedAt)
              : null
            : undefined,
        notes: dto.notes !== undefined ? dto.notes : undefined,
      },
    });

    return WorkoutResponseDto.fromEntity(updated);
  }

  async remove(userId: string, id: string): Promise<void> {
    const existing = await this.prisma.workoutSession.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada');
    }

    await this.prisma.workoutSession.delete({
      where: { id },
    });
  }
}
