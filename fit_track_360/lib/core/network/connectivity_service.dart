import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Expone si el dispositivo tiene alguna red disponible (F7).
///
/// Envuelve `connectivity_plus` para que la UI no dependa del paquete y
/// las pruebas puedan sustituirlo con un fake (`implements`).
///
/// Nota: `connectivity_plus` informa la interfaz de red (wifi, datos, etc.),
/// no garantiza salida real a internet. El reintento de cada pantalla es
/// quien confirma contra el API.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Emite `true` cuando hay red y `false` cuando no, sin repetir valores.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(isOnlineFrom).distinct();

  /// Consulta el estado actual. Si la plataforma falla, asume en linea para
  /// no mostrar un aviso falso.
  Future<bool> isOnline() async {
    try {
      return isOnlineFrom(await _connectivity.checkConnectivity());
    } catch (_) {
      return true;
    }
  }

  /// Hay red si algun resultado es distinto de [ConnectivityResult.none].
  static bool isOnlineFrom(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
