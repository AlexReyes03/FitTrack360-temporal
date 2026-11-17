import { BadRequestException, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { PrismaService } from '../../src/prisma/prisma.service';
import { RoutinesService } from '../../src/routines/routines.service';
import { CreateRoutineDto } from '../../src/routines/dto/routine.dto';
import { WorkoutsService } from '../../src/workouts/workouts.service';

const entry = { exerciseId: 'ex1', position: 1, targetSets: 2, targetReps: 8 };
const routine = {
  id: 'r1',
  userId: 'u1',
  name: 'Fuerza',
  exercises: [{ id: 're1', routineId: 'r1', ...entry }],
};
function setup(owner = true) {
  const calls: Record<string, unknown>[] = [];
  const db = {
    routine: {
      findFirst: (args: unknown) => {
        calls.push({ findFirst: args });
        return Promise.resolve(owner ? routine : null);
      },
      findMany: (args: unknown) => {
        calls.push({ findMany: args });
        return Promise.resolve([routine]);
      },
      create: (args: unknown) => {
        calls.push({ create: args });
        return Promise.resolve(routine);
      },
      update: (args: unknown) => {
        calls.push({ update: args });
        return Promise.resolve(routine);
      },
      delete: (args: unknown) => {
        calls.push({ delete: args });
        return Promise.resolve(routine);
      },
    },
    exercise: { findMany: () => Promise.resolve([{ id: 'ex1' }]) },
  };
  const workouts = {
    create: (userId: string, dto: unknown) => {
      calls.push({ workout: { userId, dto } });
      return Promise.resolve({});
    },
  };
  return {
    service: new RoutinesService(
      db as unknown as PrismaService,
      workouts as unknown as WorkoutsService,
    ),
    calls,
  };
}
describe('Rutinas', () => {
  it('valida series y repeticiones positivas y estructura anidada', async () => {
    const dto = plainToInstance(CreateRoutineDto, {
      name: 'A',
      exercises: [{ ...entry, targetSets: 0, targetReps: -1 }],
    });
    expect(await validate(dto)).not.toHaveLength(0);
  });
  it('rechaza posiciones repetidas y ejercicios inexistentes', async () => {
    const { service } = setup();
    await expect(
      service.create('u1', { name: 'A', exercises: [entry, entry] }),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.create('u1', {
        name: 'A',
        exercises: [
          { ...entry, exerciseId: 'otro' },
          { ...entry, position: 2 },
        ],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
  it('consulta y lista por usuario con orden estable', async () => {
    const { service, calls } = setup();
    await service.findOne('u1', 'r1');
    await service.findAll('u1');
    expect(calls[0]).toMatchObject({
      findFirst: {
        where: { id: 'r1', userId: 'u1' },
        include: { exercises: { orderBy: { position: 'asc' } } },
      },
    });
    expect(calls[1]).toMatchObject({ findMany: { where: { userId: 'u1' } } });
  });
  it('devuelve 404 para consulta, edición, borrado, copia e inicio ajenos', async () => {
    const { service } = setup(false);
    for (const action of [
      () => service.findOne('u2', 'r1'),
      () => service.update('u2', 'r1', { name: 'X' }),
      () => service.remove('u2', 'r1'),
      () => service.duplicate('u2', 'r1'),
      () => service.start('u2', 'r1'),
    ])
      await expect(action()).rejects.toBeInstanceOf(NotFoundException);
  });
  it('crea, actualiza y elimina una rutina propia', async () => {
    const { service, calls } = setup();
    await service.create('u1', { name: 'Fuerza', exercises: [entry] });
    await service.update('u1', 'r1', { name: 'Nueva', exercises: [entry] });
    await service.remove('u1', 'r1');
    expect(calls[0]).toMatchObject({
      create: { data: { userId: 'u1', exercises: { create: [entry] } } },
    });
    expect(calls[2]).toMatchObject({
      update: {
        data: { name: 'Nueva', exercises: { deleteMany: {}, create: [entry] } },
      },
    });
    expect(calls[4]).toMatchObject({ delete: { where: { id: 'r1' } } });
  });
  it('duplica sin reutilizar identificadores de ejercicios de rutina', async () => {
    const { service, calls } = setup();
    await service.duplicate('u1', 'r1');
    expect(calls[1]).toMatchObject({
      create: {
        data: {
          userId: 'u1',
          name: 'Fuerza (copia)',
          exercises: { create: [entry] },
        },
      },
    });
  });
  it('inicia sesión vinculada con las series y repeticiones precargadas', async () => {
    const { service, calls } = setup();
    await service.start('u1', 'r1', '2026-11-16T12:00:00.000Z');
    expect(calls[1]).toEqual({
      workout: {
        userId: 'u1',
        dto: {
          routineId: 'r1',
          startedAt: '2026-11-16T12:00:00.000Z',
          sets: [
            { exerciseId: 'ex1', order: 1, weight: 0, reps: 8 },
            { exerciseId: 'ex1', order: 2, weight: 0, reps: 8 },
          ],
        },
      },
    });
  });
});
