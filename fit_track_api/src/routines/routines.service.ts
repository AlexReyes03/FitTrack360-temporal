import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { WorkoutsService } from '../workouts/workouts.service';
import {
  CreateRoutineDto,
  RoutineExerciseDto,
  UpdateRoutineDto,
} from './dto/routine.dto';

const include = { exercises: { orderBy: { position: 'asc' as const } } };
@Injectable()
export class RoutinesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly workouts: WorkoutsService,
  ) {}
  async create(userId: string, dto: CreateRoutineDto) {
    await this.validateExercises(dto.exercises);
    return this.prisma.routine.create({
      data: {
        userId,
        name: dto.name.trim(),
        exercises: { create: dto.exercises },
      },
      include,
    });
  }
  findAll(userId: string) {
    return this.prisma.routine.findMany({
      where: { userId },
      include,
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
    });
  }
  async findOne(userId: string, id: string) {
    const routine = await this.prisma.routine.findFirst({
      where: { id, userId },
      include,
    });
    if (!routine) throw new NotFoundException('Rutina no encontrada');
    return routine;
  }
  async update(userId: string, id: string, dto: UpdateRoutineDto) {
    await this.findOne(userId, id);
    if (dto.exercises) await this.validateExercises(dto.exercises);
    return this.prisma.routine.update({
      where: { id },
      data: {
        name: dto.name?.trim(),
        exercises: dto.exercises
          ? { deleteMany: {}, create: dto.exercises }
          : undefined,
      },
      include,
    });
  }
  async remove(userId: string, id: string) {
    await this.findOne(userId, id);
    await this.prisma.routine.delete({ where: { id } });
  }
  async duplicate(userId: string, id: string) {
    const source = await this.findOne(userId, id);
    return this.create(userId, {
      name: `${source.name} (copia)`,
      exercises: source.exercises.map(
        ({ exerciseId, position, targetSets, targetReps }) => ({
          exerciseId,
          position,
          targetSets,
          targetReps,
        }),
      ),
    });
  }
  async start(userId: string, id: string, startedAt?: string) {
    const routine = await this.findOne(userId, id);
    let order = 0;
    const sets = routine.exercises.flatMap((item) =>
      Array.from({ length: item.targetSets }, () => ({
        exerciseId: item.exerciseId,
        order: ++order,
        weight: 0,
        reps: item.targetReps,
      })),
    );
    return this.workouts.create(userId, {
      startedAt: startedAt ?? new Date().toISOString(),
      routineId: id,
      sets,
    });
  }
  private async validateExercises(exercises: RoutineExerciseDto[]) {
    if (new Set(exercises.map((e) => e.position)).size !== exercises.length)
      throw new BadRequestException('Las posiciones deben ser únicas');
    if (
      exercises.some(
        (e) =>
          !e.exerciseId.trim() ||
          e.position < 1 ||
          e.targetSets < 1 ||
          e.targetSets > 100 ||
          e.targetReps < 1,
      )
    )
      throw new BadRequestException('Ejercicios inválidos');
    const ids = [...new Set(exercises.map((e) => e.exerciseId))];
    const existing = await this.prisma.exercise.findMany({
      where: { id: { in: ids } },
      select: { id: true },
    });
    if (existing.length !== ids.length)
      throw new BadRequestException('Uno o más ejercicios no existen');
  }
}
