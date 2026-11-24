import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';
import '../widgets/app_background.dart';

/// Plantilla base: fondo del DS + slot opcional [header] fijo arriba.
///
/// Con [header] (normalmente un `PageHeader`), la cabecera respeta el área
/// segura superior, queda centrada en `contentMaxWidth` y no se desplaza con
/// [body]; el [body] recibe el padding superior ya consumido.
class AppScaffoldTemplate extends StatelessWidget {
  final Widget body;
  final Widget? header;

  const AppScaffoldTemplate({super.key, required this.body, this.header});

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: header == null
            ? body
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSpacing.contentMaxWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: header,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: body,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
