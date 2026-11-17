import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type Exercise } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  ExerciseQueryDto,
  type ExerciseSortField,
  type ExerciseSortOrder,
} from './dto/exercise-query.dto';
import {
  ExercisePageResponseDto,
  ExerciseResponseDto,
} from './dto/exercise-response.dto';

const DEFAULT_PAGE = 1;
const DEFAULT_PAGE_SIZE = 20;
const DEFAULT_SORT: ExerciseSortField = 'id';
const DEFAULT_ORDER: ExerciseSortOrder = 'asc';

interface ExerciseDelegate {
  findMany(args: {
    where: Prisma.ExerciseWhereInput;
    skip: number;
    take: number;
    orderBy: Prisma.ExerciseOrderByWithRelationInput;
  }): Promise<Exercise[]>;
  count(args: { where: Prisma.ExerciseWhereInput }): Promise<number>;
  findUnique(args: { where: { id: string } }): Promise<Exercise | null>;
}

function filled(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

/** Filtros que Postgres aplica con skip/take. No se carga el catálogo en memoria. */
export function buildExerciseWhere(
  query: ExerciseQueryDto,
): Prisma.ExerciseWhereInput {
  const where: Prisma.ExerciseWhereInput = {};
  const bodyPart = filled(query.bodyPart);
  const equipment = filled(query.equipment);
  const target = filled(query.target);
  const q = filled(query.q);

  if (bodyPart) {
    where.bodyPart = { equals: bodyPart, mode: 'insensitive' };
  }
  if (equipment) {
    where.equipment = { equals: equipment, mode: 'insensitive' };
  }
  if (target) {
    where.target = { equals: target, mode: 'insensitive' };
  }
  if (q) {
    where.OR = [
      { name: { contains: q, mode: 'insensitive' } },
      { nameEs: { contains: q, mode: 'insensitive' } },
    ];
  }
  return where;
}

export function buildExerciseOrder(
  query: ExerciseQueryDto,
): Prisma.ExerciseOrderByWithRelationInput {
  const sort = query.sort ?? DEFAULT_SORT;
  const order = query.order ?? DEFAULT_ORDER;
  if (sort === 'name') return { name: order };
  return { id: order };
}

@Injectable()
export class ExercisesService {
  constructor(private readonly prisma: PrismaService) {}

  private get exercise(): ExerciseDelegate {
    return this.prisma.exercise as unknown as ExerciseDelegate;
  }

  async findAll(
    query: ExerciseQueryDto = {},
  ): Promise<ExercisePageResponseDto> {
    const page = query.page ?? DEFAULT_PAGE;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const where = buildExerciseWhere(query);
    const orderBy = buildExerciseOrder(query);
    const skip = (page - 1) * pageSize;

    const [rows, total] = await Promise.all([
      this.exercise.findMany({ where, skip, take: pageSize, orderBy }),
      this.exercise.count({ where }),
    ]);

    return {
      items: rows.map((row) => ExerciseResponseDto.fromEntity(row)),
      total,
      page,
      pageSize,
    };
  }

  async findOne(id: string): Promise<ExerciseResponseDto> {
    const exercise = await this.exercise.findUnique({ where: { id } });
    if (!exercise) {
      throw new NotFoundException('Ejercicio no encontrado');
    }
    return ExerciseResponseDto.fromEntity(exercise);
  }
}
