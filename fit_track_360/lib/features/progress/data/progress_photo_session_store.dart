import 'package:flutter/foundation.dart';

import '../domain/progress_photo_meta.dart';

/// Fotos de progreso subidas en esta sesión de la app.
///
/// El API no expone `GET /photos` (lista), así que `/app/foto`, el check-in y
/// la comparación comparten este registro en memoria para que una foto subida
/// en cualquier pantalla aparezca en Progreso sin reiniciar. Se pierde al
/// cerrar la app; cuando exista el listado en backend se cargará de ahí.
class ProgressPhotoSessionStore extends ChangeNotifier {
  ProgressPhotoSessionStore();

  /// Registro compartido de la app (Progreso y `/app/foto`).
  static final ProgressPhotoSessionStore instance = ProgressPhotoSessionStore();

  final List<ProgressPhotoMeta> _photos = [];

  List<ProgressPhotoMeta> get photos => List.unmodifiable(_photos);

  void add(ProgressPhotoMeta photo) {
    if (_photos.any((p) => p.id == photo.id)) return;
    _photos.add(photo);
    notifyListeners();
  }

  void remove(String photoId) {
    final before = _photos.length;
    _photos.removeWhere((p) => p.id == photoId);
    if (_photos.length != before) notifyListeners();
  }

  /// Limpia el registro (p. ej. al expirar la sesión) para no mezclar fotos
  /// de otra cuenta.
  void clear() {
    if (_photos.isEmpty) return;
    _photos.clear();
    notifyListeners();
  }
}
