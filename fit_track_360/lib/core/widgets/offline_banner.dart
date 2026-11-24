import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/components/secondary_button.dart';
import '../../design_system/components/status_banner.dart';
import '../network/connectivity_service.dart';

/// Banner no bloqueante que aparece cuando el dispositivo pierde la red (F7).
///
/// Se coloca arriba del contenido de la pantalla; no abre dialogos ni
/// intercepta la navegacion. Al tocar **Reintentar** vuelve a consultar la
/// conectividad y llama a [onRetry] para que la pantalla padre decida que
/// recargar.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.onRetry, this.service});

  /// Lo que la pantalla quiere repetir (por ejemplo, volver a pedir datos).
  final VoidCallback onRetry;

  /// Fuente de conectividad; por defecto usa [ConnectivityService].
  final ConnectivityService? service;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final ConnectivityService _service =
      widget.service ?? ConnectivityService();
  StreamSubscription<bool>? _subscription;
  bool _online = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _subscription = _service.onStatusChange.listen(
      _setOnline,
      onError: (_) {}, // Un fallo del plugin no debe tumbar la app.
    );
    _service.isOnline().then(_setOnline);
  }

  void _setOnline(bool online) {
    if (!mounted || online == _online) return;
    setState(() => _online = online);
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      _setOnline(await _service.isOnline());
      widget.onRetry();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: _online
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _BannerBody(checking: _checking, onRetry: _retry),
            ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.checking, required this.onRetry});

  final bool checking;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      variant: StatusBannerVariant.warning,
      icon: Icons.wifi_off_rounded,
      title: 'Sin conexión',
      message: 'Revisa tu red. Puedes seguir usando la app.',
      trailing: SecondaryButton(
        label: 'Reintentar',
        semanticLabel: 'Reintentar conexión',
        size: SecondaryButtonSize.compact,
        isLoading: checking,
        onPressed: onRetry,
      ),
    );
  }
}
