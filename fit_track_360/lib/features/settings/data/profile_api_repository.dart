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
  Future<String> exportData() async {
    try {
      final response = await _client.get('$_mePath/export');
      if (response.statusCode != 200) {
        throw const ExportUnavailableException();
      }
      final text = utf8.decode(response.bodyBytes);
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      throw const ExportUnavailableException();
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final response = await _client.delete(_mePath);
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw const AccountDeletionException();
      }
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      throw const AccountDeletionException();
    }
  }

  Map<String, dynamic> _decode(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
