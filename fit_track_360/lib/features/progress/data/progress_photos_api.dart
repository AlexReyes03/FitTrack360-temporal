import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/progress_photo_meta.dart';

abstract interface class ProgressPhotoLoader {
  Future<Uint8List> load(String photoId);
}

class ProgressPhotoUnavailableException implements Exception {
  const ProgressPhotoUnavailableException();

  @override
  String toString() => 'Foto no disponible';
}

/// Cliente de `POST/GET/DELETE /api/v1/photos`.
///
/// Ownership: foto ajena o inexistente → 404 del API →
/// [ProgressPhotoUnavailableException] (sin filtrar existencia).
class ProgressPhotosApi implements ProgressPhotoLoader {
  ProgressPhotosApi(this._client);

  final ApiClient _client;

  static const _path = '/api/v1/photos';

  /// Sube una foto de progreso. [metricId] solo cuando exista CRUD #122.
  Future<ProgressPhotoMeta> upload(
    File file, {
    String? metricId,
    String? mealId,
  }) async {
    if (metricId != null && mealId != null) {
      throw const AuthApiException('Indique comida o métrica, no ambas');
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
      throw AuthApiException(apiErrorMessage(response));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const AuthApiException('No se pudo conectar');
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

  Future<void> delete(String photoId) async {
    final response = await _client.delete(
      '$_path/${Uri.encodeComponent(photoId)}',
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    if (response.statusCode == 404) {
      throw const ProgressPhotoUnavailableException();
    }
    throw AuthApiException(apiErrorMessage(response));
  }
}
