import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../core/session_storage.dart';
import '../data/auth_api.dart';

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

  bool _privacyConsent = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
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
      } else if (!email.contains('@')) {
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
      Navigator.pop(context);
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
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Crear cuenta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Usuario',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Correo',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                hintText: 'tu@correo.com',
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _privacyConsent,
              activeColor: AppColors.accentWhite,
              checkboxShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              title: const Text(
                'Acepto el aviso de privacidad',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onChanged: (value) =>
                  setState(() => _privacyConsent = value ?? false),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentWhite,
                foregroundColor: AppColors.textOnAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Crear cuenta'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
