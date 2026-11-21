import 'package:fit_track_360/features/workouts/domain/tracker_finish_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arma el payload de create con endedAt, location y series', () {
    final payload = TrackerFinishPayload(
      startedAt: DateTime.utc(2026, 11, 12, 10),
      endedAt: DateTime.utc(2026, 11, 12, 11),
      notes: ' Buena sesion ',
      location: ' Gimnasio Norte ',
      sets: const [
        TrackerFinishSet(exerciseId: '0001', order: 1, weightKg: 60, reps: 10),
        TrackerFinishSet(exerciseId: '0001', order: 2, weightKg: 0, reps: 12),
      ],
    );

    expect(payload.toCreateWorkoutPayload(), {
      'startedAt': '2026-11-12T10:00:00.000Z',
      'endedAt': '2026-11-12T11:00:00.000Z',
      'notes': 'Buena sesion',
      'location': 'Gimnasio Norte',
      'sets': [
        {'exerciseId': '0001', 'order': 1, 'weight': 60, 'reps': 10},
        {'exerciseId': '0001', 'order': 2, 'weight': 0, 'reps': 12},
      ],
    });
  });
}
