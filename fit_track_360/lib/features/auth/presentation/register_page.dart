import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/templates/form_page_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../notifications/presentation/notifications_scope.dart';
import '../data/firebase_auth_service.dart';
import '../domain/auth_messages.dart';
import '../domain/auth_validators.dart';
import 'auth_navigation.dart';
import 'auth_view_models.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_link_row.dart';
import 'widgets/auth_status_banner.dart';
import 'widgets/auth_submit_button.dart';
import 'widgets/google_sign_in_section.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback? onGooglePressed;
  final bool googleLoading;
  final FirebaseAuthService? authService;

  const RegisterPage({
    super.key,
    this.onGooglePressed,
    this.googleLoading = false,
    this.authService,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final RegisterViewModel _viewModel = RegisterViewModel(
    auth: widget.authService,
  );
  final Map<RegisterField, TextEditingController> _controllers = {
    for (final field in RegisterField.values) field: TextEditingController(),
  };
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final GlobalKey _bannerKey = GlobalKey();

  bool _emailTouched = false;
  bool _confirmPasswordTouched = false;
  bool _didClearNotificationsOnMount = false;
  String? _lastError;

  bool get _anyGoogleLoading =>
      widget.googleLoading || _viewModel.isGoogleLoading;
  bool get _busy => _viewModel.isSubmitting || _anyGoogleLoading;

  TextEditingController _controller(RegisterField field) =>
      _controllers[field]!;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleEmailFocus);
    _confirmPasswordFocusNode.addListener(_handleConfirmPasswordFocus);
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didClearNotificationsOnMount) return;
    _didClearNotificationsOnMount = true;
    final notifications = NotificationsScope.maybeOf(context);
    if (notifications != null) {
      scheduleMicrotask(() {
        if (mounted) notifications.clearOnLogout();
      });
    }
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    final error = _viewModel.errorMessage;
    if (error != null && error != _lastError) revealAuthBanner(_bannerKey);
    _lastError = error;
    setState(() {});
  }

  void _handleEmailFocus() {
    if (!_emailFocusNode.hasFocus &&
        _controller(RegisterField.email).text.trim().isNotEmpty) {
      setState(() => _emailTouched = true);
    }
  }

  void _handleConfirmPasswordFocus() {
    if (!_confirmPasswordFocusNode.hasFocus &&
        _controller(RegisterField.confirmPassword).text.isNotEmpty) {
      setState(() => _confirmPasswordTouched = true);
    }
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _emailFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String? _fieldError(RegisterField field) {
    if (_viewModel.missingFields.contains(field)) {
      return AuthMessages.requiredField;
    }
    switch (field) {
      case RegisterField.email:
        if (!_emailTouched) return null;
        final email = _controller(field).text.trim();
        if (email.isEmpty || AuthValidators.isValidEmail(email)) return null;
        return AuthMessages.emailFormatHint;
      case RegisterField.confirmPassword:
        if (!_confirmPasswordTouched) return null;
        final confirm = _controller(field).text;
        if (confirm.isEmpty) return null;
        return confirm == _controller(RegisterField.password).text
            ? null
            : AuthMessages.passwordMismatch;
      default:
        return null;
    }
  }

  RegisterForm get _form => RegisterForm(
    displayName: _controller(RegisterField.displayName).text,
    username: _controller(RegisterField.username).text,
    email: _controller(RegisterField.email).text,
    password: _controller(RegisterField.password).text,
    confirmPassword: _controller(RegisterField.confirmPassword).text,
  );

  Future<void> _submit() async {
    setState(() {
      _emailTouched = true;
      _confirmPasswordTouched = true;
    });
    final ok = await _viewModel.submit(_form);
    if (ok) _enterApp();
  }

  Future<void> _submitGoogle() async {
    if (widget.onGooglePressed != null) {
      widget.onGooglePressed!();
      return;
    }
    final ok = await _viewModel.submitGoogle();
    if (ok) _enterApp();
  }

  void _enterApp() {
    if (!mounted) return;
    NotificationsScope.maybeOf(context)?.clearOnLogout();
    context.go('/app');
  }

  Widget _field(
    RegisterField field, {
    required String label,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    FocusNode? focusNode,
  }) {
    return DsTextField(
      controller: _controller(field),
      focusNode: focusNode,
      label: label,
      hint: hint,
      obscureText: obscureText,
      keyboardType: keyboardType,
      errorText: _fieldError(field),
      enabled: !_busy,
      onChanged: (value) => _viewModel.fieldChanged(field, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _viewModel.errorMessage;
    return FormPageTemplate(
      header: const AuthHeader(
        title: AuthMessages.registerTitle,
        subtitle: AuthMessages.registerSubtitle,
      ),
      fields: GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              RegisterField.displayName,
              label: AuthMessages.nameLabel,
              hint: AuthMessages.nameHint,
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              RegisterField.username,
              label: AuthMessages.usernameLabel,
              hint: AuthMessages.usernameHint,
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              RegisterField.email,
              label: AuthMessages.emailLabel,
              hint: AuthMessages.emailHint,
              keyboardType: TextInputType.emailAddress,
              focusNode: _emailFocusNode,
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              RegisterField.password,
              label: AuthMessages.passwordLabel,
              hint: AuthMessages.passwordHint,
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _field(
              RegisterField.confirmPassword,
              label: AuthMessages.confirmPasswordLabel,
              hint: AuthMessages.confirmPasswordHint,
              obscureText: true,
              focusNode: _confirmPasswordFocusNode,
            ),
            const SizedBox(height: AppSpacing.xs),
            _PrivacyConsentCheckbox(
              value: _viewModel.privacyConsent,
              showError: _viewModel.consentMissing,
              onChanged: _busy ? null : _viewModel.setPrivacyConsent,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AuthTextLink(
                label: AuthMessages.privacyNoticeLink,
                onPressed: () => context.push(appPrivacyNoticePath),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AuthSubmitButton(
              label: AuthMessages.registerSubmit,
              loadingLabel: AuthMessages.registerSubmitting,
              isLoading: _viewModel.isSubmitting,
              onPressed: _anyGoogleLoading ? null : _submit,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AuthStatusBanner(key: _bannerKey, message: error),
            ],
            const SizedBox(height: AppSpacing.md),
            GoogleAuthSection(
              onGooglePressed: _submitGoogle,
              isLoading: _anyGoogleLoading,
              enabled: !_viewModel.isSubmitting,
            ),
            const SizedBox(height: AppSpacing.sm),
            AuthLinkRow(
              prompt: AuthMessages.loginPrompt,
              label: AuthMessages.loginLink,
              onPressed: _busy ? null : () => backToLogin(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Casilla del aviso de privacidad: expone `checked` a lectores de pantalla y
/// toda la fila mide al menos 48dp de alto.
class _PrivacyConsentCheckbox extends StatelessWidget {
  final bool value;
  final bool showError;
  final ValueChanged<bool>? onChanged;

  const _PrivacyConsentCheckbox({
    required this.value,
    required this.showError,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final borderColor = value
        ? AppColors.accentWhite
        : showError
        ? AppColors.dangerBorder
        : AppColors.glassBorderStrong;

    return Semantics(
      container: true,
      checked: value,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.option),
        onTap: enabled ? () => onChanged!(!value) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              children: [
                Opacity(
                  opacity: enabled ? 1 : 0.35,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: value
                          ? AppColors.accentWhite
                          : AppColors.controlFillIdle,
                      borderRadius: BorderRadius.circular(AppRadii.checkbox),
                      border: Border.all(width: 1.5, color: borderColor),
                    ),
                    child: value
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: AppColors.textOnAccent,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    AuthMessages.privacyConsentLabel,
                    style: AppTypography.body.copyWith(
                      color: AppColors.zinc200,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
