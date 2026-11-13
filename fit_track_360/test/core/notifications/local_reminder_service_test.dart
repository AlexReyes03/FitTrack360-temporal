// Spec P3 (docs/permisos.md, issue #131) -> pruebas:
// - P3-1 Permiso en Android 13+ con permission_handler: granted, denied y
//   permanentlyDenied se mapean sin perder el estado permanente.
// - P3-2 Autorización en iOS con el plugin; si se niega, iOS no vuelve a
//   preguntar y se trata como permanentlyDenied (se ofrecen ajustes).
// - P3-3 Aviso diario a la hora dada, inexacto y con un único id fijo; cancelar
//   usa el mismo id.
// - P3-4 isSupported es false en web y en plataformas sin soporte, sin lanzar.
// - P3-5 openSystemSettings abre los ajustes de la app.
// - P3-6 El siguiente disparo es hoy si la hora no ha pasado; si no, mañana.
import 'package:fit_track_360/core/notifications/local_reminder_service.dart';
import 'package:fit_track_360/core/notifications/reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeNotificationsPlugin implements NotificationsPlugin {
  PermissionStatus androidStatus = PermissionStatus.granted;
  bool iosGranted = true;
  bool throwOnInitialize = false;
  int initializeCalls = 0;
  int openSettingsCalls = 0;
  final scheduled = <({int id, int hour, int minute})>[];
  final cancelled = <int>[];

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (throwOnInitialize) throw Exception('sin plugin');
  }

  @override
  Future<PermissionStatus> requestAndroidPermission() async => androidStatus;

  @override
  Future<bool> requestIosAuthorization() async => iosGranted;

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    scheduled.add((id: id, hour: hour, minute: minute));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }
}

LocalReminderService service(
  FakeNotificationsPlugin plugin, {
  bool isWeb = false,
  TargetPlatform platform = TargetPlatform.android,
}) => LocalReminderService(plugin: plugin, isWeb: isWeb, platform: platform);

void main() {
  late FakeNotificationsPlugin plugin;

  setUp(() => plugin = FakeNotificationsPlugin());

  group('P3-1 permiso en Android', () {
    final casos = {
      PermissionStatus.granted: ReminderPermission.granted,
      PermissionStatus.limited: ReminderPermission.granted,
      PermissionStatus.provisional: ReminderPermission.granted,
      PermissionStatus.denied: ReminderPermission.denied,
      PermissionStatus.permanentlyDenied: ReminderPermission.permanentlyDenied,
      PermissionStatus.restricted: ReminderPermission.permanentlyDenied,
    };
    casos.forEach((estado, esperado) {
      test('$estado se mapea a $esperado', () async {
        plugin.androidStatus = estado;
        expect(await service(plugin).requestPermission(), esperado);
      });
    });
  });

  group('P3-2 autorización en iOS', () {
    test('concedida se mapea a granted', () async {
      plugin.iosGranted = true;
      final s = service(plugin, platform: TargetPlatform.iOS);
      expect(await s.requestPermission(), ReminderPermission.granted);
    });

    test('negada se mapea a permanentlyDenied', () async {
      plugin.iosGranted = false;
      final s = service(plugin, platform: TargetPlatform.iOS);
      expect(await s.requestPermission(), ReminderPermission.permanentlyDenied);
    });
  });

  group('P3-3 programación diaria con id fijo', () {
    test('programa a la hora dada y cancela con el mismo id', () async {
      final s = service(plugin);
      await s.scheduleDaily(hour: 7, minute: 30);
      await s.cancel();

      expect(plugin.scheduled.single.hour, 7);
      expect(plugin.scheduled.single.minute, 30);
      expect(plugin.scheduled.single.id, LocalReminderService.reminderId);
      expect(plugin.cancelled, [LocalReminderService.reminderId]);
    });

    test('reprogramar reutiliza el mismo id', () async {
      final s = service(plugin);
      await s.scheduleDaily(hour: 7, minute: 0);
      await s.scheduleDaily(hour: 21, minute: 15);
      expect(plugin.scheduled.map((e) => e.id).toSet(), {
        LocalReminderService.reminderId,
      });
    });

    test('inicializa el plugin una sola vez', () async {
      final s = service(plugin);
      await s.scheduleDaily(hour: 8, minute: 0);
      await s.cancel();
      expect(plugin.initializeCalls, 1);
    });

    test('rechaza horas fuera de rango', () async {
      final s = service(plugin);
      await expectLater(
        s.scheduleDaily(hour: 24, minute: 0),
        throwsArgumentError,
      );
      await expectLater(
        s.scheduleDaily(hour: 8, minute: 60),
        throwsArgumentError,
      );
      expect(plugin.scheduled, isEmpty);
    });
  });

  group('P3-4 isSupported', () {
    test('true en Android e iOS', () async {
      expect(await service(plugin).isSupported(), isTrue);
      expect(
        await service(plugin, platform: TargetPlatform.iOS).isSupported(),
        isTrue,
      );
    });

    test('false en web sin tocar el plugin', () async {
      expect(await service(plugin, isWeb: true).isSupported(), isFalse);
      expect(plugin.initializeCalls, 0);
    });

    test('false en escritorio', () async {
      final s = service(plugin, platform: TargetPlatform.windows);
      expect(await s.isSupported(), isFalse);
    });

    test('false y sin lanzar si el plugin falla al iniciar', () async {
      plugin.throwOnInitialize = true;
      expect(await service(plugin).isSupported(), isFalse);
    });

    test('sin soporte, programar y cancelar no hacen nada', () async {
      final s = service(plugin, isWeb: true);
      await s.scheduleDaily(hour: 7, minute: 0);
      await s.cancel();
      expect(plugin.scheduled, isEmpty);
      expect(plugin.cancelled, isEmpty);
      expect(await s.requestPermission(), ReminderPermission.denied);
    });
  });

  test('P3-5 openSystemSettings abre los ajustes de la app', () async {
    await service(plugin).openSystemSettings();
    expect(plugin.openSettingsCalls, 1);
  });

  group('P3-6 siguiente disparo', () {
    final now = tz.TZDateTime.utc(2026, 11, 10, 12, 0);

    test('hoy si la hora no ha pasado', () {
      expect(
        nextDailyInstance(now, 18, 30),
        tz.TZDateTime.utc(2026, 11, 10, 18, 30),
      );
    });

    test('mañana si la hora ya pasó o es la actual', () {
      expect(
        nextDailyInstance(now, 7, 0),
        tz.TZDateTime.utc(2026, 11, 11, 7, 0),
      );
      expect(
        nextDailyInstance(now, 12, 0),
        tz.TZDateTime.utc(2026, 11, 11, 12, 0),
      );
    });
  });
}
