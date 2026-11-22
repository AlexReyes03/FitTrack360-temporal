import 'package:fit_track_360/features/progress/presentation/progress_shell_page.dart';
import 'package:fit_track_360/features/progress/presentation/progress_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'support/fake_progress_photos_repository.dart';

void main() {
  Future<void> tapSelectPhoto(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Agregar foto de progreso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar foto de progreso'));
    await tester.pumpAndSettle();
  }

  testWidgets('si el selector falla avisa al usuario sin romper', (
    tester,
  ) async {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressShellPage(
          viewModel: vm,
          pickCheckInPhoto: () async =>
              throw PlatformException(code: 'photo_access_denied'),
        ),
      ),
    );
    await tapSelectPhoto(tester);

    expect(
      find.text('No se pudo abrir la galería. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(vm.selectedCheckInPhotoLabel, isNull);
  });

  testWidgets('la foto elegida queda adjunta al check-in', (tester) async {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressShellPage(
          viewModel: vm,
          pickCheckInPhoto: () async => XFile('/tmp/selfie.jpg'),
        ),
      ),
    );
    await tapSelectPhoto(tester);

    expect(vm.selectedCheckInPhotoLabel, 'selfie.jpg');
    expect(find.text('Foto adjunta al check-in'), findsOneWidget);
  });

  testWidgets('check-in sin foto muestra en el formulario que no se guarda', (
    tester,
  ) async {
    final repo = FakeProgressPhotosRepository();
    final vm = ProgressViewModel(photos: repo);
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ProgressShellPage(viewModel: vm)),
    );
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '74.2');
    await tester.ensureVisible(find.text('Guardar check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar check-in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('aún no se guarda'), findsOneWidget);
    expect(find.textContaining('listo para guardar'), findsNothing);
    expect(repo.uploaded, isEmpty);
  });
}
