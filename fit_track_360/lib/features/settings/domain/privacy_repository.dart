import 'privacy_notice.dart';

class ConsentRejectedException implements Exception {
  const ConsentRejectedException([
    this.message = 'Consentimiento no confirmado',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ConsentReceipt {
  const ConsentReceipt({required this.version});

  final String version;
}

abstract class PrivacyRepository {
  Future<PrivacyNotice> fetchNotice();

  /// Solo hay recibo si el servidor confirma la misma [version].
  Future<ConsentReceipt> registerConsent({
    required String userId,
    required String version,
  });
}
