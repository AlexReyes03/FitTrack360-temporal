import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import '../domain/workout_summary_sharer.dart';

class SharePlusWorkoutSummarySharer implements WorkoutSummarySharer {
  SharePlusWorkoutSummarySharer({SharePlus? sharePlus})
    : _share = sharePlus ?? SharePlus.instance;

  final SharePlus _share;

  @override
  Future<WorkoutShareResult> shareText({
    required String text,
    Rect? origin,
  }) async {
    final result = await _share.share(
      ShareParams(
        text: text,
        subject: 'Resumen de entrenamiento',
        sharePositionOrigin: origin,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => WorkoutShareResult.shared,
      ShareResultStatus.dismissed => WorkoutShareResult.dismissed,
      ShareResultStatus.unavailable => WorkoutShareResult.unavailable,
    };
  }
}
