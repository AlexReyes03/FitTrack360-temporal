import 'dashboard_today.dart';

/// Contrato del resumen diario del Home.
abstract class DashboardRepository {
  /// Día local del dispositivo (`date` + `utcOffsetMinutes`).
  Future<DashboardToday> today({
    required String date,
    required int utcOffsetMinutes,
  });
}
