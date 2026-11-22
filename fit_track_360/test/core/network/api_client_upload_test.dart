import 'dart:io';
import 'dart:typed_data';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FakeStorage implements SessionStorage {
  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      'access';

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

/// Captura la [http.MultipartRequest] sin materializarla, para inspeccionar
/// el content type de cada parte.
class _CapturingClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    await request.finalize().drain<void>();
    return http.StreamedResponse(Stream.value('{}'.codeUnits), 201);
  }
}

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46]);
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D, //
]);
final _webp = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, //
]);

Future<String> _uploadedContentType(
  String fileName,
  List<int> bytes, {
  String path = '/api/v1/photos',
}) async {
  final dir = await Directory.systemTemp.createTemp('ft360-upload-');
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  final client = _CapturingClient();
  final api = ApiClient(storage: _FakeStorage(), httpClient: client);
  try {
    await api.uploadFile(path, file);
    final request = client.requests.single as http.MultipartRequest;
    final part = request.files.single;
    expect(part.field, 'file');
    return part.contentType.mimeType;
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  test('sube JPEG con content type image/jpeg (no octet-stream)', () async {
    expect(await _uploadedContentType('foto.jpg', _jpeg), 'image/jpeg');
  });

  test('sube PNG con content type image/png', () async {
    expect(await _uploadedContentType('foto.png', _png), 'image/png');
  });

  test('sube WebP con content type image/webp', () async {
    expect(await _uploadedContentType('foto.webp', _webp), 'image/webp');
  });

  test('los bytes mandan sobre una extensión engañosa', () async {
    expect(await _uploadedContentType('foto.jpg', _png), 'image/png');
  });

  test('sin firma conocida usa la extensión', () async {
    expect(await _uploadedContentType('FOTO.JPEG', [1, 2, 3]), 'image/jpeg');
  });

  test('archivo genérico a /storage/files sigue como octet-stream', () async {
    expect(
      await _uploadedContentType('notas.bin', [
        1,
        2,
        3,
        4,
      ], path: '/api/v1/storage/files'),
      'application/octet-stream',
    );
  });
}
