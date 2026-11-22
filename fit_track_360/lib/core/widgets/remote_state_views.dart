import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design_system/components/glass_surface.dart';
import '../../design_system/components/primary_button.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../async_state.dart';

/// Vista visual de carga remota con indicador monocromo y bloques skeleton
/// estilo Liquid Glass dark. No realiza llamadas de red ni maneja sesiones.
class RemoteLoadingView extends StatelessWidget {
  const RemoteLoadingView({
    super.key,
    this.message = 'Cargando...',
    this.showSkeleton = true,
    this.skeletonLines = 3,
  });

  final String message;
  final bool showSkeleton;
  final int skeletonLines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: GlassSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.accentWhite,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (showSkeleton && skeletonLines > 0) ...[
              const SizedBox(height: 16),
              for (var i = 0; i < skeletonLines; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: i == skeletonLines - 1 ? 0.65 : 1,
                  child: Container(
                    height: i == 0 ? 18 : 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.badge),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Vista visual de estado vacio reutilizable bajo el look Liquid Glass dark.
class RemoteEmptyView extends StatelessWidget {
  const RemoteEmptyView({
    super.key,
    this.title = 'Sin contenido todavía',
    this.message = 'Cuando haya registros aparecerán aquí.',
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, color: AppColors.zinc200, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Vista visual de error remoto con variante danger del DS y CTA opcional
/// de reintento.
class RemoteErrorView extends StatelessWidget {
  const RemoteErrorView({
    super.key,
    this.title = 'No se pudo cargar',
    this.message = 'Ocurrió un problema al obtener los datos.',
    this.retryLabel = 'Reintentar',
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.banner),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.dangerFill,
              borderRadius: BorderRadius.circular(AppRadii.banner),
              border: Border.all(color: AppColors.dangerBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.dangerText, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.dangerText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: const TextStyle(
                                color: AppColors.dangerText,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    PrimaryButton(label: retryLabel, onPressed: onRetry),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Conecta un [AsyncState] con las vistas visuales compartidas de carga,
/// vacio y error, manteniendo el render desacoplado de red y sesion.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.state,
    required this.dataBuilder,
    this.loadingMessage = 'Cargando...',
    this.emptyTitle = 'Sin contenido todavía',
    this.emptyMessage = 'Cuando haya registros aparecerán aquí.',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle = 'No se pudo cargar',
    this.errorMessage = 'Ocurrió un problema al obtener los datos.',
    this.retryLabel = 'Reintentar',
    this.onRetry,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
  });

  final AsyncState<T> state;
  final Widget Function(T data) dataBuilder;
  final String loadingMessage;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final String errorTitle;
  final String errorMessage;
  final String retryLabel;
  final VoidCallback? onRetry;
  final Widget Function()? loadingBuilder;
  final Widget Function()? emptyBuilder;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () =>
          loadingBuilder?.call() ?? RemoteLoadingView(message: loadingMessage),
      data: dataBuilder,
      empty: () =>
          emptyBuilder?.call() ??
          RemoteEmptyView(
            title: emptyTitle,
            message: emptyMessage,
            icon: emptyIcon,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          ),
      error: (error, stackTrace) =>
          errorBuilder?.call(error, stackTrace) ??
          RemoteErrorView(
            title: errorTitle,
            message: errorMessage,
            retryLabel: retryLabel,
            onRetry: onRetry,
          ),
    );
  }
}
