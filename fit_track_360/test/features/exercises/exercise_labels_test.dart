import 'package:fit_track_360/features/exercises/data/exercise_labels.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cómo se vería un valor sin traducción: primera letra en mayúscula.
String humanized(String value) => value[0].toUpperCase() + value.substring(1);

void main() {
  group('mapa de traducción', () {
    // "cardio" se escribe igual en español; el resto debe diferir del valor
    // original para probar que el mapa sí lo cubre.
    const identicalInSpanish = <String>{'cardio'};

    test('traduce todos los bodyPart del dataset', () {
      for (final option in bodyPartOptions) {
        final label = translateBodyPart(option);
        expect(label, isNotEmpty, reason: 'bodyPart sin etiqueta: $option');
        if (!identicalInSpanish.contains(option)) {
          expect(
            label,
            isNot(humanized(option)),
            reason: 'bodyPart sin traducción: $option',
          );
        }
      }
    });

    test('traduce todos los equipment del dataset', () {
      for (final option in equipmentOptions) {
        expect(
          translateEquipment(option),
          isNot(humanized(option)),
          reason: 'equipment sin traducción: $option',
        );
      }
    });

    test('traduce todos los target del dataset', () {
      for (final option in targetOptions) {
        expect(
          translateTarget(option),
          isNot(humanized(option)),
          reason: 'target sin traducción: $option',
        );
      }
    });
  });

  group('etiquetas conocidas', () {
    test('grupo muscular', () {
      expect(translateBodyPart('chest'), 'Pecho');
      expect(translateBodyPart('lower arms'), 'Antebrazos');
      expect(translateBodyPart('upper legs'), 'Muslos');
      expect(translateBodyPart('cardio'), 'Cardio');
    });

    test('músculos secundarios y grupo muscular', () {
      expect(translateMuscle('hip flexors'), 'Flexores de cadera');
      expect(translateMuscle('lower back'), 'Espalda baja');
      expect(translateMuscle('latissimus dorsi'), 'Dorsal ancho');
      // Reutiliza el vocabulario de target cuando coincide.
      expect(translateMuscle('lats'), 'Dorsales');
    });

    test('equipo', () {
      expect(translateEquipment('body weight'), 'Peso corporal');
      expect(translateEquipment('dumbbell'), 'Mancuerna');
      expect(translateEquipment('smith machine'), 'Máquina Smith');
    });

    test('objetivo', () {
      expect(translateTarget('pectorals'), 'Pectorales');
      expect(translateTarget('lats'), 'Dorsales');
      expect(
        translateTarget('cardiovascular system'),
        'Sistema cardiovascular',
      );
    });
  });

  group('valores desconocidos', () {
    test('no se inventan traducciones: se deja el valor legible', () {
      expect(translateBodyPart('new zone'), 'New zone');
      expect(translateEquipment('  turbo machine  '), 'Turbo machine');
      expect(translateTarget('nuevo musculo'), 'Nuevo musculo');
    });

    test('un valor vacío no rompe la etiqueta', () {
      expect(translateBodyPart(''), '');
    });
  });
}
