import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_client.dart';
import '../data/progress_metrics_api.dart';
import '../data/progress_photo_session_store.dart';
import '../data/progress_photos_api.dart';
import '../domain/progress_photo.dart';
import 'progress_page.dart';
import 'progress_view_model.dart';
import 'state/progress_view_state.dart';
import 'widgets/photo_source_sheet.dart';

/// Abre la cámara o la galería; sustituible en pruebas.
typedef PickCheckInPhoto = Future<XFile?> Function(ImageSource source);

/// Pide el permiso de cámara; sustituible en pruebas.
typedef RequestCameraPermission = Future<PermissionStatus> Function();

/// Host de [ProgressPage]: cablea fotos `/photos` y métricas `/progress`.
class ProgressShellPage extends StatefulWidget {
  const ProgressShellPage({
    super.key,
    this.viewModel,
    this.apiClient,
    this.pickCheckInPhoto,
    this.requestCameraPermission,
    this.photoSession,
  });

  final ProgressViewModel? viewModel;
  final ApiClient? apiClient;
  final PickCheckInPhoto? pickCheckInPhoto;
  final RequestCameraPermission? requestCameraPermission;

  /// Fotos de la sesión compartidas con `/app/foto`. Por defecto el registro
  /// global de la app; solo se usa si el shell crea su propio ViewModel.
  final ProgressPhotoSessionStore? photoSession;

  @override
  State<ProgressShellPage> createState() => _ProgressShellPageState();
}

class _ProgressShellPageState extends State<ProgressShellPage> {
  late final ApiClient? _ownedClient;
  late final ProgressViewModel _vm;
  late final bool _ownsVm;
  ProgressPhotoSessionStore? _ownedPhotoSession;
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
      _ownedPhotoSession =
          widget.photoSession ?? ProgressPhotoSessionStore.instance;
      _vm = ProgressViewModel(
        photos: ProgressPhotosApi(client),
        metrics: ProgressMetricsApi(client),
        photoSession: _ownedPhotoSession,
      );
      _ownsVm = true;
    }
    _vm.addListener(_onVm);
    _vm.reloadMetrics();
  }

  void _onVm() {
    if (_vm.sessionExpired && mounted) {
      // Otra cuenta podría iniciar sesión: no conservar fotos de esta.
      _ownedPhotoSession?.clear();
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

  Future<XFile?> _pickImage(ImageSource source) => _picker.pickImage(
    source: source,
    maxWidth: _maxWidth,
    imageQuality: _quality,
  );

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Hoja Cámara/Galería; la cámara pide permiso antes de abrirse (P1).
  Future<void> _selectCheckInPhoto() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    if (source == ImageSource.camera) {
      final status =
          await (widget.requestCameraPermission ?? Permission.camera.request)();
      if (!mounted) return;
      if (!status.isGranted && !status.isLimited) {
        _showSnack(
          'Permiso de cámara denegado. Puedes elegir una foto de la galería.',
        );
        return;
      }
    }

    final XFile? picked;
    try {
      picked = await (widget.pickCheckInPhoto ?? _pickImage)(source);
    } on PlatformException {
      if (!mounted) return;
      _showSnack(
        source == ImageSource.camera
            ? 'No se pudo abrir la cámara. Intenta de nuevo.'
            : 'No se pudo abrir la galería. Intenta de nuevo.',
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
          selectedCheckInPhotoFile: _vm.pendingPhotoFile,
          isSubmittingCheckIn: _vm.isSubmittingCheckIn,
          checkInFeedback: _vm.checkInFeedback,
          checkInFeedbackTone: _vm.checkInFeedbackTone,
          checkInSavedCount: _vm.checkInSavedCount,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/app');
            }
          },
          onRangeChanged: _vm.setRange,
          onSelectCheckInPhoto: _selectCheckInPhoto,
          onRemoveCheckInPhoto: _vm.clearPendingPhoto,
          // El resultado se muestra dentro del formulario (checkInFeedback).
          onSubmitCheckIn: (ProgressCheckInDraft draft) =>
              _vm.submitCheckIn(draft),
          // Con una sola foto se abre la vista de foto inicial (nunca una
          // pantalla vacía); sin fotos la tarjeta no muestra «Ver detalle».
          onComparePhotos: () => context.push(
            '/app/progreso/comparar',
            extra: _vm.sessionComparison ?? const PhotoComparison(),
          ),
          onAddPhoto: () => context.push('/app/foto'),
          onRetryChart: _vm.reloadMetrics,
          onRetryHistory: _vm.reloadMetrics,
          onRetryComparison: _vm.refreshComparison,
        );
      },
    );
  }
}
