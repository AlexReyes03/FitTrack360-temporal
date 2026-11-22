import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart' show AuthApiException, apiErrorMessage;
import '../domain/privacy_notice.dart';
import '../domain/privacy_repository.dart';

class PrivacyApiRepository implements PrivacyRepository {
  PrivacyApiRepository(this._client);

  final ApiClient _client;

  static const _noticePath = '/api/v1/privacy/notice';

  @override
  Future<PrivacyNotice> fetchNotice() async {
    final response = await _client.get(_noticePath);
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return PrivacyNotice.fromJson(_decode(response.bodyBytes));
  }

  @override
  Future<ConsentReceipt> registerConsent({
    required String userId,
    required String version,
  }) async {
    final response = await _client.post(
      '/api/v1/privacy/${Uri.encodeComponent(userId)}/consent',
      body: {'consent': true, 'version': version},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthApiException(apiErrorMessage(response));
    }
    final confirmed = _decode(response.bodyBytes)['privacyNoticeVersion'];
    if (confirmed != version) throw const ConsentRejectedException();
    return ConsentReceipt(version: version);
  }

  Map<String, dynamic> _decode(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
