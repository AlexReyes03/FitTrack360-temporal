/**
 * Almacén en memoria que sustituye a Prisma para el resumen del día.
 * Implementa solo los filtros que usa DashboardService (userId y rangos).
 */
export interface FakeMeal {
  id: string;
  userId: string;
  eatenAt: Date;
  mealType: string;
}

export interface FakeSession {
  id: string;
  userId: string;
  startedAt: Date;
  endedAt: Date | null;
  notes: string | null;
}

export interface FakeSettings {
  userId: string;
  dailyCalorieGoal: number;
  proteinGoalG: number;
  carbsGoalG: number;
  fatGoalG: number;
}

type DateRange = { gte?: Date; lt?: Date };

const inRange = (value: Date, range: DateRange | undefined) =>
  (!range?.gte || value >= range.gte) && (!range?.lt || value < range.lt);

export function createDashboardStore(seed: {
  meals?: FakeMeal[];
  sessions?: FakeSession[];
  settings?: FakeSettings[];
}) {
  const meals = seed.meals ?? [];
  const sessions = seed.sessions ?? [];
  const settings = seed.settings ?? [];

  return {
    mealLog: {
      findMany: ({
        where,
      }: {
        where: { userId: string; eatenAt?: DateRange };
      }) =>
        Promise.resolve(
          meals.filter(
            (m) =>
              m.userId === where.userId && inRange(m.eatenAt, where.eatenAt),
          ),
        ),
    },
    workoutSession: {
      findFirst: ({
        where,
        orderBy,
      }: {
        where: { userId: string; startedAt?: DateRange };
        orderBy?: { startedAt: 'asc' | 'desc' };
      }) => {
        const found = sessions
          .filter(
            (s) =>
              s.userId === where.userId &&
              inRange(s.startedAt, where.startedAt),
          )
          .sort((a, b) =>
            orderBy?.startedAt === 'desc'
              ? b.startedAt.getTime() - a.startedAt.getTime()
              : a.startedAt.getTime() - b.startedAt.getTime(),
          );
        return Promise.resolve(found[0] ?? null);
      },
    },
    userSettings: {
      findUnique: ({ where }: { where: { userId: string } }) =>
        Promise.resolve(
          settings.find((s) => s.userId === where.userId) ?? null,
        ),
    },
  };
}
