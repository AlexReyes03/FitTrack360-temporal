import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart' show AuthApiException, apiErrorMessage;
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// [ProfileRepository] sobre el API; [ApiClient] pone el Bearer y refresca.
class ProfileApiRepository implements ProfileRepository {
  ProfileApiRepository(this._client);

  final ApiClient _client;

  static const _mePath = '/api/v1/users/me';

  @override
  Future<UserProfile?> fetchProfile() async {
    final response = await _client.get(_mePath);
    if (response.statusCode == 204 || response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return UserProfile.fromJson(_decode(response.bodyBytes));
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async {
    final response = await _client.patch(_mePath, body: update.toJson());
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return UserProfile.fromJson(_decode(response.bodyBytes));
  }

  @override
  Future<int> countWorkouts() async {
    final response = await _client.get('/api/v1/workouts');
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) throw const AuthApiException('No se pudo conectar');
    return body.length;
  }

  @override
  Future<String> exportData() async {
    try {
      final response = await _client.get('$_mePath/export');
      if (response.statusCode != 200) {
        throw const ExportUnavailableException();
      }
      final text = utf8.decode(response.bodyBytes);
      jsonDecode(text); // Solo se acepta JSON válido.
      return text;
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      throw const ExportUnavailableException();
    }
  }

  Map<String, dynamic> _decode(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
