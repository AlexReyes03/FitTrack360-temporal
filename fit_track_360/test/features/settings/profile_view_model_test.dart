import 'dart:async';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/notifications/reminder_service.dart';
import 'package:fit_track_360/features/auth/data/logout_service.dart';
import 'package:fit_track_360/features/settings/domain/export_sharer.dart';
import 'package:fit_track_360/features/settings/domain/profile_repository.dart';
import 'package:fit_track_360/features/settings/domain/profile_validation.dart';
import 'package:fit_track_360/features/settings/domain/user_profile.dart';
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

  group('sesión expirada (UX-11)', () {
    test(
      'load marca sessionExpired si el API ya no acepta la sesión',
      () async {
        final repo = FakeProfileRepository()
          ..fetchError = const SessionExpiredException();
        final vm = _vm(repo, FakeExportSharer());

        await vm.load();

        expect(vm.sessionExpired, isTrue);
        expect(vm.state, isA<AsyncError<UserProfile>>());
      },
    );

    test(
      'un error genérico en load no se confunde con sesión expirada',
      () async {
        final repo = FakeProfileRepository()..fetchError = Exception('500');
        final vm = _vm(repo, FakeExportSharer());

        await vm.load();

        expect(vm.sessionExpired, isFalse);
      },
    );

    test(
      'exportar con sesión expirada no la reporta como no disponible',
      () async {
        final repo = FakeProfileRepository()
          ..exportError = const SessionExpiredException();
        final sharer = FakeExportSharer();
        final vm = _vm(repo, sharer);
        await vm.load();

        expect(await vm.exportData(), isNull);

        expect(vm.sessionExpired, isTrue);
        expect(vm.message, isNot(exportUnavailableMessage));
        expect(sharer.shared, isEmpty);
        expect(vm.exporting, isFalse);
      },
    );

    test('guardar con sesión expirada marca sessionExpired', () async {
      final repo = FakeProfileRepository();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();
      repo.updateError = const SessionExpiredException();

      final saved = await vm.save(_validForm());

      expect(saved, isFalse);
      expect(vm.sessionExpired, isTrue);
      expect(vm.formFeedback, isNull);
    });
  });

  group('regla de guardado (UX-11)', () {
    test(
      'save envía nombre, metas y descanso sin tocar las unidades',
      () async {
        final repo = FakeProfileRepository(
          profile: UserProfile(
            id: sampleProfile.id,
            email: sampleProfile.email,
            username: sampleProfile.username,
            displayName: sampleProfile.displayName,
            goals: sampleGoals,
            preferences: samplePreferences.copyWith(weightUnit: WeightUnit.lb),
          ),
        );
        final vm = _vm(repo, FakeExportSharer());
        await vm.load();

        expect(await vm.save(_validForm(rest: '120')), isTrue);

        final prefs = repo.updates.single.preferences!;
        expect(prefs.restSeconds, 120);
        expect(prefs.weightUnit, WeightUnit.lb);
        expect(vm.formFeedback?.text, formSavedMessage);
        expect(vm.formFeedback?.kind, ProfileFeedbackKind.success);
        expect(vm.preferencesFeedback, isNull);
      },
    );

    test('un fallo al guardar el formulario se reporta como error', () async {
      final repo = FakeProfileRepository();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();
      repo.updateError = Exception('500');

      expect(await vm.save(_validForm()), isFalse);

      expect(vm.formFeedback?.text, saveFailedMessage);
      expect(vm.formFeedback?.kind, ProfileFeedbackKind.error);
    });

    test('cambiar la unidad de peso se guarda al instante', () async {
      final repo = FakeProfileRepository();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();

      await vm.setWeightUnit(WeightUnit.lb);

      expect(repo.updates.single.preferences!.weightUnit, WeightUnit.lb);
      expect(repo.updates.single.displayName, isNull);
      expect(vm.profile!.preferences.weightUnit, WeightUnit.lb);
      expect(vm.preferencesFeedback?.text, preferenceSavedMessage);
      expect(vm.preferencesFeedback?.kind, ProfileFeedbackKind.success);
    });

    test('cambiar la unidad de distancia se guarda al instante', () async {
      final repo = FakeProfileRepository();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();

      await vm.setDistanceUnit(DistanceUnit.mi);

      expect(repo.updates.single.preferences!.distanceUnit, DistanceUnit.mi);
    });

    test('elegir la unidad que ya está activa no llama al API', () async {
      final repo = FakeProfileRepository();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();

      await vm.setWeightUnit(WeightUnit.kg);

      expect(repo.updates, isEmpty);
    });

    test('un interruptor nunca pone el formulario en «guardando»', () async {
      final repo = FakeProfileRepository()..updateGate = Completer<void>();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();
      final formSavingStates = <bool>[];
      final prefsStates = <bool>[];
      vm.addListener(() {
        formSavingStates.add(vm.savingForm);
        prefsStates.add(vm.updatingPreferences);
      });

      final pending = vm.setReminder(true);
      await pumpEventQueue();
      expect(vm.updatingPreferences, isTrue);
      repo.updateGate!.complete();
      await pending;

      expect(formSavingStates, everyElement(isFalse));
      expect(prefsStates, contains(isTrue));
      expect(vm.updatingPreferences, isFalse);
      expect(vm.preferencesFeedback?.kind, ProfileFeedbackKind.success);
    });

    test(
      'un fallo de preferencia se reporta como error en su sección',
      () async {
        final repo = FakeProfileRepository();
        final vm = _vm(repo, FakeExportSharer());
        await vm.load();
        repo.updateError = Exception('500');

        await vm.setDistanceUnit(DistanceUnit.mi);

        expect(vm.preferencesFeedback?.text, preferenceFailedMessage);
        expect(vm.preferencesFeedback?.kind, ProfileFeedbackKind.error);
        expect(vm.formFeedback, isNull);
        expect(vm.profile!.preferences.distanceUnit, DistanceUnit.km);
      },
    );

    test('permiso denegado se muestra como aviso, no como error', () async {
      final vm = _vm(
        FakeProfileRepository(),
        FakeExportSharer(),
        reminders: FakeReminderService(permission: ReminderPermission.denied),
      );
      await vm.load();

      await vm.setReminder(true);

      expect(vm.preferencesFeedback?.kind, ProfileFeedbackKind.warning);
    });
  });

  group('estado de exportación (UX-11)', () {
    test(
      'marca exporting y no permite una segunda exportación a la vez',
      () async {
        final repo = FakeProfileRepository()
          ..exportJson = '{"a":1}'
          ..exportGate = Completer<void>();
        final sharer = FakeExportSharer();
        final vm = _vm(repo, sharer);
        await vm.load();

        final first = vm.exportData();
        await pumpEventQueue();
        expect(vm.exporting, isTrue);
        final second = await vm.exportData();
        repo.exportGate!.complete();
        await first;

        expect(second, isNull);
        expect(repo.exportCalls, 1);
        expect(sharer.shared, hasLength(1));
        expect(vm.exporting, isFalse);
      },
    );

    test('exportación no disponible se reporta como error', () async {
      final vm = _vm(FakeProfileRepository(), FakeExportSharer());
      await vm.load();

      await vm.exportData();

      expect(vm.dataFeedback?.text, exportUnavailableMessage);
      expect(vm.dataFeedback?.kind, ProfileFeedbackKind.error);
    });
  });

  group('eliminar cuenta (UX-11)', () {
    test(
      'elimina en el API, cancela el recordatorio y limpia la sesión',
      () async {
        final repo = FakeProfileRepository();
        final storage = FakeSessionStorage();
        final reminders = FakeReminderService();
        final vm = _vm(
          repo,
          FakeExportSharer(),
          storage: storage,
          reminders: reminders,
        );
        await vm.load();

        expect(await vm.deleteAccount(), isTrue);

        expect(repo.deleteCalls, 1);
        expect(reminders.cancelled, 1);
        expect(storage.accessToken, isNull);
        expect(vm.deletingAccount, isFalse);
      },
    );

    test('si el API falla conserva la sesión y muestra el error', () async {
      final repo = FakeProfileRepository()
        ..deleteError = const AccountDeletionException();
      final storage = FakeSessionStorage();
      final vm = _vm(repo, FakeExportSharer(), storage: storage);
      await vm.load();

      expect(await vm.deleteAccount(), isFalse);

      expect(storage.accessToken, 'access');
      expect(vm.dataFeedback?.text, accountDeletionFailedMessage);
      expect(vm.dataFeedback?.kind, ProfileFeedbackKind.error);
      expect(vm.deletingAccount, isFalse);
    });

    test('con sesión expirada marca sessionExpired', () async {
      final repo = FakeProfileRepository()
        ..deleteError = const SessionExpiredException();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();

      expect(await vm.deleteAccount(), isFalse);

      expect(vm.sessionExpired, isTrue);
    });

    test('no envía dos eliminaciones a la vez', () async {
      final repo = FakeProfileRepository()..deleteGate = Completer<void>();
      final vm = _vm(repo, FakeExportSharer());
      await vm.load();

      final first = vm.deleteAccount();
      await pumpEventQueue();
      expect(vm.deletingAccount, isTrue);
      expect(await vm.deleteAccount(), isFalse);
      repo.deleteGate!.complete();
      await first;

      expect(repo.deleteCalls, 1);
    });
  });
}

ProfileForm _validForm({String rest = '90'}) => ProfileForm(
  displayName: 'Ana',
  dailyCalorieGoal: '2000',
  proteinGoalG: '150',
  carbsGoalG: '250',
  fatGoalG: '65',
  restSeconds: rest,
);
