import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// Adaptador mínimo sobre los plugins de notificaciones y permisos, para
/// probar [LocalReminderService] con dobles.
abstract class NotificationsPlugin {
  Future<void> initialize();

  /// `POST_NOTIFICATIONS` con `permission_handler` (Android 13+; en versiones
  /// anteriores el sistema la concede al instalar).
  Future<ph.PermissionStatus> requestAndroidPermission();

  /// Autorización de `UNUserNotificationCenter` (iOS).
  Future<bool> requestIosAuthorization();

  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);

  Future<bool> openSettings();
}

/// Siguiente [hour]:[minute] posterior a [now], en la zona de [now].
tz.TZDateTime nextDailyInstance(tz.TZDateTime now, int hour, int minute) {
  var next = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!next.isAfter(now)) {
    next = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return next;
}

/// Recordatorio diario P3 con `flutter_local_notifications`.
///
/// La programación es inexacta (`inexactAllowWhileIdle`): no requiere
/// `SCHEDULE_EXACT_ALARM`.
class LocalReminderService implements ReminderService {
  LocalReminderService({
    NotificationsPlugin? plugin,
    this.isWeb = kIsWeb,
    TargetPlatform? platform,
  }) : _plugin = plugin ?? FlutterNotificationsPlugin(),
       _platform = platform ?? defaultTargetPlatform;

  /// Único id del recordatorio: reprogramar reemplaza el aviso anterior.
  static const int reminderId = 360;

  static const String title = 'Hora de moverte';
  static const String body =
      'Registra tu entrenamiento o tu comida para mantener la constancia.';

  final NotificationsPlugin _plugin;

  /// `true` en web, donde no hay notificaciones locales programadas.
  final bool isWeb;
  final TargetPlatform _platform;
  Future<bool>? _ready;

  bool get _platformSupported =>
      !isWeb &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);

  /// Inicializa una sola vez; `false` si el plugin no está disponible.
  Future<bool> _ensureReady() {
    if (!_platformSupported) return Future.value(false);
    return _ready ??= _plugin
        .initialize()
        .then((_) => true)
        .catchError((Object _) => false);
  }

  @override
  Future<bool> isSupported() => _ensureReady();

  @override
  Future<ReminderPermission> requestPermission() async {
    if (!await _ensureReady()) return ReminderPermission.denied;
    if (_platform == TargetPlatform.iOS) {
      // iOS no vuelve a mostrar el diálogo tras una negativa: solo queda
      // cambiarlo en Ajustes.
      return await _plugin.requestIosAuthorization()
          ? ReminderPermission.granted
          : ReminderPermission.permanentlyDenied;
    }
    return switch (await _plugin.requestAndroidPermission()) {
      ph.PermissionStatus.granted ||
      ph.PermissionStatus.limited ||
      ph.PermissionStatus.provisional => ReminderPermission.granted,
      ph.PermissionStatus.permanentlyDenied ||
      ph.PermissionStatus.restricted => ReminderPermission.permanentlyDenied,
      ph.PermissionStatus.denied => ReminderPermission.denied,
    };
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    RangeError.checkValueInInterval(hour, 0, 23, 'hour');
    RangeError.checkValueInInterval(minute, 0, 59, 'minute');
    if (!await _ensureReady()) return;
    await _plugin.scheduleDaily(
      id: reminderId,
      hour: hour,
      minute: minute,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel() async {
    if (!await _ensureReady()) return;
    await _plugin.cancel(reminderId);
  }

  @override
  Future<void> openSystemSettings() async {
    await _plugin.openSettings();
  }
}

/// Implementación real del adaptador.
class FlutterNotificationsPlugin implements NotificationsPlugin {
  FlutterNotificationsPlugin([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorio_diario',
      'Recordatorio diario',
      channelDescription: 'Aviso para entrenar o registrar tus comidas.',
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // El permiso se pide solo al activar el recordatorio.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  @override
  Future<ph.PermissionStatus> requestAndroidPermission() =>
      ph.Permission.notification.request();

  @override
  Future<bool> requestIosAuthorization() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          sound: true,
          badge: true,
        ) ??
        false;
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: nextDailyInstance(
        tz.TZDateTime.now(tz.local),
        hour,
        minute,
      ),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<bool> openSettings() => ph.openAppSettings();
}
