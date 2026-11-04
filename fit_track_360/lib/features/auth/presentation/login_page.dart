import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session_storage.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/widgets/app_background.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../../design_system/widgets/glass_surface.dart';
import '../../../design_system/widgets/primary_button.dart';
import '../data/auth_api.dart';
import '../domain/auth_validators.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final SessionStorage _sessionStorage = SessionStorage();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _submitting = false;
  bool _emailTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleEmailFocus);
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
      final tokens = await login(email: email, password: password);
      await _sessionStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: GlassSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Iniciar sesion',
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
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      DsTextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        label: 'Correo',
                        hint: 'ejemplo@correo.com',
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: 16),
                      DsTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: 'Minimo 8 caracteres',
                        obscureText: true,
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Entrar',
                        onPressed: _submitting ? null : _submit,
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
              ),
            ),
          ),
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
