// Sensor "trinquete" de estilos fijos (issue #221).
//
// Recorre `lib/` (excepto `lib/design_system/tokens/`, donde los literales SÍ
// pertenecen) y cuenta cuatro tipos de valores fijos que deberían venir de los
// tokens del design system:
//
//   * fontSize      -> `fontSize: <número>`             (usa AppTypography)
//   * hexColor      -> `Color(0x...)`                    (usa AppColors)
//   * whiteAlpha    -> `Colors.white.withValues(`        (usa AppColors)
//   * radiusLiteral -> `BorderRadius.circular(<número>)` (usa AppRadii)
//
// Mientras la migración (fase B de #221) no termine, el sensor NO exige cero:
// compara contra la línea base de `_baseline` y FALLA si algún conteo SUBE.
// Así nadie agrega literales nuevos, y cada PR que migre pantallas puede bajar
// la línea base.
//
// Cómo bajar la línea base:
//   1. Migra literales a tokens (ver tabla en docs/design-system.md).
//   2. Corre `flutter test test/design_system/hardcoded_style_guard_test.dart`.
//      Si un conteo bajó, el test lo indica en la salida ("Línea base
//      desactualizada") con el valor nuevo.
//   3. Sustituye ese valor en `_baseline` en el mismo PR. Nunca lo subas: si
//      necesitas un literal justificado, agrégalo a `_allowedFiles` con su
//      motivo o crea el token correspondiente.
//
// Cuando todos los conteos lleguen a 0 este test se convierte en una
// prohibición total.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Línea base medida al abrir #221 (fase A). Solo puede bajar.
const Map<String, int> _baseline = {
  'fontSize': 126,
  'hexColor': 22,
  'whiteAlpha': 75,
  'radiusLiteral': 11,
};

final Map<String, RegExp> _patterns = {
  'fontSize': RegExp(r'fontSize:\s*\d+(\.\d+)?\b'),
  'hexColor': RegExp(r'\bColor\(\s*0x[0-9A-Fa-f]+\s*\)'),
  'whiteAlpha': RegExp(r'Colors\.white\.withValues\('),
  'radiusLiteral': RegExp(r'BorderRadius\.circular\(\s*\d+(\.\d+)?\s*\)'),
};

/// Carpetas donde los literales son la fuente de verdad.
const List<String> _excludedDirs = ['lib/design_system/tokens/'];

/// Archivos con literales justificados (generados o fuera del DS visual).
const Map<String, String> _allowedFiles = {
  'lib/firebase_options.dart': 'Generado por FlutterFire.',
};

String _normalize(String path) => path.replaceAll(r'\', '/');

/// Quita comentarios de línea para no contar ejemplos en documentación.
String _stripLineComment(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return '';
  final idx = line.indexOf(' //');
  return idx >= 0 ? line.substring(0, idx) : line;
}

/// Cuenta por tipo y por archivo los literales de estilo en [root].
Map<String, Map<String, int>> scanHardcodedStyles(Directory root) {
  final result = {for (final k in _patterns.keys) k: <String, int>{}};
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = _normalize(file.path);
    if (_excludedDirs.any(path.startsWith)) continue;
    if (_allowedFiles.containsKey(path)) continue;
    final lines = file.readAsLinesSync().map(_stripLineComment);
    for (final entry in _patterns.entries) {
      var count = 0;
      for (final line in lines) {
        count += entry.value.allMatches(line).length;
      }
      if (count > 0) result[entry.key]![path] = count;
    }
  }
  return result;
}

void main() {
  test('los patrones detectan literales y respetan tokens', () {
    expect(_patterns['fontSize']!.hasMatch('fontSize: 12.5,'), isTrue);
    expect(_patterns['fontSize']!.hasMatch('fontSize: size,'), isFalse);
    expect(_patterns['hexColor']!.hasMatch('const Color(0xB807080C)'), isTrue);
    expect(_patterns['hexColor']!.hasMatch('AppColors.inputFill'), isFalse);
    expect(
      _patterns['whiteAlpha']!.hasMatch('Colors.white.withValues(alpha: 1)'),
      isTrue,
    );
    expect(
      _patterns['radiusLiteral']!.hasMatch('BorderRadius.circular(14)'),
      isTrue,
    );
    expect(
      _patterns['radiusLiteral']!.hasMatch(
        'BorderRadius.circular(AppRadii.input)',
      ),
      isFalse,
    );
    expect(_stripLineComment('  // Color(0xFF000000)'), isEmpty);
  });

  test('los literales de estilo en lib/ no superan la línea base', () {
    final scan = scanHardcodedStyles(Directory('lib'));
    final failures = <String>[];
    final lowered = <String>[];

    for (final kind in _baseline.keys) {
      final perFile = scan[kind]!;
      final total = perFile.values.fold<int>(0, (a, b) => a + b);
      final base = _baseline[kind]!;
      if (total > base) {
        final top = perFile.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        failures.add(
          '$kind: $total literales (línea base $base, +${total - base}).\n'
          '  Usa tokens de lib/design_system/tokens/ en lugar de literales.\n'
          '  Archivos con más ocurrencias:\n'
          '${top.take(10).map((e) => '    ${e.value.toString().padLeft(3)}  ${e.key}').join('\n')}',
        );
      } else if (total < base) {
        lowered.add("'$kind': $total, // antes $base");
      }
    }

    if (lowered.isNotEmpty) {
      debugPrint(
        'Línea base desactualizada: los literales bajaron. Actualiza '
        '_baseline en test/design_system/hardcoded_style_guard_test.dart:\n'
        '  ${lowered.join('\n  ')}',
      );
    }

    expect(
      failures,
      isEmpty,
      reason:
          'Se agregaron estilos fijos fuera de los tokens del DS:\n'
          '${failures.join('\n\n')}',
    );
  });
}
