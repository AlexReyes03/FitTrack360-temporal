import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Permiso efectivo para recibir notificaciones push.
enum FcmAuthorizationStatus { authorized, provisional, denied, notSupported }

/// Contrato testeable sobre `FirebaseMessaging`.
///
/// Todas las implementaciones deben degradar sin lanzar cuando el plugin,
/// Firebase, Play Services o APNs no estén disponibles.
abstract interface class FcmMessagingGateway {
  bool get isSupported;

  /// `'android'` o `'ios'`; null en plataformas no soportadas.
  String? get platformName;

  Future<FcmAuthorizationStatus> requestPermission();

  Future<FcmAuthorizationStatus> getNotificationSettings();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Future<void> deleteToken();
}

/// Envoltorio real sobre `FirebaseMessaging.instance`.
///
/// Nunca imprime ni registra el valor del token. Cualquier `FirebaseException`,
/// `MissingPluginException` o error de plataforma se traduce a `null` /
/// [FcmAuthorizationStatus.notSupported].
class FirebaseMessagingGateway implements FcmMessagingGateway {
  FirebaseMessagingGateway({FirebaseMessaging? messaging})
    : _messagingClient = messaging;

  final FirebaseMessaging? _messagingClient;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  String? get platformName => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };

  FirebaseMessaging? get _instance {
    if (_messagingClient != null) return _messagingClient;
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FcmAuthorizationStatus> requestPermission() async {
    if (!isSupported) return FcmAuthorizationStatus.notSupported;
    final messaging = _instance;
    if (messaging == null) return FcmAuthorizationStatus.notSupported;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _mapStatus(settings.authorizationStatus);
    } catch (_) {
      return FcmAuthorizationStatus.notSupported;
    }
  }

  @override
  Future<FcmAuthorizationStatus> getNotificationSettings() async {
    if (!isSupported) return FcmAuthorizationStatus.notSupported;
    final messaging = _instance;
    if (messaging == null) return FcmAuthorizationStatus.notSupported;
    try {
      final settings = await messaging.getNotificationSettings();
      return _mapStatus(settings.authorizationStatus);
    } catch (_) {
      return FcmAuthorizationStatus.notSupported;
    }
  }

  @override
  Future<String?> getToken() async {
    if (!isSupported) return null;
    final messaging = _instance;
    if (messaging == null) return null;
    try {
      // El backend envia con firebase-admin al token de registro clasico;
      // la API de FID de la version 17 no cumple ese contrato.
      // ignore: deprecated_member_use
      final token = (await messaging.getToken())?.trim();
      return (token == null || token.isEmpty) ? null : token;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh {
    final messaging = _instance;
    if (messaging == null) return const Stream<String>.empty();
    try {
      // ignore: deprecated_member_use
      return messaging.onTokenRefresh
          .where((token) => token.trim().isNotEmpty)
          .handleError((Object _) {});
    } catch (_) {
      return const Stream<String>.empty();
    }
  }

  @override
  Future<void> deleteToken() async {
    final messaging = _instance;
    if (messaging == null) return;
    try {
      // ignore: deprecated_member_use
      await messaging.deleteToken();
    } catch (_) {
      // Sin Play Services / APNs no hay token que borrar.
    }
  }

  static FcmAuthorizationStatus _mapStatus(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized => FcmAuthorizationStatus.authorized,
      AuthorizationStatus.provisional => FcmAuthorizationStatus.provisional,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently ||
      AuthorizationStatus.notDetermined => FcmAuthorizationStatus.denied,
    };
  }
}
