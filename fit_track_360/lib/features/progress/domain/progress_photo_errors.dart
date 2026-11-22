/// Foto ajena, inexistente o ilegible. El mensaje no filtra si existe.
class ProgressPhotoUnavailableException implements Exception {
  const ProgressPhotoUnavailableException();

  @override
  String toString() => 'Foto no disponible';
}

/// Base de los errores al subir o borrar fotos de progreso.
abstract class ProgressPhotoException implements Exception {
  const ProgressPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// La foto o sus campos no son válidos (cliente o 400 del API).
class ProgressPhotoValidationException extends ProgressPhotoException {
  const ProgressPhotoValidationException(super.message);
}

/// Fallo del servidor o de red al subir/borrar la foto.
class ProgressPhotoUploadException extends ProgressPhotoException {
  const ProgressPhotoUploadException(super.message);
}
