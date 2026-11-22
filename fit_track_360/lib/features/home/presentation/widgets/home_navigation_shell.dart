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
                  Expanded(child: body),
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
