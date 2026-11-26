import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/app_background.dart';
import '../data/privacy_api_repository.dart';
import '../domain/privacy_notice.dart';
import '../domain/privacy_repository.dart';
import 'privacy_notice_view_model.dart';

class PrivacyNoticePage extends StatefulWidget {
  const PrivacyNoticePage({super.key, required this.userId, this.repository});

  final String userId;
  final PrivacyRepository? repository;

  @override
  State<PrivacyNoticePage> createState() => _PrivacyNoticePageState();
}

class _PrivacyNoticePageState extends State<PrivacyNoticePage> {
  ApiClient? _ownedClient;
  late final PrivacyNoticeViewModel _vm = PrivacyNoticeViewModel(
    widget.repository ?? PrivacyApiRepository(_ownedClient = ApiClient()),
    userId: widget.userId,
  );
  bool _acceptedNotice = false;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onChange);
    _vm.load();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onChange);
    _vm.dispose();
    _ownedClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Aviso de privacidad',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _vm.state.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentWhite,
                  ),
                ),
                error: (error, _) => _RetryMessage(
                  text: _vm.error ?? privacyUnavailableMessage,
                  onRetry: error is SessionExpiredException
                      ? () => context.go('/login')
                      : _vm.load,
                  actionLabel: error is SessionExpiredException
                      ? 'Iniciar sesión'
                      : 'Reintentar',
                  actionKey: error is SessionExpiredException
                      ? const Key('privacy-load-login')
                      : null,
                ),
                empty: () => _RetryMessage(
                  text: 'El aviso no tiene secciones para mostrar.',
                  onRetry: _vm.load,
                ),
                data: _content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(PrivacyNotice notice) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versión ${notice.version} · '
                '${formatPrivacyNoticeDate(notice.date)}',
                key: const Key('privacy-version'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              for (final (index, section) in notice.sections.indexed) ...[
                const SizedBox(height: 16),
                Text(
                  section.title,
                  key: Key('privacy-section-title-$index'),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  section.text,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (!notice.includesMedicalLimit) ...[
                const SizedBox(height: 16),
                const Text(
                  'El aviso recibido no incluye una sección de salud.',
                  key: Key('privacy-medical-missing'),
                  style: TextStyle(color: AppColors.warningText),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _consent(),
      ],
    );
  }

  Widget _consent() {
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Consentimiento',
            style: AppTypography.body.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (!_vm.versionSupported)
            const Text(
              privacyConsentVersionMessage,
              key: Key('privacy-version-warning'),
              style: TextStyle(color: AppColors.warningText),
            )
          else if (_vm.receipt != null)
            Text(
              'Consentimiento registrado para la versión '
              '${_vm.receipt!.version}.',
              key: const Key('privacy-consent-confirmation'),
            )
          else ...[
            const Text(
              'Al aceptar se registrará tu consentimiento en el servidor para '
              'la versión vigente del aviso.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: const Key('privacy-consent-checkbox'),
                value: _acceptedNotice,
                onChanged: _vm.submitting
                    ? null
                    : (value) =>
                          setState(() => _acceptedNotice = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.accentWhite,
                title: const Text(
                  'He leído y acepto el aviso de privacidad.',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
            PrimaryButton(
              label: _vm.submitting ? 'Registrando...' : 'Aceptar aviso',
              onPressed: _vm.canAcceptConsent && _acceptedNotice
                  ? _vm.acceptConsent
                  : null,
            ),
          ],
          if (_vm.error != null) ...[
            const SizedBox(height: 12),
            Text(
              _vm.error!,
              key: const Key('privacy-consent-error'),
              style: const TextStyle(color: AppColors.warningText),
            ),
            if (_vm.error == privacySessionExpiredMessage)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('privacy-login'),
                  onPressed: () => context.go('/login'),
                  child: const Text(
                    'Iniciar sesión',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({
    required this.text,
    required this.onRetry,
    this.actionLabel = 'Reintentar',
    this.actionKey,
  });

  final String text;
  final VoidCallback onRetry;
  final String actionLabel;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text,
                key: const Key('privacy-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                key: actionKey,
                label: actionLabel,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
