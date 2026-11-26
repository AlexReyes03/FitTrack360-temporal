import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/settings/domain/privacy_notice.dart';
import 'package:fit_track_360/features/settings/domain/privacy_repository.dart';
import 'package:fit_track_360/features/settings/presentation/privacy_notice_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

PrivacyNoticeViewModel _vm(
  FakePrivacyRepository repository, {
  String userId = 'u1',
}) => PrivacyNoticeViewModel(repository, userId: userId);

void main() {
  group('aviso remoto', () {
    test('load expone versión, fecha y secciones', () async {
      final vm = _vm(FakePrivacyRepository());

      await vm.load();

      expect(vm.state, isA<AsyncData<PrivacyNotice>>());
      expect(vm.notice!.version, '2');
      expect(
        formatPrivacyNoticeDate(vm.notice!.date),
        '16 de noviembre de 2026',
      );
      expect(vm.notice!.sections, hasLength(2));
      expect(vm.notice!.includesMedicalLimit, isTrue);
      expect(vm.versionSupported, isTrue);
    });

    test('sin secciones queda en Empty y no permite aceptar', () async {
      final repo = FakePrivacyRepository(
        notice: PrivacyNotice(
          version: '2',
          date: DateTime(2026, 11, 16),
          sections: const [],
        ),
      );
      final vm = _vm(repo);

      await vm.load();

      expect(vm.state, isA<AsyncEmpty<PrivacyNotice>>());
      expect(vm.canAcceptConsent, isFalse);
    });

    test('con secciones parciales conserva Data y las muestra', () async {
      final repo = FakePrivacyRepository(
        notice: PrivacyNotice(
          version: '2',
          date: DateTime(2026, 11, 16),
          sections: const [
            PrivacyNoticeSection(title: 'Cuenta', text: 'Datos de la cuenta.'),
          ],
        ),
      );
      final vm = _vm(repo);

      await vm.load();

      expect(vm.state, isA<AsyncData<PrivacyNotice>>());
      expect(vm.notice!.sections.single.title, 'Cuenta');
      expect(vm.notice!.includesMedicalLimit, isFalse);
      expect(vm.canAcceptConsent, isTrue);
    });

    test('error de red queda en Error con mensaje', () async {
      final repo = FakePrivacyRepository()..noticeError = Exception('500');
      final vm = _vm(repo);

      await vm.load();

      expect(vm.state, isA<AsyncError<PrivacyNotice>>());
      expect(vm.error, privacyUnavailableMessage);
    });

    test('sesión expirada se informa con su propio mensaje', () async {
      final repo = FakePrivacyRepository()
        ..noticeError = const SessionExpiredException();
      final vm = _vm(repo);

      await vm.load();

      expect(vm.error, privacySessionExpiredMessage);
    });
  });

  group('consentimiento', () {
    test('envía la versión vigente y el usuario autenticado', () async {
      final repo = FakePrivacyRepository();
      final vm = _vm(repo, userId: 'u1');

      await vm.load();
      await vm.acceptConsent();

      expect(repo.consents.single, (userId: 'u1', version: '2'));
      expect(vm.receipt!.version, '2');
      expect(vm.error, isNull);
    });

    test('no acepta una versión distinta a la soportada', () async {
      final repo = FakePrivacyRepository(
        notice: PrivacyNotice(
          version: '3',
          date: DateTime(2026, 11, 16),
          sections: samplePrivacyNotice.sections,
        ),
      );
      final vm = _vm(repo);

      await vm.load();
      await vm.acceptConsent();

      expect(vm.versionSupported, isFalse);
      expect(vm.canAcceptConsent, isFalse);
      expect(repo.consents, isEmpty);
      expect(vm.receipt, isNull);
    });

    test('un rechazo no deja recibo', () async {
      final repo = FakePrivacyRepository()
        ..consentError = const ConsentRejectedException();
      final vm = _vm(repo);

      await vm.load();
      await vm.acceptConsent();

      expect(vm.receipt, isNull);
      expect(vm.error, privacyConsentFailedMessage);
    });

    test('sesión expirada durante el consentimiento', () async {
      final repo = FakePrivacyRepository()
        ..consentError = const SessionExpiredException();
      final vm = _vm(repo);

      await vm.load();
      await vm.acceptConsent();

      expect(vm.receipt, isNull);
      expect(vm.error, privacySessionExpiredMessage);
    });
  });
}
