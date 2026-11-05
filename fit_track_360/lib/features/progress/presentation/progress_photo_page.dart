import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_client.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';

class ProgressPhotoPage extends StatefulWidget {
  const ProgressPhotoPage({super.key});

  @override
  State<ProgressPhotoPage> createState() => _ProgressPhotoPageState();
}

class _ProgressPhotoPageState extends State<ProgressPhotoPage> {
  static const _maxWidth = 1280.0;
  static const _quality = 70;

  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  bool _canOpenSettings = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final implementation = ImagePickerPlatform.instance;
    if (implementation is ImagePickerAndroid) {
      implementation.useAndroidPhotoPicker = true;
    }
  }

  Future<void> _openChoices() async {
    if (_busy) return;
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      backgroundColor: AppColors.bgMid,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Cámara',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, _PhotoChoice.camera),
              ),
              ListTile(
                title: const Text(
                  'Galería',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, _PhotoChoice.gallery),
              ),
              ListTile(
                title: const Text(
                  'Continuar sin foto',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () => Navigator.pop(context, _PhotoChoice.skip),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _PhotoChoice.camera:
        await _pickFromCamera();
      case _PhotoChoice.gallery:
        await _pickFromGallery();
      case _PhotoChoice.skip:
        setState(() {
          _canOpenSettings = false;
          _message = 'Seguiste sin foto. No se subió ninguna imagen.';
        });
    }
  }

  Future<void> _pickFromCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted || status.isLimited) {
      await _pickAndUpload(ImageSource.camera);
      return;
    }
    setState(() {
      _canOpenSettings = status.isPermanentlyDenied;
      _message = status.isPermanentlyDenied
          ? 'Permiso de cámara denegado de forma permanente. Puedes elegir una foto de la galería, continuar sin foto o abrir ajustes.'
          : 'Permiso de cámara denegado. Puedes elegir una foto de la galería o continuar sin foto.';
    });
  }

  Future<void> _pickFromGallery() async {
    setState(() => _canOpenSettings = false);
    await _pickAndUpload(ImageSource.gallery);
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: _maxWidth,
        imageQuality: _quality,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _busy = true;
        _message = null;
      });
      final client = ApiClient();
      try {
        final response = await client.uploadFile(
          '/api/v1/storage/files',
          File(picked.path),
        );
        if (!mounted) return;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          final id = body is Map ? body['id'] : null;
          setState(() {
            _canOpenSettings = false;
            _message = id == null ? 'Foto subida.' : 'Foto subida ($id).';
          });
        } else {
          setState(() => _message = 'No se pudo subir la foto.');
        }
      } on SessionExpiredException {
        if (mounted) context.go('/login');
      } finally {
        client.dispose();
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message ?? 'No se pudo abrir la cámara o la galería.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Agregar foto', style: AppTypography.pageTitle),
              const SizedBox(height: 12),
              Text(
                'La foto es de tu progreso o de una comida. Se reduce antes de subirla y solo tú puedes verla en el servidor.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _busy ? 'Subiendo...' : 'Agregar foto',
                onPressed: _busy ? null : _openChoices,
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              if (_canOpenSettings) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text(
                    'Abrir ajustes',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _PhotoChoice { camera, gallery, skip }
