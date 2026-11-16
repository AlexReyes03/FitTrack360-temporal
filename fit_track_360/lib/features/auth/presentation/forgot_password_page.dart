import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/widgets/app_background.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../data/auth_api.dart';
import '../data/firebase_auth_service.dart';
import '../domain/auth_validators.dart';

/// Recuperar contraseña: Firebase envia un enlace por correo.
/// No revela si el correo existe.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _submitting = false;
  bool _sent = false;
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
    setState(() => _emailTouched = true);
    if (email.isEmpty || !AuthValidators.isValidEmail(email)) {
      setState(() => _error = 'Escribe un correo valido');
      return;
    }

    setState(() {
      _error = null;
      _sent = false;
      _submitting = true;
    });
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _sent = true);
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
                        'Recuperar contraseña',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Te enviaremos un enlace para restablecer tu contraseña.',
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
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: _submitting ? 'Enviando...' : 'Enviar enlace',
                        onPressed: _submitting ? null : _submit,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _InfoBanner(message: _error!, danger: true),
                      ],
                      if (_sent) ...[
                        const SizedBox(height: 16),
                        const _InfoBanner(
                          message: 'Si el correo existe, enviamos un enlace de recuperacion.',
                          danger: false,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text(
                          'Volver a iniciar sesion',
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

class _InfoBanner extends StatelessWidget {
  final String message;
  final bool danger;

  const _InfoBanner({required this.message, required this.danger});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      decoration: BoxDecoration(
        color: danger
            ? AppColors.dangerFill
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: danger
              ? AppColors.dangerBorder
              : Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: danger ? AppColors.dangerText : AppColors.zinc100,
          fontSize: 14,
        ),
      ),
    );
  }
}
