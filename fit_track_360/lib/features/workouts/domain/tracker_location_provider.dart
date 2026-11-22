/// Resultado aproximado de GPS para P2 (sin exigir fine location).
class TrackerGpsFix {
  const TrackerGpsFix({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Texto corto para guardar en `location` del API.
  String get label =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}

/// Abstraccion de ubicacion para poder mockear degradacion P2 en pruebas.
abstract class TrackerLocationProvider {
  Future<TrackerGpsFix?> getApproximateLocation();
}
