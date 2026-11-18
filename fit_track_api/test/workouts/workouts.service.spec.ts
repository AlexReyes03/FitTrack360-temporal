import { BadRequestException, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { PrismaService } from '../../src/prisma/prisma.service';
import { CreateWorkoutDto } from '../../src/workouts/dto/create-workout.dto';
import { CreateWorkoutSetDto } from '../../src/workouts/dto/create-workout-set.dto';
import type { NormalizedWorkoutSetInput } from '../../src/workouts/workouts.service';
import { WorkoutsService } from '../../src/workouts/workouts.service';

interface StoredExercise {
  id: string;
  name: string;
}

interface StoredSet extends NormalizedWorkoutSetInput {
  id: string;
  sessionId: string;
  createdAt: Date;
  updatedAt: Date;
}

interface StoredSession {
  id: string;
  userId: string;
  startedAt: Date;
  endedAt: Date | null;
  location: string | null;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
}

function createWorkoutStore() {
  const exercises: StoredExercise[] = [
    { id: '0001', name: 'Sentadilla' },
    { id: '0002', name: 'Press de banca' },
  ];
  const sessions: StoredSession[] = [];
  const sets: StoredSet[] = [];
  let sessionSeq = 1;
  let setSeq = 1;

  const attach = (session: StoredSession) => ({
    ...session,
    sets: sets
      .filter((set) => set.sessionId === session.id)
      .sort((a, b) => a.order - b.order)
      .map((set) => ({
        ...set,
        exercise: exercises.find((item) => item.id === set.exerciseId) ?? null,
      })),
  });

  return {
    sessions,
    sets,
    exercise: {
      findMany: ({
        where,
      }: {
        where: { id: { in: string[] } };
        select?: { id: boolean };
      }) =>
        Promise.resolve(
          exercises
            .filter((exercise) => where.id.in.includes(exercise.id))
            .map((exercise) => ({ id: exercise.id })),
        ),
    },
    workoutSession: {
      create: ({
        data,
      }: {
        data: {
          userId: string;
          startedAt: Date;
          endedAt: Date | null;
          location: string | null;
          notes: string | null;
          sets?: { create: NormalizedWorkoutSetInput[] };
        };
      }) => {
        const now = new Date('2026-11-15T18:00:00.000Z');
        const session: StoredSession = {
          id: `session-${sessionSeq++}`,
          userId: data.userId,
          startedAt: data.startedAt,
          endedAt: data.endedAt,
          location: data.location,
          notes: data.notes,
          createdAt: now,
          updatedAt: now,
        };
        sessions.push(session);
        for (const input of data.sets?.create ?? []) {
          sets.push({
            ...input,
            id: `set-${setSeq++}`,
            sessionId: session.id,
            createdAt: now,
            updatedAt: now,
          });
        }
        return Promise.resolve(attach(session));
      },
      findMany: ({
        where,
        orderBy,
      }: {
        where: { userId: string };
        orderBy?: { startedAt: 'asc' | 'desc' };
      }) => {
        const found = sessions
          .filter((session) => session.userId === where.userId)
          .sort((a, b) => {
            const delta = a.startedAt.getTime() - b.startedAt.getTime();
            return orderBy?.startedAt === 'asc' ? delta : -delta;
          });
        return Promise.resolve(found.map(attach));
      },
      findFirst: ({ where }: { where: { id: string; userId: string } }) => {
        const found = sessions.find(
          (session) =>
            session.id === where.id && session.userId === where.userId,
        );
        return Promise.resolve(found ? attach(found) : null);
      },
      update: ({
        where,
        data,
      }: {
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
      }) => {
        const session = sessions.find((item) => item.id === where.id);
        if (!session) {
          return Promise.reject(new Error('Registro no encontrado'));
        }
        if (data.startedAt !== undefined) session.startedAt = data.startedAt;
        if (data.endedAt !== undefined) session.endedAt = data.endedAt;
        if (data.location !== undefined) session.location = data.location;
        if (data.notes !== undefined) session.notes = data.notes;
        if (data.sets) {
          for (let index = sets.length - 1; index >= 0; index -= 1) {
            if (sets[index]?.sessionId === session.id) {
              sets.splice(index, 1);
            }
          }
          const now = new Date('2026-11-15T18:30:00.000Z');
          for (const input of data.sets.create) {
            sets.push({
              ...input,
              id: `set-${setSeq++}`,
              sessionId: session.id,
              createdAt: now,
              updatedAt: now,
            });
          }
        }
        session.updatedAt = new Date('2026-11-15T18:30:00.000Z');
        return Promise.resolve(attach(session));
      },
      delete: ({ where }: { where: { id: string } }) => {
        const index = sessions.findIndex((session) => session.id === where.id);
        if (index < 0) {
          return Promise.reject(new Error('Registro no encontrado'));
        }
        const [removed] = sessions.splice(index, 1);
        for (let cursor = sets.length - 1; cursor >= 0; cursor -= 1) {
          if (sets[cursor]?.sessionId === removed.id) {
            sets.splice(cursor, 1);
          }
        }
        return Promise.resolve(attach(removed));
      },
    },
  };
}

function serviceWithStore() {
  const store = createWorkoutStore();
  const service = new WorkoutsService(store as unknown as PrismaService);
  return { store, service };
}

describe('WorkoutsService · series, volumen y comparación (W11-03)', () => {
  it('crea una sesión con varias series y la recupera completa, en orden', async () => {
    const { service } = serviceWithStore();

    const created = await service.create('user-ana', {
      startedAt: '2026-11-15T10:00:00.000Z',
      endedAt: '2026-11-15T11:15:00.000Z',
      notes: 'Día de fuerza',
      sets: [
        { exerciseId: '0002', order: 2, weight: 40, reps: 8, rpe: 7 },
        {
          exerciseId: '0001',
          order: 1,
          weight: 80,
          reps: 10,
          rpe: 8,
          rir: 2,
        },
      ],
    });

    const loaded = await service.findOne('user-ana', created.id);

    expect(loaded.sets.map((set) => set.order)).toEqual([1, 2]);
    expect(loaded.sets[0]).toMatchObject({
      exerciseId: '0001',
      exerciseName: 'Sentadilla',
      weight: 80,
      weightKg: 80,
      reps: 10,
      rpe: 8,
      rir: 2,
      volume: 800,
    });
    expect(loaded.sets[1]).toMatchObject({
      exerciseId: '0002',
      exerciseName: 'Press de banca',
      weight: 40,
      reps: 8,
      rpe: 7,
      rir: null,
      volume: 320,
    });
    expect(loaded.notes).toBe('Día de fuerza');
  });

  it('calcula el volumen como peso × reps y la duración con startedAt y endedAt', async () => {
    const { service } = serviceWithStore();

    const created = await service.create('user-ana', {
      startedAt: '2026-11-15T10:00:00.000Z',
      endedAt: '2026-11-15T11:15:00.000Z',
      sets: [
        { exerciseId: '0001', order: 1, weight: 80, reps: 10 },
        { exerciseId: '0001', order: 2, weight: 60, reps: 8 },
      ],
    });

    expect(created.volume).toBe(1280);
    expect(created.durationSeconds).toBe(75 * 60);
    expect(created.comparison).toBeNull();
    expect(created.lastMarks).toEqual([]);
  });

  it('deja la duración en null cuando la sesión no tiene fin', async () => {
    const { service } = serviceWithStore();
    const created = await service.create('user-ana', {
      startedAt: '2026-11-15T10:00:00.000Z',
      sets: [{ exerciseId: '0001', order: 1, weight: 20, reps: 5 }],
    });
    expect(created.durationSeconds).toBeNull();
    expect(created.volume).toBe(100);
  });

  it('compara y toma la última marca solo con sesiones anteriores del mismo usuario', async () => {
    const { service } = serviceWithStore();

    await service.create('user-ana', {
      startedAt: '2026-11-15T08:00:00.000Z',
      endedAt: '2026-11-15T08:30:00.000Z',
      sets: [
        { exerciseId: '0002', order: 1, weight: 50, reps: 10 },
        { exerciseId: '0002', order: 2, weight: 55, reps: 6 },
      ],
    });
    const middle = await service.create('user-ana', {
      startedAt: '2026-11-15T09:00:00.000Z',
      endedAt: '2026-11-15T09:20:00.000Z',
      sets: [{ exerciseId: '0001', order: 1, weight: 100, reps: 5 }],
    });
    await service.create('user-beto', {
      startedAt: '2026-11-15T09:30:00.000Z',
      endedAt: '2026-11-15T10:00:00.000Z',
      sets: [{ exerciseId: '0002', order: 1, weight: 200, reps: 10 }],
    });
    const current = await service.create('user-ana', {
      startedAt: '2026-11-15T12:00:00.000Z',
      endedAt: '2026-11-15T12:40:00.000Z',
      sets: [{ exerciseId: '0002', order: 1, weight: 80, reps: 8 }],
    });

    expect(current.lastMarks).toEqual([
      expect.objectContaining({
        exerciseId: '0002',
        exerciseName: 'Press de banca',
        weight: 55,
        reps: 6,
        volume: 330,
      }),
    ]);
    expect(current.lastMarks[0]?.sessionId).not.toBe(current.id);
    expect(current.comparison).toMatchObject({
      previousSessionId: middle.id,
      previousVolume: 500,
      volume: 640,
      volumeDelta: 140,
      previousDurationSeconds: 20 * 60,
      durationSeconds: 40 * 60,
      durationDeltaSeconds: 20 * 60,
      previousSetCount: 1,
      setCount: 1,
      setCountDelta: 0,
    });

    const beto = await service.findAll('user-beto');
    expect(beto).toHaveLength(1);
    expect(beto[0]?.comparison).toBeNull();
    expect(beto[0]?.volume).toBe(2000);
  });

  it('guarda la ubicación cuando viene y permite omitirla', async () => {
    const { service } = serviceWithStore();

    const withZone = await service.create('user-ana', {
      startedAt: '2026-11-15T10:00:00.000Z',
      location: '  Gimnasio del campus  ',
      sets: [{ exerciseId: '0001', order: 1, weight: 40, reps: 8 }],
    });
    const withoutZone = await service.create('user-ana', {
      startedAt: '2026-11-15T11:00:00.000Z',
    });
    const cleared = await service.update('user-ana', withZone.id, {
      location: '   ',
    });

    expect(withZone.location).toBe('Gimnasio del campus');
    expect(withoutZone.location).toBeNull();
    expect(withoutZone.sets).toEqual([]);
    expect(cleared.location).toBeNull();
    expect(cleared.sets).toHaveLength(1);
  });

  it('responde 404 si otro usuario consulta, edita o borra la sesión', async () => {
    const { service } = serviceWithStore();
    const created = await service.create('user-ana', {
      startedAt: '2026-11-15T10:00:00.000Z',
      notes: 'privada',
    });

    await expect(
      service.findOne('user-beto', created.id),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(
      service.update('user-beto', created.id, { notes: 'ajena' }),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(
      service.remove('user-beto', created.id),
    ).rejects.toBeInstanceOf(NotFoundException);

    const stillThere = await service.findOne('user-ana', created.id);
    expect(stillThere.notes).toBe('privada');

    try {
      await service.findOne('user-beto', created.id);
    } catch (error) {
      expect(error).toBeInstanceOf(NotFoundException);
      expect((error as NotFoundException).getStatus()).toBe(404);
    }
  });

  it('reemplaza las series al actualizar y rechaza orden duplicado o ejercicio inexistente', async () => {
    const { service } = serviceWithStore();
    const created = await service.create('user-ana', {
      startedAt: '2026-11-15T10:00:00.000Z',
      endedAt: '2026-11-15T10:10:00.000Z',
      sets: [{ exerciseId: '0001', order: 1, weight: 20, reps: 5 }],
    });

    const updated = await service.update('user-ana', created.id, {
      sets: [{ exerciseId: '0002', order: 1, weight: 30, reps: 12, rir: 1 }],
    });
    expect(updated.sets).toHaveLength(1);
    expect(updated.sets[0]).toMatchObject({
      exerciseId: '0002',
      weightKg: 30,
      reps: 12,
      rir: 1,
    });
    expect(updated.volume).toBe(360);

    await expect(
      service.update('user-ana', created.id, {
        sets: [
          { exerciseId: '0001', order: 1, weight: 10, reps: 5 },
          { exerciseId: '0002', order: 1, weight: 10, reps: 5 },
        ],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      service.create('user-ana', {
        startedAt: '2026-11-15T12:00:00.000Z',
        sets: [{ exerciseId: '9999', order: 1, weight: 10, reps: 5 }],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      service.create('user-ana', {
        startedAt: '2026-11-15T13:00:00.000Z',
        endedAt: '2026-11-15T12:00:00.000Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  describe('DTOs', () => {
    it('acepta series con RPE o RIR opcionales y ubicación opcional', async () => {
      const dto = plainToInstance(CreateWorkoutDto, {
        startedAt: '2026-11-15T10:00:00.000Z',
        location: 'Casa',
        sets: [{ exerciseId: '0001', order: 1, weight: 0, reps: 12, rir: 0 }],
      });
      expect(await validate(dto)).toHaveLength(0);
    });

    it('rechaza repeticiones menores a 1, peso negativo, orden inválido y RPE fuera de rango', async () => {
      const dto = plainToInstance(CreateWorkoutDto, {
        startedAt: '2026-11-15T10:00:00.000Z',
        sets: [{ exerciseId: '0001', order: 0, weight: -5, reps: 0, rpe: 11 }],
      });
      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      const setErrors = errors.find((error) => error.property === 'sets');
      const children = setErrors?.children?.[0]?.children ?? [];
      const fields = children.map((error) => error.property);
      expect(fields).toEqual(
        expect.arrayContaining(['order', 'weight', 'reps', 'rpe']),
      );
    });

    it('exige exerciseId en cada serie', async () => {
      const dto = plainToInstance(CreateWorkoutSetDto, {
        order: 1,
        weight: 10,
        reps: 8,
      });
      const errors = await validate(dto);
      expect(errors.map((error) => error.property)).toContain('exerciseId');
    });
  });
});
