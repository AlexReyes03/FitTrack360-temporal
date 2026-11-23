import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/widgets/app_background.dart';
import 'glass_bottom_nav_bar.dart';

/// Shell visual reutilizable con fondo fijo Liquid Glass, slots de banner,
/// cabecera, cuerpo, pie opcional y barra inferior. Sin acoplamiento a
/// GoRouter ni sesion.
class HomeNavigationShell extends StatelessWidget {
  const HomeNavigationShell({
    super.key,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.topBanner,
    this.header,
    this.footer,
  });

  final Widget? topBanner;
  final Widget? header;
  final Widget body;
  final Widget? footer;
  final List<GlassNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Indica si el [context] vive dentro de [HomeNavigationShell].
  ///
  /// Permite a las vistas de pestaña evitar un segundo [AppBackground] y
  /// compactar su espaciado superior al compartir el header del shell.
  static bool isEmbedded(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_HomeNavigationShellScope>() !=
        null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?topBanner,
                  ?header,
                  Expanded(
                    child: _HomeNavigationShellScope(
                      // El shell ya absorbe el inset superior y la barra
                      // inferior absorbe el inferior.
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: body,
                      ),
                    ),
                  ),
                  ?footer,
                  GlassBottomNavBar(
                    destinations: destinations,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeNavigationShellScope extends InheritedWidget {
  const _HomeNavigationShellScope({required super.child});

  @override
  bool updateShouldNotify(_HomeNavigationShellScope oldWidget) => false;
}
