/// Resumen del día que devuelve `GET /api/v1/dashboard/today`.
class DashboardToday {
  const DashboardToday({
    required this.date,
    required this.utcOffsetMinutes,
    required this.nutrition,
    required this.session,
    required this.latestMetric,
  });

  final String date;
  final int utcOffsetMinutes;
  final DayNutrition nutrition;
  final DaySession? session;
  final LatestBodyMetric? latestMetric;

  factory DashboardToday.fromJson(Map<String, dynamic> json) {
    return DashboardToday(
      date: json['date'] as String,
      utcOffsetMinutes: (json['utcOffsetMinutes'] as num).toInt(),
      nutrition: DayNutrition.fromJson(
        json['nutrition'] as Map<String, dynamic>,
      ),
      session: json['session'] == null
          ? null
          : DaySession.fromJson(json['session'] as Map<String, dynamic>),
      latestMetric: json['latestMetric'] == null
          ? null
          : LatestBodyMetric.fromJson(
              json['latestMetric'] as Map<String, dynamic>,
            ),
    );
  }
}

class DayNutrition {
  const DayNutrition({
    required this.mealsLogged,
    required this.consumed,
    required this.goals,
    required this.remaining,
  });

  final int mealsLogged;
  final Nutrients consumed;
  final NutritionGoalsSnapshot goals;
  final Nutrients remaining;

  factory DayNutrition.fromJson(Map<String, dynamic> json) {
    return DayNutrition(
      mealsLogged: (json['mealsLogged'] as num).toInt(),
      consumed: Nutrients.fromJson(json['consumed'] as Map<String, dynamic>),
      goals: NutritionGoalsSnapshot.fromJson(
        json['goals'] as Map<String, dynamic>,
      ),
      remaining: Nutrients.fromJson(json['remaining'] as Map<String, dynamic>),
    );
  }

  bool get hasMeals => mealsLogged > 0;
}

class Nutrients {
  const Nutrients({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  factory Nutrients.fromJson(Map<String, dynamic> json) {
    return Nutrients(
      calories: (json['calories'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      carbsG: (json['carbsG'] as num).toDouble(),
      fatG: (json['fatG'] as num).toDouble(),
    );
  }
}

/// Metas diarias embebidas en el DTO del dashboard (mismo shape que UserGoalsDto).
class NutritionGoalsSnapshot {
  const NutritionGoalsSnapshot({
    required this.dailyCalorieGoal,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fatGoalG,
  });

  final int dailyCalorieGoal;
  final int proteinGoalG;
  final int carbsGoalG;
  final int fatGoalG;

  factory NutritionGoalsSnapshot.fromJson(Map<String, dynamic> json) {
    return NutritionGoalsSnapshot(
      dailyCalorieGoal: (json['dailyCalorieGoal'] as num).toInt(),
      proteinGoalG: (json['proteinGoalG'] as num).toInt(),
      carbsGoalG: (json['carbsGoalG'] as num).toInt(),
      fatGoalG: (json['fatGoalG'] as num).toInt(),
    );
  }
}

/// Sesión realizada hoy o la última registrada. Nunca una rutina planeada.
class DaySession {
  const DaySession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.notes,
    required this.isToday,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final bool isToday;

  factory DaySession.fromJson(Map<String, dynamic> json) {
    return DaySession(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      notes: json['notes'] as String?,
      isToday: json['isToday'] == true,
    );
  }
}

class LatestBodyMetric {
  const LatestBodyMetric({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    required this.bodyFatPercent,
    required this.waistCm,
  });

  final String id;
  final DateTime measuredAt;
  final double? weightKg;
  final double? bodyFatPercent;
  final double? waistCm;

  factory LatestBodyMetric.fromJson(Map<String, dynamic> json) {
    return LatestBodyMetric(
      id: json['id'] as String,
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      waistCm: (json['waistCm'] as num?)?.toDouble(),
    );
  }

  bool get hasDisplayValue =>
      weightKg != null || bodyFatPercent != null || waistCm != null;
}
