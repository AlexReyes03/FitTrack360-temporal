import 'dart:typed_data';

import '../../../core/network/api_client.dart';

abstract interface class ProgressPhotoLoader {
  Future<Uint8List> load(String photoId);
}

class ProgressPhotoUnavailableException implements Exception {
  const ProgressPhotoUnavailableException();

  @override
  String toString() => 'Foto no disponible';
}

class ProgressPhotosApi implements ProgressPhotoLoader {
  ProgressPhotosApi(this._client);

  final ApiClient _client;

  @override
  Future<Uint8List> load(String photoId) async {
    final response = await _client.get(
      '/api/v1/photos/${Uri.encodeComponent(photoId)}',
    );
    // 404, foto ajena y error comparten mensaje: no se filtra si existe.
    if (response.statusCode != 200) {
      throw const ProgressPhotoUnavailableException();
    }
    return response.bodyBytes;
  }
}
