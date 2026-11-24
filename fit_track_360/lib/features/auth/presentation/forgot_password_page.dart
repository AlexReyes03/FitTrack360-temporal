import 'package:flutter/material.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/templates/form_page_template.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../data/firebase_auth_service.dart';
import '../domain/auth_messages.dart';
import '../domain/auth_validators.dart';
import 'auth_navigation.dart';
import 'auth_view_models.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_link_row.dart';
import 'widgets/auth_status_banner.dart';
import 'widgets/auth_submit_button.dart';

/// Recupera tu contraseña: Firebase envía un enlace por correo.
/// No revela si el correo existe.
class ForgotPasswordPage extends StatefulWidget {
  /// Correo que el usuario ya escribió en «Inicia sesión» (vía `extra`).
  final String? initialEmail;
  final FirebaseAuthService? authService;

  const ForgotPasswordPage({super.key, this.initialEmail, this.authService});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final ForgotPasswordViewModel _viewModel = ForgotPasswordViewModel(
    auth: widget.authService,
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final FocusNode _emailFocusNode = FocusNode();
  final GlobalKey _bannerKey = GlobalKey();

  bool _emailTouched = false;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleEmailFocus);
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    final status =
        _viewModel.errorMessage ??
        (_viewModel.sent ? AuthMessages.recoverySuccess : null);
    if (status != null && status != _lastStatus) revealAuthBanner(_bannerKey);
    _lastStatus = status;
    setState(() {});
  }

  void _handleEmailFocus() {
    if (!_emailFocusNode.hasFocus && _emailController.text.trim().isNotEmpty) {
      setState(() => _emailTouched = true);
    }
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  String? get _emailError {
    if (!_emailTouched) return null;
    final email = _emailController.text.trim();
    if (email.isEmpty || AuthValidators.isValidEmail(email)) return null;
    return AuthMessages.emailFormatHint;
  }

  Future<void> _submit() async {
    setState(() => _emailTouched = true);
    await _viewModel.submit(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final error = _viewModel.errorMessage;
    final submitting = _viewModel.isSubmitting;
    return FormPageTemplate(
      header: const AuthHeader(
        title: AuthMessages.recoveryTitle,
        subtitle: AuthMessages.recoveryInstructions,
      ),
      fields: GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              label: AuthMessages.emailLabel,
              hint: AuthMessages.emailHint,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              enabled: !submitting,
            ),
            const SizedBox(height: AppSpacing.md),
            AuthSubmitButton(
              label: AuthMessages.recoverySubmit,
              loadingLabel: AuthMessages.recoverySubmitting,
              isLoading: submitting,
              onPressed: _submit,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AuthStatusBanner(key: _bannerKey, message: error),
            ] else if (_viewModel.sent) ...[
              const SizedBox(height: AppSpacing.sm),
              AuthStatusBanner(
                key: _bannerKey,
                message: AuthMessages.recoverySuccess,
                tone: AuthStatusTone.info,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: AuthTextLink(
                label: AuthMessages.backToLogin,
                onPressed: submitting ? null : () => backToLogin(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
