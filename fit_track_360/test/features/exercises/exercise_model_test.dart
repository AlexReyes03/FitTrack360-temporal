import 'package:fit_track_360/features/exercises/data/exercise.dart';
import 'package:fit_track_360/features/exercises/data/exercise_media.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/exercise_test_support.dart';

void main() {
  group('Exercise.fromJson', () {
    test('mapea todos los campos cuando vienen completos', () {
      final exercise = Exercise.fromJson(
        exerciseJson(
          nameEs: 'Sentadilla 3/4',
          level: 'beginner',
          category: 'waist',
          muscleGroup: 'hip flexors',
          secondaryMuscles: const ['hip flexors', 'lower back'],
          instructionsEs: 'Túmbate sobre tu espalda.',
          instructionStepsEs: const ['Paso uno', 'Paso dos'],
          commonErrors: 'No curvar la espalda.',
          mediaId: '2gPfomN',
        ),
      );

      expect(exercise.id, '0001');
      expect(exercise.name, '3/4 sit-up');
      expect(exercise.nameEs, 'Sentadilla 3/4');
      expect(exercise.bodyPart, 'waist');
      expect(exercise.equipment, 'body weight');
      expect(exercise.target, 'abs');
      expect(exercise.level, 'beginner');
      expect(exercise.category, 'waist');
      expect(exercise.muscleGroup, 'hip flexors');
      expect(exercise.secondaryMuscles, ['hip flexors', 'lower back']);
      expect(exercise.instructionsEs, 'Túmbate sobre tu espalda.');
      expect(exercise.instructionStepsEs, ['Paso uno', 'Paso dos']);
      expect(exercise.commonErrors, 'No curvar la espalda.');
      expect(exercise.mediaId, '2gPfomN');
      expect(exercise.imageFile, '0001-2gPfomN.jpg');
      expect(exercise.gifFile, '0001-2gPfomN.gif');
      expect(exercise.attribution, contains('Gym visual'));
    });

    test('deja en null los campos opcionales ausentes', () {
      final exercise = Exercise.fromJson(exerciseJson());

      expect(exercise.nameEs, isNull);
      expect(exercise.level, isNull);
      expect(exercise.instructionsEs, isNull);
      expect(exercise.commonErrors, isNull);
      expect(exercise.muscleGroup, isNull);
      expect(exercise.category, isNull);
      expect(exercise.mediaId, isNull);
      expect(exercise.secondaryMuscles, isEmpty);
      expect(exercise.instructionStepsEs, isEmpty);
    });

    test('tolera que falten los archivos de media', () {
      final exercise = Exercise.fromJson(
        exerciseJson()
          ..remove('imageFile')
          ..remove('gifFile'),
      );

      expect(exercise.imageFile, '');
      expect(exercise.gifFile, '');
      expect(hasAnimation(exercise), isFalse);
    });

    test('normaliza cadenas vacías y listas con basura', () {
      final exercise = Exercise.fromJson(
        exerciseJson(nameEs: '   ', instructionsEs: '', level: '  ')
          ..['secondaryMuscles'] = ['hip flexors', '', '  ', 42]
          ..['instructionStepsEs'] = 'no-es-lista',
      );

      expect(exercise.nameEs, isNull);
      expect(exercise.instructionsEs, isNull);
      expect(exercise.level, isNull);
      expect(exercise.secondaryMuscles, ['hip flexors']);
      expect(exercise.instructionStepsEs, isEmpty);
    });

    test('exige los campos que el catálogo no puede omitir', () {
      expect(
        () => Exercise.fromJson(exerciseJson()..remove('name')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Exercise.fromJson(exerciseJson()..remove('attribution')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ExercisePage.fromJson', () {
    test('lee el sobre provisional', () {
      final page = ExercisePage.fromJson(
        pageJson([exerciseJson(), exerciseJson(id: '0002')], total: 1324),
        page: 1,
        pageSize: 20,
      );

      expect(page.items, hasLength(2));
      expect(page.total, 1324);
      expect(page.page, 1);
      expect(page.pageSize, 20);
      expect(page.totalPages, 67);
      expect(page.hasPrevious, isFalse);
      expect(page.hasNext, isTrue);
    });

    test('acepta un array plano como una sola página', () {
      final page = ExercisePage.fromJson(
        [exerciseJson(), exerciseJson(id: '0002')],
        page: 1,
        pageSize: 20,
      );

      expect(page.items, hasLength(2));
      expect(page.total, 2);
      expect(page.hasNext, isFalse);
    });

    test('calcula la última página y los extremos', () {
      final lastPage = ExercisePage.fromJson(
        pageJson([exerciseJson()], total: 41, page: 3, pageSize: 20),
        page: 3,
        pageSize: 20,
      );

      expect(lastPage.totalPages, 3);
      expect(lastPage.hasPrevious, isTrue);
      expect(lastPage.hasNext, isFalse);
    });

    test('una página vacía no promete más resultados', () {
      final page = ExercisePage.fromJson(
        pageJson(const [], total: 0),
        page: 1,
        pageSize: 20,
      );

      expect(page.items, isEmpty);
      expect(page.totalPages, 1);
      expect(page.hasNext, isFalse);
    });

    test('rechaza una respuesta que no es objeto ni lista', () {
      expect(
        () => ExercisePage.fromJson('texto', page: 1, pageSize: 20),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('URLs de media', () {
    test('el GIF usa la ruta estática de videos', () {
      final url = exerciseGifUrl('0001-2gPfomN.gif');

      expect(url, endsWith('/static/exercises/videos/0001-2gPfomN.gif'));
      expect(url, contains(exerciseMediaBaseUrl(exerciseVideosPath)));
    });

    test('la imagen usa la ruta estática de imágenes', () {
      final url = exerciseImageUrl('0001-2gPfomN.jpg');

      expect(url, endsWith('/static/exercises/images/0001-2gPfomN.jpg'));
    });

    test('codifica nombres con caracteres especiales', () {
      expect(exerciseImageUrl('foto uno.jpg'), endsWith('foto%20uno.jpg'));
    });

    test('hasAnimation distingue un GIF declarado de uno vacío', () {
      expect(hasAnimation(Exercise.fromJson(exerciseJson())), isTrue);
      expect(
        hasAnimation(
          const Exercise(
            id: '0001',
            name: '3/4 sit-up',
            bodyPart: 'waist',
            equipment: 'body weight',
            target: 'abs',
            imageFile: '0001-2gPfomN.jpg',
            gifFile: '   ',
            attribution: '© Gym visual — https://gymvisual.com/',
          ),
        ),
        isFalse,
      );
    });
  });
}
