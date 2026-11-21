import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/logout_service.dart';
import 'package:fit_track_360/features/settings/domain/export_sharer.dart';
import 'package:fit_track_360/features/settings/presentation/profile_view_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

ProfileViewModel _vm(
  FakeProfileRepository repository,
  FakeExportSharer sharer, {
  DateTime Function()? clock,
}) => ProfileViewModel(
  profileRepository: repository,
  reminderService: FakeReminderService(),
  biometricService: FakeBiometricService(),
  logoutService: LogoutService(
    storage: FakeSessionStorage(),
    revoke: ({required idToken}) async {},
  ),
  exportSharer: sharer,
  clock: clock,
);

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
      expect(vm.sessionExpired, isFalse);
    });

    test('sesión expirada no se degrada como exportación ausente', () async {
      final repo = FakeProfileRepository()
        ..exportError = const SessionExpiredException();
      final vm = _vm(repo, FakeExportSharer());

      expect(await vm.exportData(), isNull);
      expect(vm.sessionExpired, isTrue);
      expect(vm.message, sessionExpiredMessage);
    });
  });

  group('eliminación de cuenta', () {
    test('confirma solo cuando el repositorio responde', () async {
      final repo = FakeProfileRepository();
      final vm = _vm(repo, FakeExportSharer());

      expect(await vm.deleteAccount(), isTrue);
      expect(repo.deleteCalls, 1);
      expect(vm.message, isNull);
      expect(vm.deleting, isFalse);
    });

    test('un error de red no confirma la eliminación', () async {
      final repo = FakeProfileRepository()..deleteError = Exception('500');
      final vm = _vm(repo, FakeExportSharer());

      expect(await vm.deleteAccount(), isFalse);
      expect(vm.message, deleteAccountFailedMessage);
      expect(vm.sessionExpired, isFalse);
    });

    test(
      'la sesión expirada se informa para volver a iniciar sesión',
      () async {
        final repo = FakeProfileRepository()
          ..deleteError = const SessionExpiredException();
        final vm = _vm(repo, FakeExportSharer());

        expect(await vm.deleteAccount(), isFalse);
        expect(vm.message, sessionExpiredMessage);
        expect(vm.sessionExpired, isTrue);
      },
    );

    test('ignora una segunda solicitud mientras la primera sigue', () async {
      final gate = Completer<void>();
      final repo = FakeProfileRepository()..deleteGate = gate.future;
      final vm = _vm(repo, FakeExportSharer());

      final first = vm.deleteAccount();
      expect(vm.deleting, isTrue);
      expect(await vm.deleteAccount(), isFalse);
      expect(repo.deleteCalls, 1);

      gate.complete();
      expect(await first, isTrue);
      expect(vm.deleting, isFalse);
    });
  });
}
