import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  exercisesForSeed,
  type RawExerciseJson,
} from '../../prisma/exercise-catalog';

const apiRoot = process.cwd();

describe('Catálogo de ejercicios (W11-02 seed)', () => {
  const catalog = JSON.parse(
    readFileSync(path.join(apiRoot, 'seed/exercises.es.json'), 'utf8'),
  ) as RawExerciseJson[];

  it('carga los 1324 ejercicios, sin el recorte slice(0, 5)', () => {
    const seedSource = readFileSync(
      path.join(apiRoot, 'prisma/seed.ts'),
      'utf8',
    );

    expect(seedSource).not.toMatch(/slice\(\s*0\s*,\s*5\s*\)/);
    expect(catalog).toHaveLength(1324);
    expect(exercisesForSeed(catalog)).toHaveLength(1324);
    expect(exercisesForSeed(catalog)[0]?.id).toBe(catalog[0]?.id);
  });

  it('mapea media, músculos e instrucciones y deja nulos los campos que el JSON no trae', () => {
    const [first] = exercisesForSeed(catalog);

    expect(first).toMatchObject({
      id: '0001',
      name: '3/4 sit-up',
      bodyPart: 'waist',
      equipment: 'body weight',
      target: 'abs',
      imageFile: '0001-2gPfomN.jpg',
      gifFile: '0001-2gPfomN.gif',
      attribution: '© Gym visual — https://gymvisual.com/',
    });
    expect(first?.instructionStepsEs.length).toBeGreaterThan(0);
    expect(first?.nameEs).toBeNull();
    expect(first?.level).toBeNull();
    expect(first?.commonErrors).toBeNull();
  });

  it('conserva nameEs, level y commonErrors cuando el registro curado los trae', () => {
    const [mapped] = exercisesForSeed([
      {
        id: '9001',
        name: 'bench press',
        name_es: ' Press de banca ',
        body_part: 'chest',
        equipment: 'barbell',
        target: 'pectorals',
        level: 'intermediate',
        common_errors: '  Rebotar la barra  ',
        image: '9001.jpg',
        gif: '9001.gif',
        attribution: '© Gym visual — https://gymvisual.com/',
      },
    ]);

    expect(mapped?.nameEs).toBe('Press de banca');
    expect(mapped?.level).toBe('intermediate');
    expect(mapped?.commonErrors).toBe('Rebotar la barra');
  });
});
