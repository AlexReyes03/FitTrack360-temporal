import 'dart:async';
import 'dart:typed_data';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/features/progress/data/progress_photos_api.dart';
import 'package:fit_track_360/features/progress/domain/progress_photo.dart';
import 'package:fit_track_360/features/progress/presentation/photo_comparison_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_progress_photo_loader.dart';
import 'support/progress_test_data.dart';
import 'support/progress_test_helpers.dart';

Future<void> _pumpPage(
  WidgetTester tester, {
  required AsyncState<PhotoComparison> state,
  FakeProgressPhotoLoader? loader,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PhotoComparisonPage(
        state: state,
        loader: loader ?? FakeProgressPhotoLoader(),
        onRetry: onRetry,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('muestra loading mientras se resuelven las referencias', (
    tester,
  ) async {
    await _pumpPage(tester, state: const AsyncLoading<PhotoComparison>());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('muestra dos fotos con etiquetas y fechas', (tester) async {
    final loader = FakeProgressPhotoLoader(
      bytes: {'inicial': transparentImage, 'actual': transparentImage},
    );

    await _pumpPage(
      tester,
      state: AsyncData(
        PhotoComparison(
          initial: photoRef('inicial', DateTime(2026, 3, 5)),
          current: photoRef('actual', DateTime(2026, 4, 12)),
        ),
      ),
      loader: loader,
    );
    await tester.pumpAndSettle();

    expect(find.text('Inicial'), findsOneWidget);
    expect(find.text('Actual'), findsOneWidget);
    expect(find.text('05/03/2026'), findsOneWidget);
    expect(find.text('12/04/2026'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Inicial')).dx,
      lessThan(tester.getTopLeft(find.text('Actual')).dx),
    );
  });

  testWidgets('muestra una sola foto e invita a agregar otra', (tester) async {
    await _pumpPage(
      tester,
      state: AsyncData(
        PhotoComparison(initial: photoRef('inicial', DateTime(2026, 3, 5))),
      ),
      loader: FakeProgressPhotoLoader(bytes: {'inicial': transparentImage}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inicial'), findsOneWidget);
    expect(find.text('Actual'), findsNothing);
    expect(
      find.text('Agrega otra foto para comparar tu avance.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Agregar foto'), findsOneWidget);
  });

  testWidgets('muestra vacío cuando no hay referencias', (tester) async {
    await _pumpPage(tester, state: const AsyncEmpty<PhotoComparison>());

    expect(
      find.text('Aún no hay fotos de progreso para comparar.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Agregar foto'), findsOneWidget);
  });

  testWidgets('muestra error y permite reintentar', (tester) async {
    var retries = 0;

    await _pumpPage(
      tester,
      state: AsyncError<PhotoComparison>(Exception('fallo')),
      onRetry: () => retries++,
    );

    expect(find.text('No se pudieron cargar las fotos.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
    expect(retries, 1);
  });

  testWidgets('cada imagen se carga de forma independiente', (tester) async {
    final first = Completer<Uint8List>();
    final second = Completer<Uint8List>();
    final loader = FakeProgressPhotoLoader(
      gates: {'inicial': first, 'actual': second},
    );

    await _pumpPage(
      tester,
      state: AsyncData(
        PhotoComparison(
          initial: photoRef('inicial'),
          current: photoRef('actual'),
        ),
      ),
      loader: loader,
    );

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

    first.complete(transparentImage);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    second.complete(transparentImage);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('un 404 en una foto no oculta la otra', (tester) async {
    final loader = FakeProgressPhotoLoader(
      bytes: {'actual': transparentImage},
      errors: {'inicial': const ProgressPhotoUnavailableException()},
    );

    await _pumpPage(
      tester,
      state: AsyncData(
        PhotoComparison(
          initial: photoRef('inicial'),
          current: photoRef('actual'),
        ),
      ),
      loader: loader,
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la foto.'), findsOneWidget);
    expect(find.text('Inicial'), findsOneWidget);
    expect(find.text('Actual'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('No se pudieron cargar las fotos.'), findsNothing);
  });

  testWidgets('una imagen inválida no bloquea la otra', (tester) async {
    final loader = FakeProgressPhotoLoader(
      bytes: {
        'inicial': Uint8List.fromList([1, 2, 3]),
        'actual': transparentImage,
      },
    );

    await _pumpPage(
      tester,
      state: AsyncData(
        PhotoComparison(
          initial: photoRef('inicial'),
          current: photoRef('actual'),
        ),
      ),
      loader: loader,
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la foto.'), findsOneWidget);
    expect(find.text('Actual'), findsOneWidget);
    expect(find.text('No se pudieron cargar las fotos.'), findsNothing);
  });

  testWidgets('reintenta solo la foto que falló', (tester) async {
    final loader = FakeProgressPhotoLoader(
      bytes: {'inicial': transparentImage, 'actual': transparentImage},
      errors: {'inicial': const ProgressPhotoUnavailableException()},
      failFirst: {'inicial'},
    );

    await _pumpPage(
      tester,
      state: AsyncData(
        PhotoComparison(
          initial: photoRef('inicial'),
          current: photoRef('actual'),
        ),
      ),
      loader: loader,
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la foto.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
    await tester.pumpAndSettle();

    expect(loader.calls['inicial'], 2);
    expect(find.text('No se pudo cargar la foto.'), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('apila las fotos en pantallas estrechas', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPage(
      tester,
      state: AsyncData(
        PhotoComparison(
          initial: photoRef('inicial'),
          current: photoRef('actual'),
        ),
      ),
      loader: FakeProgressPhotoLoader(
        bytes: {'inicial': transparentImage, 'actual': transparentImage},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Inicial')).dy,
      lessThan(tester.getTopLeft(find.text('Actual')).dy),
    );
  });

  testWidgets('navega a agregar foto desde el estado vacío', (tester) async {
    final router = _testRouter(
      const AsyncEmpty<PhotoComparison>(),
      FakeProgressPhotoLoader(),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Agregar foto'));
    await tester.pumpAndSettle();

    expect(find.text('alta foto'), findsOneWidget);
  });

  testWidgets(
    'vuelve a la pantalla anterior cuando se abrió desde el historial',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/app',
        routes: [
          GoRoute(
            path: '/app',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/app/progreso/comparar'),
                  child: const Text('abrir comparación'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/app/progreso/comparar',
            builder: (context, state) => PhotoComparisonPage(
              state: const AsyncEmpty<PhotoComparison>(),
              loader: FakeProgressPhotoLoader(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('abrir comparación'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('abrir comparación'), findsOneWidget);
      expect(
        find.text('Aún no hay fotos de progreso para comparar.'),
        findsNothing,
      );
    },
  );

  testWidgets('vuelve al inicio cuando no hay historial previo', (
    tester,
  ) async {
    final router = _testRouter(
      const AsyncEmpty<PhotoComparison>(),
      FakeProgressPhotoLoader(),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('inicio'), findsOneWidget);
  });
}

GoRouter _testRouter(
  AsyncState<PhotoComparison> comparison,
  ProgressPhotoLoader loader,
) {
  return GoRouter(
    initialLocation: '/app/progreso/comparar',
    routes: [
      GoRoute(
        path: '/app/progreso/comparar',
        builder: (context, state) =>
            PhotoComparisonPage(state: comparison, loader: loader),
      ),
      GoRoute(
        path: '/app/foto',
        builder: (context, state) => const Scaffold(body: Text('alta foto')),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const Scaffold(body: Text('inicio')),
      ),
    ],
  );
}
