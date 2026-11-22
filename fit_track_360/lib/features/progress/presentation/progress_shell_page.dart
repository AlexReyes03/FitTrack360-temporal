import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../core/network/api_client.dart';
import '../data/progress_photos_api.dart';
import '../domain/progress_photo.dart';
import 'progress_page.dart';
import 'progress_view_model.dart';
import 'state/progress_view_state.dart';

/// Abre el selector de fotos; sustituible en pruebas.
typedef PickCheckInPhoto = Future<XFile?> Function();

/// Host de [ProgressPage]: cablea fotos `/photos` y deja métricas bloqueadas.
class ProgressShellPage extends StatefulWidget {
  const ProgressShellPage({
    super.key,
    this.viewModel,
    this.apiClient,
    this.pickCheckInPhoto,
  });

  final ProgressViewModel? viewModel;
  final ApiClient? apiClient;
  final PickCheckInPhoto? pickCheckInPhoto;

  @override
  State<ProgressShellPage> createState() => _ProgressShellPageState();
}

class _ProgressShellPageState extends State<ProgressShellPage> {
  late final ApiClient? _ownedClient;
  late final ProgressViewModel _vm;
  late final bool _ownsVm;
  final ImagePicker _picker = ImagePicker();

  // Mismas opciones que ProgressPhotoPage (P1, docs/permisos.md).
  static const _maxWidth = 1280.0;
  static const _quality = 70;

  @override
  void initState() {
    super.initState();
    final implementation = ImagePickerPlatform.instance;
    if (implementation is ImagePickerAndroid) {
      implementation.useAndroidPhotoPicker = true;
    }
    if (widget.viewModel != null) {
      _vm = widget.viewModel!;
      _ownsVm = false;
      _ownedClient = null;
    } else {
      final client = widget.apiClient ?? ApiClient();
      _ownedClient = widget.apiClient == null ? client : null;
      _vm = ProgressViewModel(photos: ProgressPhotosApi(client));
      _ownsVm = true;
    }
    _vm.addListener(_onVm);
  }

  void _onVm() {
    if (_vm.sessionExpired && mounted) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    if (_ownsVm) _vm.dispose();
    _ownedClient?.dispose();
    super.dispose();
  }

  Future<XFile?> _pickFromGallery() => _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: _maxWidth,
    imageQuality: _quality,
  );

  Future<void> _selectCheckInPhoto() async {
    final XFile? picked;
    try {
      picked = await (widget.pickCheckInPhoto ?? _pickFromGallery)();
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la galería. Intenta de nuevo.'),
        ),
      );
      return;
    }
    if (picked == null || !mounted) return;
    _vm.selectPendingPhoto(File(picked.path), label: _photoLabel(picked));
  }

  /// En Windows, `XFile.name` a veces trae la ruta completa si el path usa `/`.
  static String _photoLabel(XFile file) {
    final raw = file.name.isNotEmpty ? file.name : file.path;
    final slash = raw.lastIndexOf('/');
    final back = raw.lastIndexOf(r'\');
    final cut = slash > back ? slash : back;
    return cut >= 0 ? raw.substring(cut + 1) : raw;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return ProgressPage(
          initialRange: _vm.range,
          chartStatus: _vm.chartStatus,
          checkInStatus: _vm.checkInStatus,
          historyStatus: _vm.historyStatus,
          comparisonStatus: _vm.comparisonStatus,
          chartData: _vm.chartData,
          historyEntries: _vm.historyEntries,
          initialPhotoSlot: _vm.initialPhotoSlot,
          currentPhotoSlot: _vm.currentPhotoSlot,
          selectedCheckInPhotoLabel: _vm.selectedCheckInPhotoLabel,
          isSubmittingCheckIn: _vm.isSubmittingCheckIn,
          checkInFeedback: _vm.checkInFeedback,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/app');
            }
          },
          onRangeChanged: _vm.setRange,
          onSelectCheckInPhoto: _selectCheckInPhoto,
          // El resultado se muestra dentro del formulario (checkInFeedback).
          onSubmitCheckIn: (ProgressCheckInDraft draft) =>
              _vm.submitCheckIn(draft),
          onComparePhotos: () {
            final comparison = _vm.sessionComparison;
            context.push(
              '/app/progreso/comparar',
              extra: comparison ?? const PhotoComparison(),
            );
          },
          onAddPhoto: () => context.push('/app/foto'),
          onRetryChart: _vm.reloadMetrics,
          onRetryHistory: _vm.reloadMetrics,
          onRetryComparison: _vm.refreshComparison,
        );
      },
    );
  }
}
