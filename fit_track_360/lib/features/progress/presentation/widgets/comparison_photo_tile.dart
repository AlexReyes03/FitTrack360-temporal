import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/async_state.dart';
import '../../../../core/network/api_client.dart';
import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../data/progress_photos_api.dart';
import '../../domain/progress_photo.dart';
import '../progress_photo_format.dart';

class ComparisonPhotoTile extends StatefulWidget {
  const ComparisonPhotoTile({
    super.key,
    required this.label,
    required this.photo,
    required this.loader,
    this.onSessionExpired,
  });

  final String label;
  final ProgressPhotoRef photo;
  final ProgressPhotoLoader loader;
  final VoidCallback? onSessionExpired;

  @override
  State<ComparisonPhotoTile> createState() => _ComparisonPhotoTileState();
}

class _ComparisonPhotoTileState extends State<ComparisonPhotoTile> {
  AsyncState<Uint8List> _state = const AsyncLoading<Uint8List>();
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ComparisonPhotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id ||
        oldWidget.loader != widget.loader) {
      _load();
    }
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() => _state = const AsyncLoading<Uint8List>());
    try {
      final bytes = await widget.loader.load(widget.photo.id);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _state = bytes.isEmpty
            ? const AsyncEmpty<Uint8List>()
            : AsyncData<Uint8List>(bytes);
      });
    } on SessionExpiredException {
      if (!mounted) return;
      final handler = widget.onSessionExpired;
      if (handler != null) {
        handler();
        return;
      }
      setState(
        () => _state = const AsyncError<Uint8List>(SessionExpiredException()),
      );
    } catch (error, stackTrace) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = AsyncError<Uint8List>(error, stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) {
    final takenAt = widget.photo.takenAt;

    return GlassSurface(
      radius: AppRadii.inner,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(widget.label, style: _labelStyle),
              const Spacer(),
              if (takenAt != null)
                Text(
                  formatPhotoDate(takenAt),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.option),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ColoredBox(
                color: AppColors.bgMid,
                child: _state.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentWhite,
                    ),
                  ),
                  data: (bytes) => Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) => _failure(),
                  ),
                  error: (error, stackTrace) => _failure(),
                  empty: _failure,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failure() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textMuted,
              size: 28,
            ),
            const SizedBox(height: 4),
            const Text(
              'No se pudo cargar la foto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Reintentar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w700,
);
