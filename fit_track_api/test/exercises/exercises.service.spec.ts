import { NotFoundException, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Prisma, type Exercise } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import request from 'supertest';
import type { App } from 'supertest/types';
import { JwtAuthGuard } from '../../src/auth/jwt-auth.guard';
import { APP_HTTP_OPTIONS, configureApp } from '../../src/app.setup';
import { ExerciseQueryDto } from '../../src/exercises/dto/exercise-query.dto';
import { ExerciseResponseDto } from '../../src/exercises/dto/exercise-response.dto';
import { ExercisesController } from '../../src/exercises/exercises.controller';
import { ExercisesService } from '../../src/exercises/exercises.service';
import { PrismaService } from '../../src/prisma/prisma.service';

const ATTRIBUTION = '© Gym visual — https://gymvisual.com/';

function exercise(
  overrides: Partial<Exercise> & Pick<Exercise, 'id' | 'name'>,
): Exercise {
  return {
    nameEs: null,
    category: 'strength',
    bodyPart: 'waist',
    equipment: 'body weight',
    target: 'abs',
    muscleGroup: 'abdominals',
    secondaryMuscles: ['hip flexors'],
    level: null,
    instructionsEs: 'Instrucción de prueba.',
    instructionStepsEs: ['Paso uno', 'Paso dos'],
    commonErrors: null,
    imageFile: `${overrides.id}.jpg`,
    gifFile: `${overrides.id}.gif`,
    mediaId: overrides.id,
    attribution: ATTRIBUTION,
    ...overrides,
  };
}

function textEquals(value: string, filter: unknown): boolean {
  if (typeof filter === 'string') return value === filter;
  if (!filter || typeof filter !== 'object' || !('equals' in filter)) {
    throw new Error('filtro de igualdad no reconocido');
  }
  const expected = String(filter.equals);
  const mode = 'mode' in filter ? filter.mode : undefined;
  if (mode === 'insensitive') {
    return value.toLowerCase() === expected.toLowerCase();
  }
  return value === expected;
}

function textContains(value: string | null, filter: unknown): boolean {
  if (!filter || typeof filter !== 'object' || !('contains' in filter)) {
    throw new Error('filtro de texto no reconocido');
  }
  const needle = String(filter.contains);
  const mode = 'mode' in filter ? filter.mode : undefined;
  const haystack = value ?? '';
  if (mode === 'insensitive') {
    return haystack.toLowerCase().includes(needle.toLowerCase());
  }
  return haystack.includes(needle);
}

function matches(row: Exercise, where: Prisma.ExerciseWhereInput): boolean {
  const allowed = new Set(['bodyPart', 'equipment', 'target', 'OR']);
  for (const key of Object.keys(where)) {
    if (!allowed.has(key)) {
      throw new Error(`filtro no soportado por la prueba: ${key}`);
    }
  }
  if (where.bodyPart && !textEquals(row.bodyPart, where.bodyPart)) return false;
  if (where.equipment && !textEquals(row.equipment, where.equipment)) {
    return false;
  }
  if (where.target && !textEquals(row.target, where.target)) return false;
  if (where.OR) {
    const found = where.OR.some((clause) => {
      if ('name' in clause && clause.name) {
        return textContains(row.name, clause.name);
      }
      if ('nameEs' in clause && clause.nameEs) {
        return textContains(row.nameEs, clause.nameEs);
      }
      throw new Error('clausula OR no reconocida');
    });
    if (!found) return false;
  }
  return true;
}

function compareRows(
  left: Exercise,
  right: Exercise,
  orderBy: Prisma.ExerciseOrderByWithRelationInput,
): number {
  const key = Object.keys(orderBy)[0];
  if (key !== 'id' && key !== 'name') {
    throw new Error(`orden no soportado: ${key}`);
  }
  const direction = orderBy[key];
  if (direction !== 'asc' && direction !== 'desc') {
    throw new Error(`dirección no soportada: ${String(direction)}`);
  }
  const result = left[key].localeCompare(right[key]);
  return direction === 'desc' ? -result : result;
}

interface ListArgs {
  where: Prisma.ExerciseWhereInput;
  skip: number;
  take: number;
  orderBy: Prisma.ExerciseOrderByWithRelationInput;
}

function createCatalogPrisma(rows: Exercise[]) {
  const findManyCalls: ListArgs[] = [];
  const countCalls: Prisma.ExerciseWhereInput[] = [];

  return {
    findManyCalls,
    countCalls,
    exercise: {
      findMany(args: ListArgs): Promise<Exercise[]> {
        if (args.take == null) {
          throw new Error(
            'findMany sin take: el catálogo no debe cargarse completo para filtrar',
          );
        }
        findManyCalls.push(args);
        const page = rows
          .filter((row) => matches(row, args.where))
          .sort((left, right) => compareRows(left, right, args.orderBy));
        return Promise.resolve(page.slice(args.skip, args.skip + args.take));
      },
      count(args: { where: Prisma.ExerciseWhereInput }): Promise<number> {
        countCalls.push(args.where);
        return Promise.resolve(
          rows.filter((row) => matches(row, args.where)).length,
        );
      },
      findUnique(args: { where: { id: string } }): Promise<Exercise | null> {
        return Promise.resolve(
          rows.find((row) => row.id === args.where.id) ?? null,
        );
      },
    },
  };
}

const catalogRows = [
  exercise({
    id: '0001',
    name: 'bench press',
    bodyPart: 'chest',
    equipment: 'barbell',
    target: 'pectorals',
    nameEs: null,
    level: null,
    commonErrors: null,
  }),
  exercise({
    id: '0002',
    name: 'squat',
    bodyPart: 'upper legs',
    equipment: 'barbell',
    target: 'quads',
  }),
  exercise({
    id: '0003',
    name: 'incline press',
    bodyPart: 'chest',
    equipment: 'dumbbell',
    target: 'pectorals',
  }),
  exercise({
    id: '0004',
    name: 'close-grip bench press',
    nameEs: 'Press de banca cerrado',
    bodyPart: 'chest',
    equipment: 'barbell',
    target: 'pectorals',
    level: 'intermediate',
    commonErrors: 'Abrir los codos de más.',
    instructionsEs: 'Baja la barra hacia el esternón.',
    instructionStepsEs: ['Acuéstate', 'Baja controlado'],
    secondaryMuscles: ['triceps'],
    muscleGroup: 'triceps',
  }),
];

describe('ExercisesModule · catálogo (W11-02)', () => {
  describe('validación del query', () => {
    const pipeOptions = {
      whitelist: true,
      forbidNonWhitelisted: true,
    };

    it('acepta filtros, página y orden', async () => {
      const dto = plainToInstance(ExerciseQueryDto, {
        q: 'press',
        bodyPart: 'chest',
        equipment: 'barbell',
        target: 'pectorals',
        page: '2',
        pageSize: '20',
        sort: 'name',
        order: 'desc',
      });

      expect(await validate(dto, pipeOptions)).toHaveLength(0);
      expect(dto.page).toBe(2);
      expect(dto.pageSize).toBe(20);
    });

    it('rechaza página, tamaño, orden y campos fuera del DTO', async () => {
      const invalidPage = plainToInstance(ExerciseQueryDto, { page: 0 });
      const invalidSize = plainToInstance(ExerciseQueryDto, { pageSize: 101 });
      const invalidSort = plainToInstance(ExerciseQueryDto, { sort: 'gif' });
      const extra = plainToInstance(ExerciseQueryDto, { userId: 'otro' });

      expect(await validate(invalidPage, pipeOptions)).not.toHaveLength(0);
      expect(await validate(invalidSize, pipeOptions)).not.toHaveLength(0);
      expect(await validate(invalidSort, pipeOptions)).not.toHaveLength(0);
      expect(await validate(extra, pipeOptions)).not.toHaveLength(0);
    });
  });

  describe('consultas paginadas', () => {
    const rows = Array.from({ length: 30 }, (_, index) =>
      exercise({
        id: String(index + 1).padStart(4, '0'),
        name: `Exercise ${String(index + 1).padStart(2, '0')}`,
      }),
    );
    const catalog = createCatalogPrisma(rows);
    const service = new ExercisesService(catalog as unknown as PrismaService);

    it('pide a la base solo la página y el total, ordenados por id', async () => {
      const page = await service.findAll({ page: 2, pageSize: 10 });

      expect(catalog.findManyCalls).toEqual([
        {
          where: {},
          skip: 10,
          take: 10,
          orderBy: { id: 'asc' },
        },
      ]);
      expect(catalog.countCalls).toEqual([{}]);
      expect(page.total).toBe(30);
      expect(page.page).toBe(2);
      expect(page.pageSize).toBe(10);
      expect(page.items.map((item) => item.id)).toEqual([
        '0011',
        '0012',
        '0013',
        '0014',
        '0015',
        '0016',
        '0017',
        '0018',
        '0019',
        '0020',
      ]);
    });

    it('ordena por nombre descendente dentro de la página pedida', async () => {
      const page = await service.findAll({
        page: 1,
        pageSize: 2,
        sort: 'name',
        order: 'desc',
      });

      expect(catalog.findManyCalls.at(-1)?.orderBy).toEqual({ name: 'desc' });
      expect(page.items.map((item) => item.name)).toEqual([
        'Exercise 30',
        'Exercise 29',
      ]);
    });
  });

  describe('filtros combinados, detalle y campos opcionales', () => {
    const catalog = createCatalogPrisma(catalogRows);
    const service = new ExercisesService(catalog as unknown as PrismaService);

    it('devuelve solo las coincidencias de bodyPart, equipment, target y texto', async () => {
      const page = await service.findAll({
        bodyPart: ' CHEST ',
        equipment: 'barbell',
        target: 'pectorals',
        q: 'press',
        page: 1,
        pageSize: 1,
      });

      expect(catalog.findManyCalls[0]).toEqual({
        where: {
          bodyPart: { equals: 'CHEST', mode: 'insensitive' },
          equipment: { equals: 'barbell', mode: 'insensitive' },
          target: { equals: 'pectorals', mode: 'insensitive' },
          OR: [
            { name: { contains: 'press', mode: 'insensitive' } },
            { nameEs: { contains: 'press', mode: 'insensitive' } },
          ],
        },
        skip: 0,
        take: 1,
        orderBy: { id: 'asc' },
      });
      expect(page.total).toBe(2);
      expect(page.items).toHaveLength(1);
      expect(page.items[0]?.id).toBe('0001');

      const second = await service.findAll({
        bodyPart: 'chest',
        equipment: 'barbell',
        target: 'pectorals',
        q: 'press',
        page: 2,
        pageSize: 1,
      });
      expect(second.items[0]?.id).toBe('0004');
      expect(second.total).toBe(2);
    });

    it('omite nameEs, level y commonErrors cuando no existen y los incluye cuando sí', async () => {
      const page = await service.findAll({ page: 1, pageSize: 20 });
      const plain = page.items.map(
        (item) => JSON.parse(JSON.stringify(item)) as Record<string, unknown>,
      );
      const without = plain.find((item) => item.id === '0001');
      const withOptional = plain.find((item) => item.id === '0004');

      expect(without).not.toHaveProperty('nameEs');
      expect(without).not.toHaveProperty('level');
      expect(without).not.toHaveProperty('commonErrors');
      expect(without?.category).toBe('strength');
      expect(withOptional).toMatchObject({
        nameEs: 'Press de banca cerrado',
        level: 'intermediate',
        commonErrors: 'Abrir los codos de más.',
      });
    });

    it('el detalle incluye instrucciones, pasos, músculos, media y atribución', async () => {
      const detail = await service.findOne('0004');
      const json = JSON.parse(JSON.stringify(detail)) as Record<
        string,
        unknown
      >;

      expect(detail).toBeInstanceOf(ExerciseResponseDto);
      expect(json).toMatchObject({
        id: '0004',
        instructionsEs: 'Baja la barra hacia el esternón.',
        instructionStepsEs: ['Acuéstate', 'Baja controlado'],
        muscleGroup: 'triceps',
        secondaryMuscles: ['triceps'],
        imageFile: '0004.jpg',
        gifFile: '0004.gif',
        mediaId: '0004',
        attribution: ATTRIBUTION,
        nameEs: 'Press de banca cerrado',
      });
    });

    it('responde 404 cuando el id no existe', async () => {
      const error = await service.findOne('9999').then(
        () => {
          throw new Error('debio fallar');
        },
        (caught: unknown) => caught,
      );

      expect(error).toBeInstanceOf(NotFoundException);
      expect((error as NotFoundException).getStatus()).toBe(404);
    });
  });

  describe('HTTP /api/v1/exercises', () => {
    let app: INestApplication<App>;

    beforeAll(async () => {
      const catalog = createCatalogPrisma(catalogRows);
      const moduleRef = await Test.createTestingModule({
        controllers: [ExercisesController],
        providers: [
          ExercisesService,
          { provide: PrismaService, useValue: catalog },
        ],
      })
        .overrideGuard(JwtAuthGuard)
        .useValue({ canActivate: () => true })
        .compile();

      app =
        moduleRef.createNestApplication<INestApplication<App>>(
          APP_HTTP_OPTIONS,
        );
      configureApp(app);
      await app.init();
    });

    afterAll(async () => {
      await app.close();
    });

    it('lista con filtros bajo el prefijo y omite los opcionales vacíos', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/exercises')
        .query({
          bodyPart: 'chest',
          equipment: 'barbell',
          target: 'pectorals',
          q: 'bench',
          page: 1,
          pageSize: 20,
        })
        .expect(200);

      expect(response.body.total).toBe(2);
      expect(
        response.body.items.map((item: { id: string }) => item.id),
      ).toEqual(['0001', '0004']);
      expect(response.body.items[0]).not.toHaveProperty('nameEs');
      expect(response.body.items[1].nameEs).toBe('Press de banca cerrado');
    });

    it('responde 400 si el query trae un campo fuera del DTO', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/exercises')
        .query({ page: 1, userId: 'otro' })
        .expect(400);
    });

    it('responde 404 para un id inexistente', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/exercises/no-existe')
        .expect(404);

      expect(response.body.message).toBe('Ejercicio no encontrado');
    });
  });
});
