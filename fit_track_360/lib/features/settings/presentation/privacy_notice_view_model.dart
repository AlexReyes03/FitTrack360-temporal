import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../domain/privacy_notice.dart';
import '../domain/privacy_repository.dart';

const privacyUnavailableMessage = 'No pudimos cargar el aviso de privacidad.';
const privacySessionExpiredMessage =
    'Tu sesión expiró. Inicia sesión de nuevo.';
const privacyConsentFailedMessage =
    'No se pudo registrar el consentimiento. Intenta de nuevo.';
const privacyConsentVersionMessage =
    'Esta versión de la app solo registra el consentimiento del aviso '
    '$supportedPrivacyNoticeVersion. Actualiza la app para aceptar la versión '
    'vigente.';

class PrivacyNoticeViewModel extends ChangeNotifier {
  PrivacyNoticeViewModel(this._repository, {required this.userId});

  final PrivacyRepository _repository;
  final String userId;

  AsyncState<PrivacyNotice> state = const AsyncLoading();
  ConsentReceipt? receipt;
  bool submitting = false;
  String? error;

  bool _disposed = false;

  PrivacyNotice? get notice => state.dataOrNull;

  bool get versionSupported => notice?.version == supportedPrivacyNoticeVersion;

  bool get canAcceptConsent =>
      notice != null && versionSupported && receipt == null && !submitting;

  String errorMessage(Object error) => error is SessionExpiredException
      ? privacySessionExpiredMessage
      : privacyUnavailableMessage;

  Future<void> load() async {
    state = const AsyncLoading();
    error = null;
    _notify();
    try {
      final notice = await _repository.fetchNotice();
      state = notice.isEmpty ? AsyncEmpty<PrivacyNotice>() : AsyncData(notice);
    } catch (failure, stackTrace) {
      error = errorMessage(failure);
      state = AsyncError(failure, stackTrace);
    }
    _notify();
  }

  Future<void> acceptConsent() async {
    final current = notice;
    if (current == null || !canAcceptConsent) return;
    submitting = true;
    error = null;
    _notify();
    try {
      receipt = await _repository.registerConsent(
        userId: userId,
        version: current.version,
      );
    } on SessionExpiredException {
      error = privacySessionExpiredMessage;
    } catch (_) {
      error = privacyConsentFailedMessage;
    } finally {
      submitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
