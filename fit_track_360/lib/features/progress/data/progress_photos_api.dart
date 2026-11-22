import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/progress_photo_errors.dart';
import '../domain/progress_photo_meta.dart';
import '../domain/progress_photos_repository.dart';

export '../domain/progress_photo_errors.dart';

abstract interface class ProgressPhotoLoader {
  Future<Uint8List> load(String photoId);
}

/// Cliente de `POST/GET/DELETE /api/v1/photos`.
///
/// Ownership: foto ajena o inexistente → 404 del API →
/// [ProgressPhotoUnavailableException] (sin filtrar existencia).
class ProgressPhotosApi
    implements ProgressPhotoLoader, ProgressPhotosRepository {
  ProgressPhotosApi(this._client);

  final ApiClient _client;

  static const _path = '/api/v1/photos';

  /// Sube una foto de progreso. [metricId] solo cuando exista CRUD #122.
  @override
  Future<ProgressPhotoMeta> upload(
    File file, {
    String? metricId,
    String? mealId,
  }) async {
    if (metricId != null && mealId != null) {
      throw const ProgressPhotoValidationException(
        'Indique comida o métrica, no ambas',
      );
    }
    final fields = <String, String>{'metricId': ?metricId, 'mealId': ?mealId};
    final response = await _client.uploadFile(
      _path,
      file,
      fields: fields.isEmpty ? null : fields,
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw const ProgressPhotoUnavailableException();
      }
      throw _uploadError(response);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const ProgressPhotoUploadException('No se pudo subir la foto');
    }
    return ProgressPhotoMeta.fromJson(body);
  }

  @override
  Future<Uint8List> load(String photoId) async {
    final response = await _client.get(
      '$_path/${Uri.encodeComponent(photoId)}',
    );
    // 404, foto ajena y error comparten mensaje: no se filtra si existe.
    if (response.statusCode != 200) {
      throw const ProgressPhotoUnavailableException();
    }
    return response.bodyBytes;
  }

  @override
  Future<void> delete(String photoId) async {
    final response = await _client.delete(
      '$_path/${Uri.encodeComponent(photoId)}',
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    if (response.statusCode == 404) {
      throw const ProgressPhotoUnavailableException();
    }
    throw ProgressPhotoUploadException(apiErrorMessage(response));
  }

  /// 400/413/415: la imagen no pasó la validación del API (formato, tamaño).
  static ProgressPhotoException _uploadError(http.Response response) {
    final message = apiErrorMessage(response);
    switch (response.statusCode) {
      case 400:
      case 413:
      case 415:
        return ProgressPhotoValidationException(message);
      default:
        return ProgressPhotoUploadException(message);
    }
  }
}
