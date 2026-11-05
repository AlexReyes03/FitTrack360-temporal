import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session_storage.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/widgets/app_background.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../data/auth_api.dart';
import '../domain/auth_validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  final SessionStorage _sessionStorage = SessionStorage();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _privacyConsent = false;
  bool _submitting = false;
  bool _emailTouched = false;
  bool _confirmPasswordTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleEmailFocus);
    _confirmPasswordFocusNode.addListener(_handleConfirmPasswordFocus);
  }

  void _handleEmailFocus() {
    if (!_emailFocusNode.hasFocus && _emailController.text.trim().isNotEmpty) {
      setState(() => _emailTouched = true);
    }
  }

  void _handleConfirmPasswordFocus() {
    if (!_confirmPasswordFocusNode.hasFocus &&
        _confirmPasswordController.text.trim().isNotEmpty) {
      setState(() => _confirmPasswordTouched = true);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _emailFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String? get _emailError {
    if (!_emailTouched) return null;
    final email = _emailController.text.trim();
    if (email.isEmpty || AuthValidators.isValidEmail(email)) return null;
    return 'Usa el formato ejemplo@correo.com';
  }

  String? get _confirmPasswordError {
    if (!_confirmPasswordTouched) return null;
    final confirmPassword = _confirmPasswordController.text.trim();
    if (confirmPassword.isEmpty) return null;
    return confirmPassword == _passwordController.text.trim()
        ? null
        : 'Las contraseñas no coinciden';
  }

  bool get _fieldsFilled =>
      _usernameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty &&
      _confirmPasswordController.text.trim().isNotEmpty &&
      _displayNameController.text.trim().isNotEmpty;

  bool get _canSubmit => _fieldsFilled && _privacyConsent && !_submitting;

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final displayName = _displayNameController.text.trim();

    setState(() {
      _error = null;
      _emailTouched = true;
      _confirmPasswordTouched = true;
      if (username.isEmpty ||
          email.isEmpty ||
          password.isEmpty ||
          confirmPassword.isEmpty ||
          displayName.isEmpty) {
        _error = 'Completa todos los campos';
      } else if (!_usernamePattern.hasMatch(username)) {
        _error = 'El usuario solo puede tener letras, numeros y guion bajo';
      } else if (password.length < 8) {
        _error = 'La contraseña debe tener al menos 8 caracteres';
      } else if (password != confirmPassword) {
        _error = 'Las contraseñas no coinciden';
      } else if (!AuthValidators.isValidEmail(email)) {
        _error = 'Correo invalido';
      }
    });
    if (_error != null || !_privacyConsent) return;

    setState(() => _submitting = true);
    try {
      final tokens = await register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
        privacyConsent: true,
        privacyNoticeVersion: '1',
      );
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: GlassSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Crear cuenta',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Empieza a registrar tu progreso',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DsTextField(
                        controller: _displayNameController,
                        label: 'Nombre',
                        hint: 'Tu nombre completo',
                        enabled: !_submitting,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DsTextField(
                        controller: _usernameController,
                        label: 'Usuario',
                        hint: 'Solo letras, numeros y guion bajo',
                        enabled: !_submitting,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DsTextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        label: 'Correo',
                        hint: 'ejemplo@correo.com',
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        enabled: !_submitting,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DsTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: 'Minimo 8 caracteres',
                        obscureText: true,
                        enabled: !_submitting,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DsTextField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        label: 'Confirmar contraseña',
                        hint: 'Repite tu contraseña',
                        obscureText: true,
                        errorText: _confirmPasswordError,
                        enabled: !_submitting,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _PrivacyCheckbox(
                        value: _privacyConsent,
                        onChanged: _submitting
                            ? null
                            : (value) =>
                                  setState(() => _privacyConsent = value),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Crear cuenta',
                        onPressed: _canSubmit ? _submit : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _DangerBanner(message: _error!),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text(
                          'Ya tienes cuenta? Iniciar sesion',
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

class _PrivacyCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PrivacyCheckbox({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.35,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value
                      ? AppColors.accentWhite
                      : AppColors.controlFillIdle,
                  borderRadius: BorderRadius.circular(6.4),
                  border: Border.all(
                    width: 1.5,
                    color: value
                        ? AppColors.accentWhite
                        : Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check,
                        size: 14.4,
                        color: AppColors.textOnAccent,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Acepto el aviso de privacidad',
                style: TextStyle(color: AppColors.zinc200, fontSize: 15.5),
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
