import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import type { WorkoutSessionSnapshot } from './domain/workout-metrics';
import { CreateWorkoutSetDto } from './dto/create-workout-set.dto';
import { CreateWorkoutDto } from './dto/create-workout.dto';
import { UpdateWorkoutDto } from './dto/update-workout.dto';
import { WorkoutResponseDto } from './dto/workout-response.dto';

export interface NormalizedWorkoutSetInput {
  exerciseId: string;
  order: number;
  weight: number;
  reps: number;
  rpe: number | null;
  rir: number | null;
}

interface ExerciseRef {
  id: string;
  name: string;
}

interface StoredSet extends NormalizedWorkoutSetInput {
  id: string;
  sessionId: string;
  createdAt: Date;
  updatedAt: Date;
  exercise?: ExerciseRef | null;
}

interface StoredSession {
  id: string;
  userId: string;
  startedAt: Date;
  endedAt: Date | null;
  location: string | null;
  notes: string | null;
  routineId?: string | null;
  createdAt: Date;
  updatedAt: Date;
  sets?: StoredSet[];
}

// Se consultan como máximo las 1000 sesiones previas para calcular métricas.
const HISTORY_LIMIT = 1000;

const SETS_INCLUDE = {
  sets: {
    orderBy: { order: 'asc' as const },
    include: { exercise: { select: { id: true, name: true } } },
  },
};

@Injectable()
export class WorkoutsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    userId: string,
    dto: CreateWorkoutDto,
  ): Promise<WorkoutResponseDto> {
    if (dto.routineId) {
      const routine = await this.prisma.routine.findFirst({
        where: { id: dto.routineId, userId },
        select: { id: true },
      });
      if (!routine) throw new NotFoundException('Rutina no encontrada');
    }
    const startedAt = new Date(dto.startedAt);
    const endedAt = dto.endedAt ? new Date(dto.endedAt) : null;
    this.assertDateOrder(startedAt, endedAt);
    const sets = await this.prepareSets(dto.sets ?? []);

    const session = await this.sessions().create({
      data: {
        userId,
        routineId: dto.routineId ?? null,
        startedAt,
        endedAt,
        location: normalizeLocation(dto.location),
        notes: dto.notes ?? null,
        sets: sets.length > 0 ? { create: sets } : undefined,
      },
      include: SETS_INCLUDE,
    });

    return this.present(userId, session);
  }

  async findAll(userId: string): Promise<WorkoutResponseDto[]> {
    const sessions = await this.sessions().findMany({
      where: { userId },
      include: SETS_INCLUDE,
      orderBy: { startedAt: 'desc' },
    });
    const history = sessions
      .map(toSnapshot)
      .sort(
        (a, b) =>
          b.startedAt.getTime() - a.startedAt.getTime() ||
          b.createdAt.getTime() - a.createdAt.getTime(),
      );
    const result: WorkoutResponseDto[] = [];
    for (let start = 0; start < history.length;) {
      const current = history[start];
      let end = start + 1;
      while (
        end < history.length &&
        history[end].startedAt.getTime() === current.startedAt.getTime() &&
        history[end].createdAt.getTime() === current.createdAt.getTime()
      ) {
        end++;
      }
      // Sesiones con ambas fechas iguales no son anteriores entre sí.
      const previous = history.slice(end, end + HISTORY_LIMIT);
      for (let index = start; index < end; index++) {
        result.push(WorkoutResponseDto.fromSnapshot(history[index], previous));
      }
      start = end;
    }
    return result;
  }

  async findOne(userId: string, id: string): Promise<WorkoutResponseDto> {
    const session = await this.sessions().findFirst({
      where: { id, userId },
      include: SETS_INCLUDE,
    });
    if (!session) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada');
    }
    return this.present(userId, session);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateWorkoutDto,
  ): Promise<WorkoutResponseDto> {
    const existing = await this.sessions().findFirst({
      where: { id, userId },
      include: SETS_INCLUDE,
    });
    if (!existing) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada');
    }

    const startedAt = dto.startedAt
      ? new Date(dto.startedAt)
      : existing.startedAt;
    const endedAt =
      dto.endedAt !== undefined
        ? dto.endedAt
          ? new Date(dto.endedAt)
          : null
        : existing.endedAt;
    this.assertDateOrder(startedAt, endedAt);

    const sets =
      dto.sets !== undefined ? await this.prepareSets(dto.sets) : undefined;

    const updated = await this.sessions().update({
      where: { id },
      data: {
        startedAt: dto.startedAt ? startedAt : undefined,
        endedAt: dto.endedAt !== undefined ? endedAt : undefined,
        location:
          dto.location !== undefined
            ? normalizeLocation(dto.location)
            : undefined,
        notes: dto.notes !== undefined ? dto.notes : undefined,
        sets: sets !== undefined ? { deleteMany: {}, create: sets } : undefined,
      },
      include: SETS_INCLUDE,
    });

    return this.present(userId, updated);
  }

  async remove(userId: string, id: string): Promise<void> {
    const existing = await this.sessions().findFirst({
      where: { id, userId },
    });
    if (!existing) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada');
    }
    await this.sessions().delete({ where: { id } });
  }

  private async present(
    userId: string,
    session: StoredSession,
  ): Promise<WorkoutResponseDto> {
    const history = await this.sessions().findMany({
      where: {
        userId,
        OR: [
          { startedAt: { lt: session.startedAt } },
          {
            startedAt: session.startedAt,
            createdAt: { lt: session.createdAt },
          },
        ],
      },
      include: SETS_INCLUDE,
      orderBy: [{ startedAt: 'desc' }, { createdAt: 'desc' }],
      take: HISTORY_LIMIT,
    });
    return WorkoutResponseDto.fromSnapshot(
      toSnapshot(session),
      history.map(toSnapshot),
    );
  }

  private async prepareSets(
    sets: CreateWorkoutSetDto[],
  ): Promise<NormalizedWorkoutSetInput[]> {
    if (sets.length === 0) {
      return [];
    }

    const orders = sets.map((set) => set.order);
    if (new Set(orders).size !== orders.length) {
      throw new BadRequestException(
        'El orden de las series debe ser único dentro de la sesión',
      );
    }

    const exerciseIds = [
      ...new Set(sets.map((set) => set.exerciseId.trim()).filter(Boolean)),
    ];
    const exercises = await this.prisma.exercise.findMany({
      where: { id: { in: exerciseIds } },
      select: { id: true },
    });
    if (exercises.length !== exerciseIds.length) {
      throw new BadRequestException('Uno o más ejercicios no existen');
    }

    return sets.map((set) => ({
      exerciseId: set.exerciseId.trim(),
      order: set.order,
      weight: set.weight,
      reps: set.reps,
      rpe: set.rpe ?? null,
      rir: set.rir ?? null,
    }));
  }

  private assertDateOrder(startedAt: Date, endedAt: Date | null): void {
    if (Number.isNaN(startedAt.getTime())) {
      throw new BadRequestException('startedAt debe ser una fecha válida');
    }
    if (endedAt && Number.isNaN(endedAt.getTime())) {
      throw new BadRequestException('endedAt debe ser una fecha válida');
    }
    if (endedAt && endedAt.getTime() < startedAt.getTime()) {
      throw new BadRequestException(
        'endedAt no puede ser anterior a startedAt',
      );
    }
  }

  private sessions(): {
    create(args: {
      data: {
        userId: string;
        startedAt: Date;
        endedAt: Date | null;
        location: string | null;
        notes: string | null;
        routineId?: string | null;
        sets?: { create: NormalizedWorkoutSetInput[] };
      };
      include?: typeof SETS_INCLUDE;
    }): Promise<StoredSession>;
    findMany(args: {
      where: {
        userId: string;
        OR?: Array<{
          startedAt: Date | { lt: Date };
          createdAt?: { lt: Date };
        }>;
      };
      include?: typeof SETS_INCLUDE;
      orderBy?:
        | { startedAt: 'asc' | 'desc' }
        | Array<{ startedAt: 'desc' } | { createdAt: 'desc' }>;
      take?: number;
    }): Promise<StoredSession[]>;
    findFirst(args: {
      where: { id: string; userId: string };
      include?: typeof SETS_INCLUDE;
    }): Promise<StoredSession | null>;
    update(args: {
      where: { id: string };
      data: {
        startedAt?: Date;
        endedAt?: Date | null;
        location?: string | null;
        notes?: string | null;
        sets?: {
          deleteMany: Record<string, never>;
          create: NormalizedWorkoutSetInput[];
        };
      };
      include?: typeof SETS_INCLUDE;
    }): Promise<StoredSession>;
    delete(args: { where: { id: string } }): Promise<StoredSession>;
  } {
    return this.prisma.workoutSession as unknown as ReturnType<
      WorkoutsService['sessions']
    >;
  }
}

export function normalizeLocation(location: string | undefined): string | null {
  if (location === undefined) {
    return null;
  }
  const trimmed = location.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toSnapshot(session: StoredSession): WorkoutSessionSnapshot {
  const sets = [...(session.sets ?? [])].sort((a, b) => a.order - b.order);
  return {
    id: session.id,
    userId: session.userId,
    routineId: session.routineId ?? null,
    startedAt: session.startedAt,
    endedAt: session.endedAt,
    location: session.location ?? null,
    notes: session.notes,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    sets: sets.map((set) => ({
      id: set.id,
      sessionId: set.sessionId,
      exerciseId: set.exerciseId,
      exerciseName: set.exercise?.name ?? null,
      order: set.order,
      weight: set.weight,
      reps: set.reps,
      rpe: set.rpe,
      rir: set.rir,
      createdAt: set.createdAt,
      updatedAt: set.updatedAt,
    })),
  };
}
