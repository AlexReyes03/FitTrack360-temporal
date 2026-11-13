import 'package:fit_track_360/features/settings/domain/profile_validation.dart';
import 'package:fit_track_360/features/settings/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

ProfileForm _form({
  String name = 'Ana',
  String calories = '2000',
  String protein = '150',
  String carbs = '250',
  String fat = '65',
  String rest = '90',
}) => ProfileForm(
  displayName: name,
  dailyCalorieGoal: calories,
  proteinGoalG: protein,
  carbsGoalG: carbs,
  fatGoalG: fat,
  restSeconds: rest,
);

void main() {
  group('validateProfileForm (paridad con el API)', () {
    test('acepta valores válidos y recorta el nombre', () {
      final result = validateProfileForm(_form(name: '  Ana  '));
      expect(result.isValid, isTrue);
      expect(result.displayName, 'Ana');
      expect(result.goals, sampleGoals);
      expect(result.restSeconds, 90);
    });

    test('rechaza meta de calorías <= 0 y > 20000', () {
      for (final value in ['0', '-5', '20001']) {
        final result = validateProfileForm(_form(calories: value));
        expect(result.errors['dailyCalorieGoal'], isNotNull, reason: value);
      }
      expect(validateProfileForm(_form(calories: '1')).isValid, isTrue);
      expect(validateProfileForm(_form(calories: '20000')).isValid, isTrue);
    });

    test('rechaza macro negativo o > 2000 y acepta 0', () {
      expect(
        validateProfileForm(_form(protein: '-1')).errors['proteinGoalG'],
        'El macro debe estar entre 0 y 2000 g.',
      );
      expect(
        validateProfileForm(_form(carbs: '2001')).errors,
        contains('carbsGoalG'),
      );
      expect(validateProfileForm(_form(fat: '0')).isValid, isTrue);
    });

    test('rechaza nombre vacío o de más de 80 caracteres', () {
      expect(
        validateProfileForm(_form(name: '   ')).errors['displayName'],
        'Escribe tu nombre.',
      );
      expect(
        validateProfileForm(_form(name: 'a' * 81)).errors,
        contains('displayName'),
      );
      expect(validateProfileForm(_form(name: 'a' * 80)).isValid, isTrue);
    });

    test('rechaza descanso fuera de 1..3600 y texto no numérico', () {
      expect(
        validateProfileForm(_form(rest: '0')).errors,
        contains('restSeconds'),
      );
      expect(
        validateProfileForm(_form(rest: '3601')).errors,
        contains('restSeconds'),
      );
      expect(
        validateProfileForm(_form(calories: 'abc')).errors['dailyCalorieGoal'],
        'Escribe un número entero.',
      );
    });
  });

  group('mapeo JSON', () {
    test('UserProfile.fromJson lee metas y preferencias', () {
      final json = sampleProfileJson();
      json['preferences'] = {
        ...samplePreferences.toJson(),
        'weightUnit': 'lb',
        'distanceUnit': 'mi',
        'biometricEnabled': true,
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.displayName, 'Ana');
      expect(profile.goals, sampleGoals);
      expect(profile.preferences.weightUnit, WeightUnit.lb);
      expect(profile.preferences.distanceUnit, DistanceUnit.mi);
      expect(profile.preferences.biometricEnabled, isTrue);
    });

    test('ProfileUpdate.toJson solo envía lo que cambia', () {
      expect(const ProfileUpdate(displayName: 'Bea').toJson(), {
        'displayName': 'Bea',
      });
      expect(const ProfileUpdate(preferences: samplePreferences).toJson(), {
        'preferences': samplePreferences.toJson(),
      });
    });
  });
}
