import 'package:fit_track_360/features/progress/domain/progress_photo.dart';

ProgressPhotoRef photoRef(String id, [DateTime? takenAt]) {
  return ProgressPhotoRef(id: id, takenAt: takenAt);
}
