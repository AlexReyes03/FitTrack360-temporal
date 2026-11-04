import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/widgets/app_background.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../../design_system/widgets/glass_surface.dart';
import '../../../design_system/widgets/primary_button.dart';
import '../data/auth_api.dart';

/// Restablecer contraseña: valida el codigo de 6 digitos contra el API y
/// actualiza la password. Al terminar regresa a login.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static final _codePattern = RegExp(r'^\d{6}$');

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _submitting = false;
  bool _confirmPasswordTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirmPasswordFocusNode.addListener(_handleConfirmPasswordFocus);
  }

  void _handleConfirmPasswordFocus() {
    if (!_confirmPasswordFocusNode.hasFocus &&
        _confirmPasswordController.text.trim().isNotEmpty) {
      setState(() => _confirmPasswordTouched = true);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String? get _confirmPasswordError {
    if (!_confirmPasswordTouched) return null;
    final confirmPassword = _confirmPasswordController.text.trim();
    if (confirmPassword.isEmpty) return null;
    return confirmPassword == _passwordController.text.trim()
        ? null
        : 'Las contraseñas no coinciden';
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _error = null;
      _confirmPasswordTouched = true;
      if (!_codePattern.hasMatch(code)) {
        _error = 'El codigo debe tener 6 digitos';
      } else if (password.length < 8) {
        _error = 'La contraseña debe tener al menos 8 caracteres';
      } else if (password != confirmPassword) {
        _error = 'Las contraseñas no coinciden';
      }
    });
    if (_error != null) return;

    setState(() => _submitting = true);
    try {
      await resetPassword(code: code, password: password);
      if (!mounted) return;
      context.go('/login');
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
                        'Restablecer contraseña',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escribe el codigo de 6 digitos y tu nueva contraseña.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      DsTextField(
                        controller: _codeController,
                        label: 'Codigo',
                        hint: '6 digitos',
                        keyboardType: TextInputType.number,
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: 16),
                      DsTextField(
                        controller: _passwordController,
                        label: 'Nueva contraseña',
                        hint: 'Minimo 8 caracteres',
                        obscureText: true,
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: 16),
                      DsTextField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        label: 'Confirmar contraseña',
                        hint: 'Repite tu contraseña',
                        obscureText: true,
                        errorText: _confirmPasswordError,
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: _submitting
                            ? 'Guardando...'
                            : 'Guardar contraseña',
                        onPressed: _submitting ? null : _submit,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _DangerBanner(message: _error!),
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
