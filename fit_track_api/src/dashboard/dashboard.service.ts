import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DEFAULT_SETTINGS } from '../users/domain/profile-rules';
import { resolveDay, sumNutrition, ZERO_NUTRIENTS } from './domain/day-summary';
import { DashboardQueryDto } from './dto/dashboard-query.dto';
import { DashboardTodayDto, DaySessionDto } from './dto/dashboard-response.dto';

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

    const [meals, settings, todaySession] = await Promise.all([
      this.prisma.mealLog.findMany({
        where: { userId, eatenAt: { gte: day.start, lt: day.end } },
      }),
      this.prisma.userSettings.findUnique({ where: { userId } }),
      this.prisma.workoutSession.findFirst({
        where: { userId, startedAt: { gte: day.start, lt: day.end } },
        orderBy: { startedAt: 'desc' },
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

    // MealLog todavía no guarda alimentos con nutrientes: el modelo MealItem
    // (decisión M-02) no existe. Cuando exista, aquí se mapean los items de
    // cada comida a Nutrients; por ahora cada comida aporta cero.
    const consumed = sumNutrition(meals.map(() => ZERO_NUTRIENTS));
    const goals = {
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
        remaining: {
          calories: goals.dailyCalorieGoal - consumed.calories,
          proteinG: goals.proteinGoalG - consumed.proteinG,
          carbsG: goals.carbsGoalG - consumed.carbsG,
          fatG: goals.fatGoalG - consumed.fatG,
        },
      },
      session: session ? toSession(session, todaySession !== null) : null,
      // Punto de extensión: el modelo de métricas corporales llega con #122.
      // Entonces se consulta la última BodyMetric del userId aquí.
      latestMetric: null,
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
