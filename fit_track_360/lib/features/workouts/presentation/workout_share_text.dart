import '../domain/workout_summary.dart';
import 'workout_detail_format.dart';

String buildWorkoutShareText(WorkoutSummary summary) {
  final buffer = StringBuffer()
    ..writeln('Sesión de entrenamiento')
    ..writeln('Fecha: ${formatDateTime(summary.startedAt)}')
    ..writeln('Duración: ${formatDuration(summary.duration)}')
    ..writeln('Volumen: ${formatKg(summary.volumeKg)}')
    ..writeln('Series: ${summary.setCount}');
  if (summary.exercises.isNotEmpty) {
    buffer.writeln('Ejercicios:');
    for (final exercise in summary.exercises) {
      buffer.writeln(
        '- $exercise: '
        '${formatSetCount(summary.setsPerExercise[exercise] ?? 0)}',
      );
    }
  }
  return buffer.toString().trim();
}
