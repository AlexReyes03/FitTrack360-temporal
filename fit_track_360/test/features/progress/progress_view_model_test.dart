import 'dart:io';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/progress/data/progress_photos_api.dart';
import 'package:fit_track_360/features/progress/presentation/progress_view_model.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_checkin_card.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_range_selector.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_section_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/progress_test_data.dart';

class _FakeStorage implements SessionStorage {
  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      'access';

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

ProgressViewModel _vm(MockClient client) {
  return ProgressViewModel(
    photosApi: ProgressPhotosApi(
      ApiClient(storage: _FakeStorage(), httpClient: client),
    ),
  );
}

void main() {
  test('métricas quedan empty por bloqueo #122', () {
    final vm = _vm(MockClient((_) async => http.Response('', 500)));

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

  test('check-in sin foto solo informa el bloqueo de métricas', () async {
    final vm = _vm(MockClient((_) async => http.Response('', 500)));

    await vm.submitCheckIn(
      const ProgressCheckInDraft(
        weightText: '74.2',
        notesText: '',
        hasPhotoSelected: false,
      ),
    );

    expect(vm.checkInFeedback, contains('#122'));
    expect(vm.sessionPhotos, isEmpty);

    vm.dispose();
  });

  test('check-in con foto sube a /photos y arma comparación de sesión', () async {
    var uploads = 0;
    final temp = File(
      '${Directory.systemTemp.path}/ft360-vm-photo-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await temp.writeAsBytes(transparentImage);

    final vm = _vm(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/photos');
        uploads++;
        return http.Response(
          '''
{
  "id": "ph-$uploads",
  "mimeType": "image/jpeg",
  "sizeBytes": 12,
  "width": 1,
  "height": 1,
  "mealId": null,
  "metricId": null,
  "createdAt": "2026-11-19T12:0$uploads:00.000Z"
}
''',
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    vm.selectPendingPhoto(temp, label: 'selfie.jpg');
    await vm.submitCheckIn(
      const ProgressCheckInDraft(
        weightText: '74.2',
        notesText: 'nota',
        hasPhotoSelected: true,
      ),
    );

    expect(uploads, 1);
    expect(vm.sessionPhotos, hasLength(1));
    expect(vm.comparisonStatus, ProgressSectionStatus.data);
    expect(vm.checkInFeedback, contains('Foto guardada'));
    expect(vm.checkInFeedback, contains('#122'));

    vm.selectPendingPhoto(temp, label: 'selfie2.jpg');
    await vm.submitCheckIn(
      const ProgressCheckInDraft(
        weightText: '74.0',
        notesText: '',
        hasPhotoSelected: true,
      ),
    );

    expect(vm.sessionPhotos, hasLength(2));
    expect(vm.sessionComparison, isNotNull);
    expect(vm.sessionComparison!.initial!.id, 'ph-1');
    expect(vm.sessionComparison!.current!.id, 'ph-2');

    await temp.delete();
    vm.dispose();
  });

  test('delete 404 de foto ajena no tumba el VM', () async {
    final vm = _vm(
      MockClient((request) async {
        expect(request.method, 'DELETE');
        return http.Response('{"message":"Foto no encontrada"}', 404);
      }),
    );

    expect(
      () => vm.deletePhoto('ajena'),
      throwsA(isA<ProgressPhotoUnavailableException>()),
    );

    vm.dispose();
  });
}
