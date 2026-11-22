import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';

/// Contrato del API de dispositivos push. Lo implementa [DeviceTokenApi].
abstract interface class DeviceTokenClient {
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  });

  Future<void> revokeDeviceToken({required String token});
}

/// Error del API de dispositivos push.
class DeviceTokenApiException implements Exception {
  const DeviceTokenApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente de `/api/v1/notifications/devices`.
///
/// Registro: `POST /devices` con `{token, platform}`.
/// Revocación: `POST /devices/revoke` con `{token}`; ante 404/405 intenta
/// `DELETE /devices/:token`. Un 404 final se considera éxito por la regla S4.
class DeviceTokenApi implements DeviceTokenClient {
  DeviceTokenApi(this._client);

  final ApiClient _client;

  static const _path = '/api/v1/notifications/devices';

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final response = await _client.post(
      _path,
      body: {'token': token, 'platform': platform},
    );
    if (_isSuccess(response.statusCode)) return;
    throw DeviceTokenApiException(
      apiErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  @override
  Future<void> revokeDeviceToken({required String token}) async {
    final response = await _client.post(
      '$_path/revoke',
      body: {'token': token},
    );
    if (_isSuccess(response.statusCode)) return;

    if (response.statusCode == 404 || response.statusCode == 405) {
      final fallback = await _client.delete(
        '$_path/${Uri.encodeComponent(token)}',
      );
      if (_isSuccess(fallback.statusCode) || fallback.statusCode == 404) {
        return;
      }
      throw DeviceTokenApiException(
        apiErrorMessage(fallback),
        statusCode: fallback.statusCode,
      );
    }

    throw DeviceTokenApiException(
      apiErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  static bool _isSuccess(int statusCode) =>
      statusCode == 200 || statusCode == 201 || statusCode == 204;
}
