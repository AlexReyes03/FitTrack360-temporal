import 'package:fit_track_360/features/home/data/steps_baseline_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guarda y lee la línea base del día', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureStepsBaselineStore();
    final baseline = StepsBaseline(
      day: '2026-11-21',
      steps: 5000,
      capturedAt: DateTime(2026, 11, 21, 8, 30),
    );

    await store.writeBaseline(baseline);
    final read = await store.readBaseline();

    expect(read!.day, '2026-11-21');
    expect(read.steps, 5000);
    expect(read.capturedAt, DateTime(2026, 11, 21, 8, 30));
  });

  test('un valor corrupto se trata como sin línea base', () async {
    FlutterSecureStorage.setMockInitialValues({
      'steps_daily_baseline': '{no es json',
    });
    expect(await SecureStepsBaselineStore().readBaseline(), isNull);
  });

  test('recuerda si iOS ya autorizó Motion', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureStepsBaselineStore();
    expect(await store.readMotionAuthorized(), isFalse);

    await store.writeMotionAuthorized(true);
    expect(await store.readMotionAuthorized(), isTrue);

    await store.writeMotionAuthorized(false);
    expect(await store.readMotionAuthorized(), isFalse);
  });
}
