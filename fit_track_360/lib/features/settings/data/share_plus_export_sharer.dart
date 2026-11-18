import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import '../domain/export_sharer.dart';

/// [ExportSharer] sobre `share_plus` (O10). Sin permisos: el plugin escribe
/// el archivo en la caché temporal de la app y abre la hoja del sistema.
class SharePlusExportSharer implements ExportSharer {
  SharePlusExportSharer({SharePlus? sharePlus})
    : _share = sharePlus ?? SharePlus.instance;

  final SharePlus _share;

  @override
  Future<void> shareJson({
    required String json,
    required String fileName,
    Rect? origin,
  }) async {
    await _share.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        // `XFile.fromData` ignora `name` en Android e iOS.
        fileNameOverrides: [fileName],
        subject: 'Mis datos de FitTrack360',
        title: 'Exportar mis datos',
        sharePositionOrigin: origin,
      ),
    );
  }
}
