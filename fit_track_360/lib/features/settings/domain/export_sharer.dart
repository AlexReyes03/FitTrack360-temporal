import 'dart:ui' show Rect;

/// Nombre del archivo exportado con la fecha local: `fittrack360-export-YYYY-MM-DD.json`.
String exportFileName(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'fittrack360-export-${date.year}-${two(date.month)}-'
      '${two(date.day)}.json';
}

/// Comparte la exportación con la hoja del sistema (O10).
///
/// Lanza si la plataforma no puede abrir la hoja; quien llama decide la
/// degradación. Cancelar la hoja no es un error.
abstract class ExportSharer {
  /// [origin] ancla la hoja en iPad (coordenadas globales del botón).
  Future<void> shareJson({
    required String json,
    required String fileName,
    Rect? origin,
  });
}
