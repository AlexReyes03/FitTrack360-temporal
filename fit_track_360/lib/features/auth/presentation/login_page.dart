import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/app_logo.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/form_page_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../notifications/presentation/notifications_scope.dart';
import '../data/auth_api.dart';
import '../data/firebase_auth_service.dart';
import '../data/google_auth_gateway.dart';
import '../domain/auth_validators.dart';
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
  late final FirebaseAuthService _auth =
      widget.authService ?? FirebaseAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _submitting = false;
  bool _googleLoading = false;
  bool _emailTouched = false;
  bool _didClearNotificationsOnMount = false;
  String? _error;

  bool get _anyGoogleLoading => widget.googleLoading || _googleLoading;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleEmailFocus);
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

  void _handleEmailFocus() {
    if (!_emailFocusNode.hasFocus && _emailController.text.trim().isNotEmpty) {
      setState(() => _emailTouched = true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  String? get _emailError {
    if (!_emailTouched) return null;
    final email = _emailController.text.trim();
    if (email.isEmpty || AuthValidators.isValidEmail(email)) return null;
    return 'Usa el formato ejemplo@correo.com';
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _error = null;
      _emailTouched = true;
      if (email.isEmpty || password.isEmpty) {
        _error = 'Completa todos los campos';
      } else if (!AuthValidators.isValidEmail(email)) {
        _error = 'Correo invalido';
      }
    });
    if (_error != null) return;

    setState(() => _submitting = true);
    try {
      await _auth.login(email: email, password: password);
      if (!mounted) return;
      NotificationsScope.maybeOf(context)?.clearOnLogout();
      context.go('/app');
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo conectar');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    if (widget.onGooglePressed != null) {
      widget.onGooglePressed!();
      return;
    }
    if (_submitting || _anyGoogleLoading) return;

    setState(() {
      _error = null;
      _googleLoading = true;
    });
    try {
      await _auth.loginWithGoogle(allowAutoRegister: false);
      if (!mounted) return;
      NotificationsScope.maybeOf(context)?.clearOnLogout();
      context.go('/app');
    } on GoogleSignInCancelledException {
      // Cancelar deja la pantalla de login sin error fatal.
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo conectar');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPageTemplate(
      fields: GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: AppLogo(
                variant: AppLogoVariant.mark,
                height: AppLogo.loginHeight,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Iniciar sesion',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bienvenido de vuelta',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            DsTextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              label: 'Correo',
              hint: 'ejemplo@correo.com',
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              enabled: !_submitting && !_anyGoogleLoading,
            ),
            const SizedBox(height: 16),
            DsTextField(
              controller: _passwordController,
              label: 'Contraseña',
              hint: 'Minimo 8 caracteres',
              obscureText: true,
              enabled: !_submitting && !_anyGoogleLoading,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Entrar',
              onPressed: (_submitting || _anyGoogleLoading) ? null : _submit,
            ),
            const SizedBox(height: 16),
            GoogleAuthSection(
              onGooglePressed: _submitGoogle,
              isLoading: _anyGoogleLoading,
              enabled: !_submitting,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _DangerBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: const Text(
                'Olvidaste tu contraseña?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text(
                'No tienes cuenta? Crear cuenta',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerBanner extends StatelessWidget {
  final String message;

  const _DangerBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.dangerFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.dangerText, fontSize: 14),
      ),
    );
  }
}
