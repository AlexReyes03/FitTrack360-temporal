import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../network/connectivity_service.dart';

/// Colores de la variante Warning de StatusBanner
/// (`fit_track_360/docs/design-system.md`, seccion Tokens).
const Color _warningFill = Color(0x24F59E0B); // #f59e0b @ 14 %
const Color _warningBorder = Color(0x66FBBF24); // #fbbf24 @ 40 %
const Color _warningText = Color(0xFFFDE68A);

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
    return Semantics(
      container: true,
      liveRegion: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _warningFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _warningBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: _warningText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sin conexión',
                          style: TextStyle(
                            color: _warningText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Revisa tu red. Puedes seguir usando la app.',
                          style: TextStyle(color: _warningText, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RetryButton(checking: checking, onPressed: onRetry),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill compacta con el acento blanco/plata; 1 dp de elevacion al presionar.
class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.checking, required this.onPressed});

  final bool checking;
  final VoidCallback onPressed;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.checking;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Reintentar conexión',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? -1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 40, minWidth: 104),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accentWhite.withValues(alpha: 0.85),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _pressed
                  ? const [AppColors.accentWhite, Color(0xFFF4F4F5)]
                  : const [
                      AppColors.accentWhite,
                      Color(0xFFE4E4E7),
                      AppColors.accentSilver,
                    ],
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: widget.checking
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnAccent,
                    ),
                  )
                : const Text(
                    'Reintentar',
                    style: TextStyle(
                      color: AppColors.textOnAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
