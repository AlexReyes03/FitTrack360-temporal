/// Metas diarias: calorías (kcal) y macros (gramos).
class NutritionGoals {
  const NutritionGoals({
    required this.dailyCalorieGoal,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fatGoalG,
  });

  final int dailyCalorieGoal;
  final int proteinGoalG;
  final int carbsGoalG;
  final int fatGoalG;

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
    dailyCalorieGoal: (json['dailyCalorieGoal'] as num).toInt(),
    proteinGoalG: (json['proteinGoalG'] as num).toInt(),
    carbsGoalG: (json['carbsGoalG'] as num).toInt(),
    fatGoalG: (json['fatGoalG'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'dailyCalorieGoal': dailyCalorieGoal,
    'proteinGoalG': proteinGoalG,
    'carbsGoalG': carbsGoalG,
    'fatGoalG': fatGoalG,
  };

  @override
  bool operator ==(Object other) =>
      other is NutritionGoals &&
      other.dailyCalorieGoal == dailyCalorieGoal &&
      other.proteinGoalG == proteinGoalG &&
      other.carbsGoalG == carbsGoalG &&
      other.fatGoalG == fatGoalG;

  @override
  int get hashCode =>
      Object.hash(dailyCalorieGoal, proteinGoalG, carbsGoalG, fatGoalG);
}

enum WeightUnit { kg, lb }

enum DistanceUnit { km, mi }

/// Unidades, descanso entre series y opciones de P3 y O1.
class UserPreferences {
  const UserPreferences({
    required this.weightUnit,
    required this.distanceUnit,
    required this.restSeconds,
    required this.notificationsEnabled,
    required this.biometricEnabled,
  });

  final WeightUnit weightUnit;
  final DistanceUnit distanceUnit;
  final int restSeconds;
  final bool notificationsEnabled;
  final bool biometricEnabled;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        weightUnit: json['weightUnit'] == 'lb' ? WeightUnit.lb : WeightUnit.kg,
        distanceUnit: json['distanceUnit'] == 'mi'
            ? DistanceUnit.mi
            : DistanceUnit.km,
        restSeconds: (json['restSeconds'] as num).toInt(),
        notificationsEnabled: json['notificationsEnabled'] == true,
        biometricEnabled: json['biometricEnabled'] == true,
      );

  Map<String, dynamic> toJson() => {
    'weightUnit': weightUnit.name,
    'distanceUnit': distanceUnit.name,
    'restSeconds': restSeconds,
    'notificationsEnabled': notificationsEnabled,
    'biometricEnabled': biometricEnabled,
  };

  UserPreferences copyWith({
    WeightUnit? weightUnit,
    DistanceUnit? distanceUnit,
    int? restSeconds,
    bool? notificationsEnabled,
    bool? biometricEnabled,
  }) => UserPreferences(
    weightUnit: weightUnit ?? this.weightUnit,
    distanceUnit: distanceUnit ?? this.distanceUnit,
    restSeconds: restSeconds ?? this.restSeconds,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.weightUnit == weightUnit &&
      other.distanceUnit == distanceUnit &&
      other.restSeconds == restSeconds &&
      other.notificationsEnabled == notificationsEnabled &&
      other.biometricEnabled == biometricEnabled;

  @override
  int get hashCode => Object.hash(
    weightUnit,
    distanceUnit,
    restSeconds,
    notificationsEnabled,
    biometricEnabled,
  );
}

/// Perfil completo que devuelve `GET /api/v1/users/me`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.goals,
    required this.preferences,
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final NutritionGoals goals;
  final UserPreferences preferences;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    displayName: json['displayName'] as String,
    goals: NutritionGoals.fromJson(json['goals'] as Map<String, dynamic>),
    preferences: UserPreferences.fromJson(
      json['preferences'] as Map<String, dynamic>,
    ),
  );
}

/// Cambios parciales para `PATCH /api/v1/users/me`: solo viaja lo no nulo.
class ProfileUpdate {
  const ProfileUpdate({this.displayName, this.goals, this.preferences});

  final String? displayName;
  final NutritionGoals? goals;
  final UserPreferences? preferences;

  Map<String, dynamic> toJson() => {
    if (displayName != null) 'displayName': displayName,
    if (goals != null) 'goals': goals!.toJson(),
    if (preferences != null) 'preferences': preferences!.toJson(),
  };
}
