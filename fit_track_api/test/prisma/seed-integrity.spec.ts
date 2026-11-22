import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  EXPECTED_EXERCISE_COUNT,
  assertExerciseCount,
  assertUniqueExerciseIds,
  exercisesForSeed,
  type RawExerciseJson,
} from '../../prisma/exercise-catalog';

const apiRoot = process.cwd();

describe('Integridad del seed de ejercicios (W12-14)', () => {
  const catalog = JSON.parse(
    readFileSync(path.join(apiRoot, 'seed/exercises.es.json'), 'utf8'),
  ) as RawExerciseJson[];
  const records = exercisesForSeed(catalog);
  const seedSource = readFileSync(path.join(apiRoot, 'prisma/seed.ts'), 'utf8');

  it(`tiene exactamente ${EXPECTED_EXERCISE_COUNT} IDs únicos`, () => {
    expect(catalog).toHaveLength(EXPECTED_EXERCISE_COUNT);
    expect(records).toHaveLength(EXPECTED_EXERCISE_COUNT);
    expect(() => assertUniqueExerciseIds(records)).not.toThrow();
    expect(() => assertExerciseCount(records.length)).not.toThrow();
  });

  it('falla si el conteo de integridad no coincide', () => {
    expect(() => assertExerciseCount(EXPECTED_EXERCISE_COUNT - 1)).toThrow(
      /Integridad del catálogo fallida/,
    );
    expect(() =>
      assertUniqueExerciseIds([{ id: '0001' }, { id: '0001' }]),
    ).toThrow(/duplicado/);
  });

  it('usa upsert por id para evitar duplicados al re-ejecutar', () => {
    expect(seedSource).toMatch(/prisma\.exercise\.upsert/);
    expect(seedSource).toMatch(/where:\s*\{\s*id\s*\}/);
    expect(seedSource).not.toMatch(/createMany/);
    expect(seedSource).toMatch(/assertExerciseCount/);
  });
});
