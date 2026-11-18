import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../data/progress_photos_api.dart';
import '../domain/progress_photo.dart';
import 'widgets/comparison_photo_tile.dart';

class PhotoComparisonPage extends StatefulWidget {
  const PhotoComparisonPage({
    super.key,
    required this.state,
    this.loader,
    this.onRetry,
    this.fallbackLocation = '/app',
  });

  final AsyncState<PhotoComparison> state;
  final ProgressPhotoLoader? loader;
  final VoidCallback? onRetry;
  final String fallbackLocation;

  @override
  State<PhotoComparisonPage> createState() => _PhotoComparisonPageState();
}

class _PhotoComparisonPageState extends State<PhotoComparisonPage> {
  late final ApiClient? _ownedClient;
  late final ProgressPhotoLoader _loader;

  @override
  void initState() {
    super.initState();
    _ownedClient = widget.loader == null ? ApiClient() : null;
    _loader = widget.loader ?? ProgressPhotosApi(_ownedClient!);
  }

  @override
  void dispose() {
    _ownedClient?.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(widget.fallbackLocation);
  }

  void _openAddPhoto() => context.push('/app/foto');

  void _handleSessionExpired() {
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                Expanded(
                  child: widget.state.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentWhite,
                      ),
                    ),
                    data: (comparison) =>
                        comparison.isEmpty ? _empty() : _content(comparison),
                    error: (error, stackTrace) => _error(),
                    empty: _empty,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text('Comparación de fotos', style: AppTypography.pageTitle),
          ),
        ],
      ),
    );
  }

  Widget _content(PhotoComparison comparison) {
    final initial = comparison.initial;
    final current = comparison.current;

    Widget tile(ProgressPhotoRef photo, String label) {
      return ComparisonPhotoTile(
        label: label,
        photo: photo,
        loader: _loader,
        onSessionExpired: _handleSessionExpired,
      );
    }

    if (initial == null || current == null) {
      final photo = initial ?? current!;
      final label = initial == null ? 'Actual' : 'Inicial';
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: tile(photo, label),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Agrega otra foto para comparar tu avance.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton(
              onPressed: _openAddPhoto,
              child: const Text(
                'Agregar foto',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final initialTile = tile(initial, 'Inicial');
            final currentTile = tile(current, 'Actual');

            if (constraints.maxWidth < 360) {
              return Column(
                children: [
                  initialTile,
                  const SizedBox(height: AppSpacing.sm),
                  currentTile,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: initialTile),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: currentTile),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _empty() {
    return _centeredMessage(
      'Aún no hay fotos de progreso para comparar.',
      action: TextButton(
        onPressed: _openAddPhoto,
        child: const Text(
          'Agregar foto',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _error() {
    final onRetry = widget.onRetry;
    return _centeredMessage(
      'No se pudieron cargar las fotos.',
      action: onRetry == null
          ? null
          : TextButton(
              onPressed: onRetry,
              child: const Text(
                'Reintentar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
    );
  }

  Widget _centeredMessage(String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xs),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
