import 'package:fit_track_360/features/auth/presentation/login_page.dart';
import 'package:fit_track_360/features/auth/presentation/register_page.dart';
import 'package:fit_track_360/features/auth/presentation/widgets/google_sign_in_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  testWidgets('LoginPage muestra separador o y CTA Continuar con Google', (
    tester,
  ) async {
    var tapped = 0;

    await tester.pumpWidget(_wrap(LoginPage(onGooglePressed: () => tapped++)));
    await tester.pumpAndSettle();

    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('o'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);

    await tester.ensureVisible(find.text('Continuar con Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets(
    'LoginPage refleja estado loading de Google y bloquea doble tap',
    (tester) async {
      var tapped = 0;

      await tester.pumpWidget(
        _wrap(LoginPage(googleLoading: true, onGooglePressed: () => tapped++)),
      );
      await tester.pump();

      expect(find.text('Conectando con Google...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.ensureVisible(find.text('Conectando con Google...'));
      await tester.pump();
      await tester.tap(find.text('Conectando con Google...'));
      await tester.pump();

      expect(tapped, 0);
    },
  );

  testWidgets('RegisterPage muestra el mismo entrypoint visual de Google', (
    tester,
  ) async {
    var tapped = 0;

    await tester.pumpWidget(
      _wrap(RegisterPage(onGooglePressed: () => tapped++)),
    );
    await tester.pumpAndSettle();

    expect(find.text('o'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);

    await tester.ensureVisible(find.text('Continuar con Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets(
    'GoogleSignInButton soporta cancel visual y modo preview sin error',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GoogleSignInButton(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(GoogleSignInButton);
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(find.text('Continuar con Google'), findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Continuar con Google'), findsOneWidget);
    },
  );
}
