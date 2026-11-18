import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DEFAULT_SETTINGS } from '../users/domain/profile-rules';
import {
  remainingAgainst,
  resolveDay,
  sumMealItems,
  type DailyGoals,
} from './domain/day-summary';
import { DashboardQueryDto } from './dto/dashboard-query.dto';
import {
  DashboardTodayDto,
  DaySessionDto,
  LatestMetricDto,
} from './dto/dashboard-response.dto';

/** Macros congelados que el resumen necesita de cada MealItem (M-02). */
const MEAL_ITEM_MACROS = {
  kcal: true,
  proteinG: true,
  carbsG: true,
  fatG: true,
} as const;

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Resumen del día del deportista. Toda consulta filtra por el userId del
   * JWT, así que nunca mezcla datos de otra persona.
   */
  async today(
    userId: string,
    query: DashboardQueryDto,
    now: Date = new Date(),
  ): Promise<DashboardTodayDto> {
    const utcOffsetMinutes = query.utcOffsetMinutes ?? 0;
    const day = resolveDay(query.date, utcOffsetMinutes, now);

    const [meals, settings, todaySession, metric] = await Promise.all([
      // Comidas del día local [start, end) del usuario, con sus alimentos.
      this.prisma.mealLog.findMany({
        where: { userId, eatenAt: { gte: day.start, lt: day.end } },
        include: { items: { select: MEAL_ITEM_MACROS } },
      }),
      this.prisma.userSettings.findUnique({ where: { userId } }),
      this.prisma.workoutSession.findFirst({
        where: { userId, startedAt: { gte: day.start, lt: day.end } },
        orderBy: { startedAt: 'desc' },
      }),
      // Última métrica corporal registrada hasta el fin del día consultado.
      this.prisma.bodyMetric.findFirst({
        where: { userId, measuredAt: { lt: day.end } },
        orderBy: { measuredAt: 'desc' },
      }),
    ]);

    // Sin sesión en el día no se inventa una rutina: se muestra la última
    // sesión real anterior al día consultado, o nada.
    const session =
      todaySession ??
      (await this.prisma.workoutSession.findFirst({
        where: { userId, startedAt: { lt: day.start } },
        orderBy: { startedAt: 'desc' },
      }));

    // Suma de los MealItem (macros congelados, M-02) de las comidas del día.
    // No se reutiliza GET /meals/summary porque su día es UTC fijo y aquí el
    // día es el local del cliente (date + utcOffsetMinutes).
    const consumed = sumMealItems(meals);
    const goals: DailyGoals = {
      dailyCalorieGoal:
        settings?.dailyCalorieGoal ?? DEFAULT_SETTINGS.dailyCalorieGoal,
      proteinGoalG: settings?.proteinGoalG ?? DEFAULT_SETTINGS.proteinGoalG,
      carbsGoalG: settings?.carbsGoalG ?? DEFAULT_SETTINGS.carbsGoalG,
      fatGoalG: settings?.fatGoalG ?? DEFAULT_SETTINGS.fatGoalG,
    };

    return {
      date: day.date,
      utcOffsetMinutes,
      nutrition: {
        mealsLogged: meals.length,
        consumed,
        goals,
        remaining: remainingAgainst(goals, consumed),
      },
      session: session ? toSession(session, todaySession !== null) : null,
      latestMetric: metric ? toMetric(metric) : null,
    };
  }
}

function toSession(
  session: {
    id: string;
    startedAt: Date;
    endedAt: Date | null;
    notes: string | null;
  },
  isToday: boolean,
): DaySessionDto {
  return {
    id: session.id,
    startedAt: session.startedAt.toISOString(),
    endedAt: session.endedAt?.toISOString() ?? null,
    notes: session.notes,
    isToday,
  };
}

function toMetric(metric: {
  id: string;
  measuredAt: Date;
  weightKg: number | null;
  bodyFatPercent: number | null;
  waistCm: number | null;
}): LatestMetricDto {
  return {
    id: metric.id,
    measuredAt: metric.measuredAt.toISOString(),
    weightKg: metric.weightKg,
    bodyFatPercent: metric.bodyFatPercent,
    waistCm: metric.waistCm,
  };
}
