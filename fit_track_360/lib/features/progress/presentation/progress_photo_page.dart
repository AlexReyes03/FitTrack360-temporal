import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/permission_denied_notice.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../data/progress_photo_session_store.dart';
import '../data/progress_photos_api.dart';
import '../domain/progress_photo.dart';
import '../domain/progress_photos_repository.dart';
import 'state/progress_view_state.dart';
import 'widgets/photo_source_sheet.dart';
import 'widgets/progress_status_banner.dart';

/// Abre la cámara o la galería; sustituible en pruebas.
typedef PickProgressPhoto = Future<XFile?> Function(ImageSource source);

/// `/app/foto`: sube una foto de progreso y la registra en la sesión para que
/// aparezca en Progreso sin reiniciar la app.
class ProgressPhotoPage extends StatefulWidget {
  const ProgressPhotoPage({
    super.key,
    this.photos,
    this.apiClient,
    this.photoSession,
    this.pickPhoto,
    this.requestCameraPermission,
  });

  /// Sustituibles en pruebas.
  final ProgressPhotosRepository? photos;
  final ApiClient? apiClient;
  final ProgressPhotoSessionStore? photoSession;
  final PickProgressPhoto? pickPhoto;
  final Future<PermissionStatus> Function()? requestCameraPermission;

  @override
  State<ProgressPhotoPage> createState() => _ProgressPhotoPageState();
}

enum _CameraDenial { none, denied, permanent }

class _ProgressPhotoPageState extends State<ProgressPhotoPage> {
  static const _maxWidth = 1280.0;
  static const _quality = 70;

  final ImagePicker _picker = ImagePicker();
  ApiClient? _ownedClient;
  late final ProgressPhotosRepository _photos;
  late final ProgressPhotoSessionStore _session;
  bool _busy = false;
  bool _saved = false;
  _CameraDenial _cameraDenial = _CameraDenial.none;
  String? _error;

  @override
  void initState() {
    super.initState();
    final implementation = ImagePickerPlatform.instance;
    if (implementation is ImagePickerAndroid) {
      implementation.useAndroidPhotoPicker = true;
    }
    _session = widget.photoSession ?? ProgressPhotoSessionStore.instance;
    if (widget.photos != null) {
      _photos = widget.photos!;
      _ownedClient = null;
    } else {
      final client = widget.apiClient ?? ApiClient();
      _ownedClient = widget.apiClient == null ? client : null;
      _photos = ProgressPhotosApi(client);
    }
  }

  @override
  void dispose() {
    _ownedClient?.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  void _openComparison() {
    context.go(
      '/app/progreso/comparar',
      extra: comparisonFromPhotos(_session.photos) ?? const PhotoComparison(),
    );
  }

  Future<void> _openChoices() async {
    if (_busy) return;
    final source = await showPhotoSourceSheet(context);
    if (!mounted || source == null) return;
    switch (source) {
      case ImageSource.camera:
        await _pickFromCamera();
      case ImageSource.gallery:
        await _pickFromGallery();
    }
  }

  Future<void> _pickFromCamera() async {
    final status =
        await (widget.requestCameraPermission ?? Permission.camera.request)();
    if (!mounted) return;
    if (status.isGranted || status.isLimited) {
      setState(() => _cameraDenial = _CameraDenial.none);
      await _pickAndUpload(ImageSource.camera);
      return;
    }
    setState(() {
      _error = null;
      _cameraDenial = status.isPermanentlyDenied
          ? _CameraDenial.permanent
          : _CameraDenial.denied;
    });
  }

  Future<void> _pickFromGallery() async {
    setState(() => _cameraDenial = _CameraDenial.none);
    await _pickAndUpload(ImageSource.gallery);
  }

  Future<XFile?> _pickImage(ImageSource source) => _picker.pickImage(
    source: source,
    maxWidth: _maxWidth,
    imageQuality: _quality,
  );

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await (widget.pickPhoto ?? _pickImage)(source);
      if (picked == null || !mounted) return;
      setState(() {
        _busy = true;
        _saved = false;
        _error = null;
      });
      try {
        final meta = await _photos.upload(File(picked.path));
        if (!mounted) return;
        _session.add(meta);
        setState(() => _saved = true);
      } on SessionExpiredException {
        _session.clear();
        if (mounted) context.go('/login');
      } on ProgressPhotoUnavailableException {
        if (!mounted) return;
        setState(() => _error = 'Foto no disponible.');
      } on ProgressPhotoValidationException catch (error) {
        if (!mounted) return;
        setState(() => _error = error.message);
      } catch (_) {
        if (!mounted) return;
        setState(() => _error = 'No se pudo subir la foto. Intenta de nuevo.');
      }
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _error = source == ImageSource.camera
            ? 'No se pudo abrir la cámara. Intenta de nuevo.'
            : 'No se pudo abrir la galería. Intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      tooltip: 'Volver',
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Expanded(
                      child: Text(
                        'Foto de progreso',
                        style: AppTypography.pageTitle,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _body(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Toma o elige una foto para comparar tu avance. Se reduce antes de '
        'subirla y solo tú puedes verla.',
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_saved) ...[
        const ProgressStatusBanner(
          title: 'Foto guardada',
          message: 'Ya aparece en tu comparación de progreso.',
          tone: ProgressFeedbackTone.success,
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(label: 'Ver comparación', onPressed: _openComparison),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _openChoices,
            child: const Text(
              'Agregar otra foto',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ] else
        PrimaryButton(
          label: _busy ? 'Subiendo...' : 'Agregar foto',
          onPressed: _busy ? null : _openChoices,
        ),
      if (_cameraDenial != _CameraDenial.none) ...[
        const SizedBox(height: AppSpacing.md),
        PermissionDeniedNotice(
          title: 'Permiso de cámara denegado',
          message: _cameraDenial == _CameraDenial.permanent
              ? 'Puedes elegir una foto de la galería o habilitar la cámara '
                    'desde los ajustes del dispositivo.'
              : 'Puedes elegir una foto de la galería o volver a intentarlo '
                    'con la cámara.',
          icon: Icons.no_photography_outlined,
          actionLabel: 'Elegir de la galería',
          onAction: _busy ? null : _pickFromGallery,
          secondaryActionLabel: _cameraDenial == _CameraDenial.permanent
              ? 'Abrir ajustes'
              : null,
          onSecondaryAction: openAppSettings,
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        ProgressStatusBanner(
          message: _error!,
          tone: ProgressFeedbackTone.error,
        ),
      ],
    ];
  }
}
