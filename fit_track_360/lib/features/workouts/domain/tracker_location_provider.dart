import 'package:geolocator/geolocator.dart';

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

/// Implementacion real con `geolocator` (accuracy low / coarse).
class GeolocatorTrackerLocationProvider implements TrackerLocationProvider {
  @override
  Future<TrackerGpsFix?> getApproximateLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return TrackerGpsFix(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}
