import 'dart:io';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/progress/domain/progress_photo_errors.dart';
import 'package:fit_track_360/features/progress/presentation/progress_view_model.dart';
import 'package:fit_track_360/features/progress/presentation/state/progress_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_progress_photos_repository.dart';

const _draft = ProgressCheckInDraft(
  weightKg: 74.2,
  notesText: '',
  hasPhotoSelected: false,
);

File _photo(String name) => File('${Directory.systemTemp.path}/$name');

void main() {
  test('métricas quedan empty por bloqueo #122', () {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());

    expect(vm.chartStatus, ProgressSectionStatus.empty);
    expect(vm.historyStatus, ProgressSectionStatus.empty);
    expect(vm.chartAsync, isA<AsyncEmpty>());
    expect(vm.historyAsync, isA<AsyncEmpty>());
    expect(vm.chartData.points, isEmpty);
    expect(vm.historyEntries, isEmpty);

    vm.setRange(ProgressRange.y1);
    expect(vm.range, ProgressRange.y1);
    expect(vm.chartStatus, ProgressSectionStatus.empty);

    vm.dispose();
  });

  test('reintentar recarga métricas aunque el rango no cambie', () {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    var notifications = 0;
    vm.addListener(() => notifications++);

    vm.setRange(vm.range);
    expect(notifications, 0, reason: 'mismo rango sin forzar no recarga');

    vm.reloadMetrics();
    expect(notifications, greaterThan(0));
    expect(vm.chartStatus, ProgressSectionStatus.empty);
    expect(vm.historyStatus, ProgressSectionStatus.empty);

    vm.dispose();
  });

  test('check-in sin foto dice que el peso aún no se guarda', () async {
    final repo = FakeProgressPhotosRepository();
    final vm = ProgressViewModel(photos: repo);

    await vm.submitCheckIn(_draft);

    expect(vm.checkInFeedback, contains('aún no se guarda'));
    expect(vm.checkInFeedback, contains('#122'));
    expect(vm.checkInFeedback, isNot(contains('listo para guardar')));
    expect(repo.uploaded, isEmpty);
    expect(vm.sessionPhotos, isEmpty);

    vm.dispose();
  });

  test('check-in con foto sube y arma comparación de sesión', () async {
    final repo = FakeProgressPhotosRepository();
    final vm = ProgressViewModel(photos: repo);

    vm.selectPendingPhoto(_photo('a.jpg'), label: 'selfie.jpg');
    await vm.submitCheckIn(_draft);

    expect(repo.uploaded, hasLength(1));
    expect(vm.sessionPhotos, hasLength(1));
    expect(vm.comparisonStatus, ProgressSectionStatus.data);
    expect(vm.checkInFeedback, contains('Foto guardada'));
    expect(vm.checkInFeedback, contains('aún no se guarda'));
    expect(vm.selectedCheckInPhotoLabel, isNull);

    vm.selectPendingPhoto(_photo('b.jpg'), label: 'selfie2.jpg');
    await vm.submitCheckIn(_draft);

    expect(vm.sessionPhotos, hasLength(2));
    expect(vm.sessionComparison!.initial!.id, 'ph-1');
    expect(vm.sessionComparison!.current!.id, 'ph-2');

    vm.dispose();
  });

  test('sesión expirada al subir marca sessionExpired', () async {
    final vm = ProgressViewModel(
      photos: FakeProgressPhotosRepository(
        uploadError: const SessionExpiredException(),
      ),
    );
    vm.selectPendingPhoto(_photo('a.jpg'), label: 'a.jpg');

    await vm.submitCheckIn(_draft);

    expect(vm.sessionExpired, isTrue);
    expect(vm.isSubmittingCheckIn, isFalse);
    vm.dispose();
  });

  test('error de validación de foto se muestra sin tumbar el VM', () async {
    final vm = ProgressViewModel(
      photos: FakeProgressPhotosRepository(
        uploadError: const ProgressPhotoValidationException('Formato raro'),
      ),
    );
    vm.selectPendingPhoto(_photo('a.jpg'), label: 'a.jpg');

    await vm.submitCheckIn(_draft);

    expect(vm.checkInFeedback, 'Formato raro');
    vm.dispose();
  });

  test('reintentar comparación recalcula los slots de la sesión', () async {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    await vm.uploadProgressPhoto(_photo('a.jpg'));
    vm.comparisonStatus = ProgressSectionStatus.error;

    vm.refreshComparison();

    expect(vm.comparisonStatus, ProgressSectionStatus.data);
    expect(vm.initialPhotoSlot, isNotNull);
    vm.dispose();
  });

  test('delete 404 de foto ajena no tumba el VM', () async {
    final vm = ProgressViewModel(
      photos: FakeProgressPhotosRepository(
        deleteError: const ProgressPhotoUnavailableException(),
      ),
    );

    await expectLater(
      vm.deletePhoto('ajena'),
      throwsA(isA<ProgressPhotoUnavailableException>()),
    );

    vm.dispose();
  });
}
