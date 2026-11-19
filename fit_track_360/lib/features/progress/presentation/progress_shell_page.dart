import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../data/progress_photos_api.dart';
import '../domain/progress_photo.dart';
import 'progress_page.dart';
import 'progress_view_model.dart';
import 'widgets/progress_checkin_card.dart';

/// Host de [ProgressPage]: cablea fotos `/photos` y deja métricas bloqueadas.
class ProgressShellPage extends StatefulWidget {
  const ProgressShellPage({super.key, this.viewModel, this.apiClient});

  final ProgressViewModel? viewModel;
  final ApiClient? apiClient;

  @override
  State<ProgressShellPage> createState() => _ProgressShellPageState();
}

class _ProgressShellPageState extends State<ProgressShellPage> {
  late final ApiClient? _ownedClient;
  late final ProgressViewModel _vm;
  late final bool _ownsVm;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _vm = widget.viewModel!;
      _ownsVm = false;
      _ownedClient = null;
    } else {
      final client = widget.apiClient ?? ApiClient();
      _ownedClient = widget.apiClient == null ? client : null;
      _vm = ProgressViewModel(photosApi: ProgressPhotosApi(client));
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

  Future<void> _selectCheckInPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;
    _vm.selectPendingPhoto(File(picked.path), label: picked.name);
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
          usePreviewPhotos: false,
          selectedCheckInPhotoLabel: _vm.selectedCheckInPhotoLabel,
          isSubmittingCheckIn: _vm.isSubmittingCheckIn,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/app');
            }
          },
          onRangeChanged: _vm.setRange,
          onSelectCheckInPhoto: _selectCheckInPhoto,
          onSubmitCheckIn: (ProgressCheckInDraft draft) async {
            await _vm.submitCheckIn(draft);
            if (!mounted) return;
            final msg = _vm.checkInFeedback;
            if (msg != null) {
              final messenger = ScaffoldMessenger.of(this.context);
              messenger.showSnackBar(SnackBar(content: Text(msg)));
            }
          },
          onComparePhotos: () {
            final comparison = _vm.sessionComparison;
            context.push(
              '/app/progreso/comparar',
              extra: comparison ?? const PhotoComparison(),
            );
          },
          onAddPhoto: () => context.push('/app/foto'),
          onRetryChart: () => _vm.setRange(_vm.range),
          onRetryHistory: () => _vm.setRange(_vm.range),
          onRetryComparison: () {},
        );
      },
    );
  }
}
