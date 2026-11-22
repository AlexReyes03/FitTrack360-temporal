import 'dart:ui' show Rect;

enum WorkoutShareResult { shared, dismissed, unavailable }

abstract interface class WorkoutSummarySharer {
  Future<WorkoutShareResult> shareText({required String text, Rect? origin});
}
