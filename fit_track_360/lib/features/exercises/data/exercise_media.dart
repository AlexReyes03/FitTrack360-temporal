import '../../auth/data/auth_api.dart';
import 'exercise.dart';

/// Rutas estáticas de la media, servidas por `@nestjs/serve-static` fuera de
/// `/api/v1`.
const String exerciseImagesPath = '/static/exercises/images';
const String exerciseVideosPath = '/static/exercises/videos';

/// Miniatura JPG; se usa como respaldo del GIF.
String exerciseImageUrl(String imageFile) =>
    '${exerciseMediaBaseUrl(exerciseImagesPath)}/${_segment(imageFile)}';

String exerciseGifUrl(String gifFile) =>
    '${exerciseMediaBaseUrl(exerciseVideosPath)}/${_segment(gifFile)}';

/// Base del API sin barra final, para no duplicar `//` en la URL.
String exerciseMediaBaseUrl(String path) {
  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return '$base$path';
}

bool hasAnimation(Exercise exercise) => exercise.gifFile.trim().isNotEmpty;

String _segment(String fileName) => Uri.encodeComponent(fileName.trim());
