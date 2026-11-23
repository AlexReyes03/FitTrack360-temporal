import 'package:fit_track_360/core/notifications/reminder_service.dart';
import 'package:fit_track_360/features/auth/data/logout_service.dart';
import 'package:fit_track_360/features/settings/domain/export_sharer.dart';
import 'package:fit_track_360/features/settings/presentation/profile_view_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

ProfileViewModel _vm(
  FakeProfileRepository repository,
  FakeExportSharer sharer, {
  FakePushDeviceLifecycle? push,
  FakeSessionStorage? storage,
  FakeReminderService? reminders,
  DateTime Function()? clock,
}) {
  final session = storage ?? FakeSessionStorage();
  return ProfileViewModel(
    profileRepository: repository,
    reminderService: reminders ?? FakeReminderService(),
    biometricService: FakeBiometricService(),
    logoutService: LogoutService(
      storage: session,
      revoke: ({required idToken}) async {},
      pushDeviceService: push,
    ),
    exportSharer: sharer,
    pushDeviceService: push,
    clock: clock,
  );
}

void main() {
  group('resumen de entrenamientos (W12-20)', () {
    test('load toma workoutCount del perfil', () async {
      final vm = _vm(FakeProfileRepository(workouts: 7), FakeExportSharer());
      await vm.load();
      expect(vm.workoutCount, 7);
    });

    test('si el perfil falla, el resumen queda en null', () async {
      final repo = FakeProfileRepository()..fetchError = Exception('500');
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();
      expect(vm.workoutCount, isNull);
    });
  });

  group('exportación compartible (W12-20)', () {
    test('exportFileName usa la fecha local con ceros a la izquierda', () {
      expect(
        exportFileName(DateTime(2026, 3, 5, 23, 59)),
        'fittrack360-export-2026-03-05.json',
      );
      expect(
        exportFileName(DateTime(2026, 11, 18)),
        'fittrack360-export-2026-11-18.json',
      );
    });

    test('comparte el JSON con nombre fechado y no pide diálogo', () async {
      final repo = FakeProfileRepository()..exportJson = '{"a":1}';
      final sharer = FakeExportSharer();
      final vm = _vm(repo, sharer, clock: () => DateTime(2026, 11, 18, 10));
      const origin = Rect.fromLTWH(10, 20, 100, 40);

      final fallback = await vm.exportData(origin: origin);

      expect(fallback, isNull);
      expect(sharer.shared.single.json, '{"a":1}');
      expect(
        sharer.shared.single.fileName,
        'fittrack360-export-2026-11-18.json',
      );
      expect(sharer.shared.single.origin, origin);
      expect(vm.message, isNull);
    });

    test('si el plugin falla devuelve el JSON para el diálogo', () async {
      final repo = FakeProfileRepository()..exportJson = '{"a":1}';
      final vm = _vm(repo, FakeExportSharer(error: StateError('sin plugin')));

      final fallback = await vm.exportData();

      expect(fallback, '{"a":1}');
      expect(vm.message, exportShareFailedMessage);
    });

    test('si la exportación no existe no intenta compartir', () async {
      final sharer = FakeExportSharer();
      final vm = _vm(FakeProfileRepository(), sharer);

      expect(await vm.exportData(), isNull);
      expect(sharer.shared, isEmpty);
      expect(vm.message, exportUnavailableMessage);
    });
  });

  group('token FCM (W13-7)', () {
    test('load sincroniza el token si P3 ya estaba activo', () async {
      final push = FakePushDeviceLifecycle();
      final vm = _vm(
        FakeProfileRepository(profile: sampleProfileWithNotifications(true)),
        FakeExportSharer(),
        push: push,
      );

      await vm.load();
      await pumpEventQueue();

      expect(push.syncCalls, hasLength(1));
      expect(push.syncCalls.single.notificationsEnabled, isTrue);
      expect(push.syncCalls.single.requestPermissionIfNeeded, isFalse);
    });

    test('load no sincroniza si P3 está apagado', () async {
      final push = FakePushDeviceLifecycle();
      final vm = _vm(FakeProfileRepository(), FakeExportSharer(), push: push);

      await vm.load();
      await pumpEventQueue();

      expect(push.syncCalls, isEmpty);
    });

    test('un fallo del ciclo FCM no rompe load', () async {
      final push = FakePushDeviceLifecycle()
        ..syncError = Exception('sin Play Services');
      final vm = _vm(
        FakeProfileRepository(profile: sampleProfileWithNotifications(true)),
        FakeExportSharer(),
        push: push,
      );

      await vm.load();
      await pumpEventQueue();

      expect(vm.profile, isNotNull);
    });

    test('setReminder(true) registra el token tras conceder permiso', () async {
      final push = FakePushDeviceLifecycle();
      final reminders = FakeReminderService(
        permission: ReminderPermission.granted,
      );
      final repo = FakeProfileRepository();
      final vm = _vm(
        repo,
        FakeExportSharer(),
        push: push,
        reminders: reminders,
      );

      await vm.load();
      await vm.setReminder(true);

      expect(reminders.scheduled, 1);
      expect(repo.updates.single.preferences!.notificationsEnabled, isTrue);
      expect(push.syncCalls, hasLength(1));
      expect(push.syncCalls.single.notificationsEnabled, isTrue);
      expect(push.syncCalls.single.requestPermissionIfNeeded, isTrue);
    });

    test('setReminder(true) denegado no registra el token', () async {
      final push = FakePushDeviceLifecycle();
      final reminders = FakeReminderService(
        permission: ReminderPermission.denied,
      );
      final vm = _vm(
        FakeProfileRepository(),
        FakeExportSharer(),
        push: push,
        reminders: reminders,
      );

      await vm.load();
      await vm.setReminder(true);

      expect(vm.message, reminderDeniedMessage);
      expect(push.syncCalls, isEmpty);
    });

    test('setReminder(false) revoca el token', () async {
      final push = FakePushDeviceLifecycle();
      final repo = FakeProfileRepository(
        profile: sampleProfileWithNotifications(true),
      );
      final vm = _vm(repo, FakeExportSharer(), push: push);

      await vm.load();
      push.syncCalls.clear();
      await vm.setReminder(false);

      expect(repo.updates.single.preferences!.notificationsEnabled, isFalse);
      expect(push.revokeCalls, 1);
    });

    test('logout revoca el token antes de limpiar la sesión', () async {
      final push = FakePushDeviceLifecycle();
      final storage = FakeSessionStorage();
      final vm = _vm(
        FakeProfileRepository(),
        FakeExportSharer(),
        push: push,
        storage: storage,
      );

      await vm.logout();

      expect(push.revokeCalls, 1);
      expect(storage.accessToken, isNull);
    });

    test('un fallo de revocación no bloquea el logout', () async {
      final push = FakePushDeviceLifecycle()
        ..revokeError = Exception('sin red');
      final storage = FakeSessionStorage();
      final vm = _vm(
        FakeProfileRepository(),
        FakeExportSharer(),
        push: push,
        storage: storage,
      );

      await vm.logout();

      expect(push.revokeCalls, 1);
      expect(storage.accessToken, isNull);
    });
  });
}
