import 'package:fit_track_360/core/widgets/permission_denied_notice.dart';
import 'package:fit_track_360/features/progress/data/progress_photo_session_store.dart';
import 'package:fit_track_360/features/progress/domain/progress_photo.dart';
import 'package:fit_track_360/features/progress/domain/progress_photo_errors.dart';
import 'package:fit_track_360/features/progress/presentation/progress_photo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/fake_progress_photos_repository.dart';

void main() {
  late FakeProgressPhotosRepository repo;
  late ProgressPhotoSessionStore store;
  late List<ImageSource> sources;
  Object? comparisonExtra;

  setUp(() {
    repo = FakeProgressPhotosRepository();
    store = ProgressPhotoSessionStore();
    sources = [];
    comparisonExtra = null;
  });

  Future<GoRouter> pumpPage(
    WidgetTester tester, {
    PermissionStatus camera = PermissionStatus.granted,
  }) async {
    final router = GoRouter(
      initialLocation: '/app',
      routes: [
        GoRoute(
          path: '/app',
          builder: (context, state) => const Scaffold(body: Text('inicio')),
        ),
        GoRoute(
          path: '/app/foto',
          builder: (context, state) => ProgressPhotoPage(
            photos: repo,
            photoSession: store,
            requestCameraPermission: () async => camera,
            pickPhoto: (source) async {
              sources.add(source);
              return XFile('/tmp/progreso.jpg');
            },
          ),
        ),
        GoRoute(
          path: '/app/progreso/comparar',
          builder: (context, state) {
            comparisonExtra = state.extra;
            return const Scaffold(body: Text('comparación'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/app/foto');
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.text('Agregar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  testWidgets('tiene botón para volver', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('no menciona comidas ni ofrece «Continuar sin foto»', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.textContaining('comida'), findsNothing);

    await tester.tap(find.text('Agregar foto'));
    await tester.pumpAndSettle();

    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
    expect(find.text('Continuar sin foto'), findsNothing);
  });

  testWidgets(
    'al guardar muestra «Foto guardada» sin ID y la registra en Progreso',
    (tester) async {
      await pumpPage(tester);

      await choose(tester, 'Galería');

      expect(sources, [ImageSource.gallery]);
      expect(find.text('Foto guardada'), findsOneWidget);
      expect(find.textContaining('ph-1'), findsNothing);
      expect(store.photos.map((p) => p.id), ['ph-1']);

      await tester.tap(find.text('Ver comparación'));
      await tester.pumpAndSettle();

      expect(find.text('comparación'), findsOneWidget);
      final comparison = comparisonExtra! as PhotoComparison;
      expect(comparison.initial!.id, 'ph-1');
    },
  );

  testWidgets('permiso de cámara denegado usa PermissionDeniedNotice', (
    tester,
  ) async {
    await pumpPage(tester, camera: PermissionStatus.denied);

    await choose(tester, 'Cámara');

    expect(sources, isEmpty);
    expect(find.byType(PermissionDeniedNotice), findsOneWidget);
    expect(find.text('Permiso de cámara denegado'), findsOneWidget);
    expect(find.text('Abrir ajustes'), findsNothing);

    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();

    expect(sources, [ImageSource.gallery]);
    expect(find.byType(PermissionDeniedNotice), findsNothing);
    expect(find.text('Foto guardada'), findsOneWidget);
  });

  testWidgets('permiso denegado de forma permanente ofrece abrir ajustes', (
    tester,
  ) async {
    await pumpPage(tester, camera: PermissionStatus.permanentlyDenied);

    await choose(tester, 'Cámara');

    expect(find.byType(PermissionDeniedNotice), findsOneWidget);
    expect(find.text('Abrir ajustes'), findsOneWidget);
  });

  testWidgets('un error al subir se muestra como error', (tester) async {
    repo.uploadError = const ProgressPhotoValidationException(
      'Formato no permitido',
    );
    await pumpPage(tester);

    await choose(tester, 'Galería');

    expect(find.byKey(const Key('progress-feedback-error')), findsOneWidget);
    expect(find.text('Formato no permitido'), findsOneWidget);
    expect(find.text('Foto guardada'), findsNothing);
    expect(store.photos, isEmpty);
  });
}
