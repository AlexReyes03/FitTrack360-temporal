import 'user_profile.dart';

/// Límites iguales a los del API (paridad F5/S7): calorías 1..20000,
/// macros 0..2000 g, descanso 1..3600 s y nombre de 1 a 80 caracteres.
class ProfileLimits {
  ProfileLimits._();

  static const int minCalories = 1;
  static const int maxCalories = 20000;
  static const int minMacro = 0;
  static const int maxMacro = 2000;
  static const int minRestSeconds = 1;
  static const int maxRestSeconds = 3600;
  static const int maxDisplayNameLength = 80;
}

/// Texto capturado en el formulario de Perfil, antes de validar.
class ProfileForm {
  const ProfileForm({
    required this.displayName,
    required this.dailyCalorieGoal,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fatGoalG,
    required this.restSeconds,
  });

  final String displayName;
  final String dailyCalorieGoal;
  final String proteinGoalG;
  final String carbsGoalG;
  final String fatGoalG;
  final String restSeconds;
}

/// Resultado de validar: errores por campo o, si no hay, los valores limpios.
class ProfileValidationResult {
  const ProfileValidationResult._({
    required this.errors,
    this.displayName,
    this.goals,
    this.restSeconds,
  });

  /// Claves con los nombres de campo del API (`displayName`, `fatGoalG`...).
  final Map<String, String> errors;
  final String? displayName;
  final NutritionGoals? goals;
  final int? restSeconds;

  bool get isValid => errors.isEmpty;
}

String? validateDisplayName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Escribe tu nombre.';
  if (trimmed.length > ProfileLimits.maxDisplayNameLength) {
    return 'El nombre no puede pasar de 80 caracteres.';
  }
  return null;
}

String? validateCalorieGoal(int? value) {
  if (value == null) return 'Escribe un número entero.';
  if (value < ProfileLimits.minCalories || value > ProfileLimits.maxCalories) {
    return 'La meta de calorías debe estar entre 1 y 20000.';
  }
  return null;
}

String? validateMacro(int? value) {
  if (value == null) return 'Escribe un número entero.';
  if (value < ProfileLimits.minMacro || value > ProfileLimits.maxMacro) {
    return 'El macro debe estar entre 0 y 2000 g.';
  }
  return null;
}

String? validateRestSeconds(int? value) {
  if (value == null) return 'Escribe un número entero.';
  if (value < ProfileLimits.minRestSeconds ||
      value > ProfileLimits.maxRestSeconds) {
    return 'El descanso debe estar entre 1 y 3600 segundos.';
  }
  return null;
}

int? _parseInt(String text) => int.tryParse(text.trim());

/// Valida el formulario completo antes de llamar al API.
ProfileValidationResult validateProfileForm(ProfileForm form) {
  final calories = _parseInt(form.dailyCalorieGoal);
  final protein = _parseInt(form.proteinGoalG);
  final carbs = _parseInt(form.carbsGoalG);
  final fat = _parseInt(form.fatGoalG);
  final rest = _parseInt(form.restSeconds);

  final errors = <String, String>{};
  void check(String field, String? error) {
    if (error != null) errors[field] = error;
  }

  check('displayName', validateDisplayName(form.displayName));
  check('dailyCalorieGoal', validateCalorieGoal(calories));
  check('proteinGoalG', validateMacro(protein));
  check('carbsGoalG', validateMacro(carbs));
  check('fatGoalG', validateMacro(fat));
  check('restSeconds', validateRestSeconds(rest));

  if (errors.isNotEmpty) return ProfileValidationResult._(errors: errors);
  return ProfileValidationResult._(
    errors: const {},
    displayName: form.displayName.trim(),
    goals: NutritionGoals(
      dailyCalorieGoal: calories!,
      proteinGoalG: protein!,
      carbsGoalG: carbs!,
      fatGoalG: fat!,
    ),
    restSeconds: rest,
  );
}
