import 'dart:async';
import 'dart:typed_data';

import 'package:fit_track_360/features/progress/data/progress_photos_api.dart';

class FakeProgressPhotoLoader implements ProgressPhotoLoader {
  FakeProgressPhotoLoader({
    Map<String, Uint8List>? bytes,
    Map<String, Object>? errors,
    Set<String>? failFirst,
    Map<String, Completer<Uint8List>>? gates,
  }) : bytes = bytes ?? {},
       errors = errors ?? {},
       failFirst = failFirst ?? {},
       gates = gates ?? {};

  final Map<String, Uint8List> bytes;
  final Map<String, Object> errors;
  final Set<String> failFirst;
  final Map<String, Completer<Uint8List>> gates;
  final Map<String, int> calls = {};

  @override
  Future<Uint8List> load(String photoId) {
    calls[photoId] = (calls[photoId] ?? 0) + 1;

    final gate = gates[photoId];
    if (gate != null) return gate.future;

    if (failFirst.remove(photoId)) {
      return Future.error(errors[photoId] ?? Exception('fallo'));
    }

    final value = bytes[photoId];
    if (value != null) return Future.value(value);

    final error = errors[photoId];
    if (error != null) return Future.error(error);

    return Future.error(Exception('sin datos'));
  }
}
