import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/templates/form_page_template.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../notifications/presentation/notifications_scope.dart';
import '../data/firebase_auth_service.dart';
import '../domain/auth_messages.dart';
import '../domain/auth_validators.dart';
import 'auth_view_models.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_link_row.dart';
import 'widgets/auth_status_banner.dart';
import 'widgets/auth_submit_button.dart';
import 'widgets/google_sign_in_section.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onGooglePressed;
  final bool googleLoading;
  final FirebaseAuthService? authService;

  const LoginPage({
    super.key,
    this.onGooglePressed,
    this.googleLoading = false,
    this.authService,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginViewModel _viewModel = LoginViewModel(
    auth: widget.authService,
  );
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final GlobalKey _bannerKey = GlobalKey();

  bool _emailTouched = false;
  bool _didClearNotificationsOnMount = false;
  String? _lastError;

  bool get _anyGoogleLoading =>
      widget.googleLoading || _viewModel.isGoogleLoading;
  bool get _busy => _viewModel.isSubmitting || _anyGoogleLoading;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleEmailFocus);
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
    _passwordController.dispose();
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
    final ok = await _viewModel.submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (ok) _enterApp();
  }

  Future<void> _submitGoogle() async {
    if (widget.onGooglePressed != null) {
      widget.onGooglePressed!();
      return;
    }
    if (_busy) return;
    final ok = await _viewModel.submitGoogle();
    if (ok) _enterApp();
  }

  void _enterApp() {
    if (!mounted) return;
    NotificationsScope.maybeOf(context)?.clearOnLogout();
    context.go('/app');
  }

  void _openForgotPassword() {
    final email = _emailController.text.trim();
    context.push('/forgot-password', extra: email.isEmpty ? null : email);
  }

  @override
  Widget build(BuildContext context) {
    final error = _viewModel.errorMessage;
    return FormPageTemplate(
      header: const AuthHeader(
        title: AuthMessages.loginTitle,
        subtitle: AuthMessages.loginSubtitle,
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
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.sm),
            DsTextField(
              controller: _passwordController,
              label: AuthMessages.passwordLabel,
              obscureText: true,
              enabled: !_busy,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AuthTextLink(
                label: AuthMessages.forgotPasswordLink,
                onPressed: _busy ? null : _openForgotPassword,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AuthSubmitButton(
              label: AuthMessages.loginSubmit,
              loadingLabel: AuthMessages.loginSubmitting,
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
              prompt: AuthMessages.registerPrompt,
              label: AuthMessages.registerLink,
              onPressed: _busy ? null : () => context.push('/register'),
            ),
          ],
        ),
      ),
    );
  }
}
