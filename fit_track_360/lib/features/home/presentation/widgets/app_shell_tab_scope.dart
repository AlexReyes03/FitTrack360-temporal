import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Índice de la rama Inicio en `StatefulShellRoute` (ver `appShellDestinations`).
const int appShellHomeTabIndex = 0;

/// Expone la pestaña activa del shell persistente.
///
/// `StatefulShellRoute` conserva el estado de cada rama, así que una vista no
/// se reconstruye al volver a ella. Con este scope, Inicio sabe cuándo el
/// usuario regresa desde otra pestaña y recarga su resumen.
class AppShellTabScope extends InheritedWidget {
  const AppShellTabScope({
    super.key,
    required this.currentTab,
    required super.child,
  });

  final ValueListenable<int> currentTab;

  /// Pestaña activa, o `null` si la vista se monta fuera del shell (pruebas).
  static ValueListenable<int>? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<AppShellTabScope>()
        ?.currentTab;
  }

  @override
  bool updateShouldNotify(AppShellTabScope oldWidget) =>
      currentTab != oldWidget.currentTab;
}
