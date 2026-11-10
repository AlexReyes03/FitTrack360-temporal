import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/notifications/unsupported_reminder_service.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/unsupported_biometric_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/app_background.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../auth/data/logout_service.dart';
import '../data/profile_api_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_validation.dart';
import '../domain/user_profile.dart';
import 'privacy_notice_page.dart';
import 'profile_view_model.dart';

/// Títulos y valores sobre el fondo oscuro: siempre `textPrimary`.
/// `AppTypography.cta` es solo para texto sobre botones claros.
final TextStyle _sectionTitle = AppTypography.body.copyWith(
  color: AppColors.textPrimary,
  fontSize: 18,
  fontWeight: FontWeight.w800,
);
const TextStyle _secondary = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 14,
);

/// Perfil (W12-12): datos, metas, preferencias, P3, O1, exportación,
/// aviso de privacidad y cierre de sesión.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.repository,
    this.reminderService,
    this.biometricService,
    this.logoutService,
    this.connectivityService,
  });

  final ProfileRepository? repository;
  final ReminderService? reminderService;
  final BiometricService? biometricService;
  final LogoutService? logoutService;
  final ConnectivityService? connectivityService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ApiClient? _ownedClient;
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  late final ProfileViewModel _vm = ProfileViewModel(
    profileRepository:
        widget.repository ?? ProfileApiRepository(_ownedClient = ApiClient()),
    reminderService:
        widget.reminderService ?? const UnsupportedReminderService(),
    biometricService:
        widget.biometricService ?? const UnsupportedBiometricService(),
    logoutService: widget.logoutService ?? LogoutService(),
  );

  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _rest = TextEditingController();
  WeightUnit _weightUnit = WeightUnit.kg;
  DistanceUnit _distanceUnit = DistanceUnit.km;
  UserProfile? _filledFrom;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onChange);
    _vm.load();
  }

  void _onChange() {
    final profile = _vm.profile;
    if (profile != null && !identical(profile, _filledFrom)) {
      _fill(profile);
    }
    if (mounted) setState(() {});
  }

  void _fill(UserProfile profile) {
    _filledFrom = profile;
    _name.text = profile.displayName;
    _calories.text = '${profile.goals.dailyCalorieGoal}';
    _protein.text = '${profile.goals.proteinGoalG}';
    _carbs.text = '${profile.goals.carbsGoalG}';
    _fat.text = '${profile.goals.fatGoalG}';
    _rest.text = '${profile.preferences.restSeconds}';
    _weightUnit = profile.preferences.weightUnit;
    _distanceUnit = profile.preferences.distanceUnit;
  }

  @override
  void dispose() {
    _vm.removeListener(_onChange);
    _vm.dispose();
    _ownedClient?.dispose();
    for (final c in [_name, _calories, _protein, _carbs, _fat, _rest]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await _vm.save(
      ProfileForm(
        displayName: _name.text,
        dailyCalorieGoal: _calories.text,
        proteinGoalG: _protein.text,
        carbsGoalG: _carbs.text,
        fatGoalG: _fat.text,
        restSeconds: _rest.text,
      ),
      weightUnit: _weightUnit,
      distanceUnit: _distanceUnit,
    );
  }

  Future<void> _export() async {
    final json = await _vm.exportData();
    if (json == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text(
          'Tus datos exportados',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            json,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await _vm.logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfflineBanner(service: _connectivity, onRetry: _vm.load),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Volver',
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/app'),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Text('Perfil', style: AppTypography.pageTitle),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _vm.state.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentWhite,
                        ),
                      ),
                      error: (_, _) => _StatusMessage(
                        text: 'No pudimos cargar tu perfil.',
                        onRetry: _vm.load,
                      ),
                      empty: () => _StatusMessage(
                        text: 'Aún no hay datos de perfil.',
                        onRetry: _vm.load,
                      ),
                      data: _content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(UserProfile profile) {
    final errors = _vm.fieldErrors;
    final prefs = profile.preferences;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                key: const Key('profile-name'),
                style: _sectionTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username} · ${profile.email}',
                style: _secondary,
              ),
              const SizedBox(height: 12),
              if (_vm.workoutCount != null)
                Text(
                  'Sesiones de entrenamiento registradas: ${_vm.workoutCount}',
                  key: const Key('profile-workout-count'),
                  style: const TextStyle(color: AppColors.textPrimary),
                )
              else
                const Text(
                  'El resumen histórico no está disponible por ahora.',
                  style: _secondary,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Metas diarias',
                key: const Key('goals-title'),
                style: _sectionTitle,
              ),
              const SizedBox(height: 4),
              Text(
                '${profile.goals.dailyCalorieGoal} kcal',
                key: const Key('goals-calories-value'),
                style: _sectionTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),
              DsTextField(
                controller: _name,
                label: 'Nombre',
                errorText: errors['displayName'],
              ),
              const SizedBox(height: 12),
              DsTextField(
                controller: _calories,
                label: 'Calorías (kcal)',
                keyboardType: TextInputType.number,
                errorText: errors['dailyCalorieGoal'],
              ),
              const SizedBox(height: 12),
              DsTextField(
                controller: _protein,
                label: 'Proteína (g)',
                keyboardType: TextInputType.number,
                errorText: errors['proteinGoalG'],
              ),
              const SizedBox(height: 12),
              DsTextField(
                controller: _carbs,
                label: 'Carbohidratos (g)',
                keyboardType: TextInputType.number,
                errorText: errors['carbsGoalG'],
              ),
              const SizedBox(height: 12),
              DsTextField(
                controller: _fat,
                label: 'Grasa (g)',
                keyboardType: TextInputType.number,
                errorText: errors['fatGoalG'],
              ),
              const SizedBox(height: 20),
              Text('Preferencias', style: _sectionTitle),
              const SizedBox(height: 12),
              DsTextField(
                controller: _rest,
                label: 'Descanso entre series (s)',
                keyboardType: TextInputType.number,
                errorText: errors['restSeconds'],
              ),
              const SizedBox(height: 12),
              _UnitRow<WeightUnit>(
                label: 'Peso',
                values: WeightUnit.values,
                selected: _weightUnit,
                onSelected: (u) => setState(() => _weightUnit = u),
              ),
              _UnitRow<DistanceUnit>(
                label: 'Distancia',
                values: DistanceUnit.values,
                selected: _distanceUnit,
                onSelected: (u) => setState(() => _distanceUnit = u),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _vm.saving ? 'Guardando...' : 'Guardar cambios',
                onPressed: _vm.saving ? null : _save,
              ),
            ],
          ),
        ),
        if (_vm.message != null) ...[
          const SizedBox(height: 16),
          Text(
            _vm.message!,
            key: const Key('profile-message'),
            style: const TextStyle(color: AppColors.warningText),
          ),
          if (_vm.showOpenSettings)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _vm.openSystemSettings,
                child: const Text(
                  'Abrir ajustes',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Notificaciones y seguridad', style: _sectionTitle),
              _Transparent(
                child: SwitchListTile(
                  key: const Key('reminder-switch'),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.accentWhite,
                  value: _vm.reminderSupported && prefs.notificationsEnabled,
                  onChanged: _vm.reminderSupported && !_vm.saving
                      ? _vm.setReminder
                      : null,
                  title: const Text(
                    'Recordatorio diario',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    _vm.reminderSupported
                        ? 'Te avisamos una vez al día para entrenar o registrar '
                              'tu comida. Te pediremos permiso al activarlo.'
                        : 'Tu dispositivo no admite recordatorios por ahora.',
                    style: _secondary,
                  ),
                ),
              ),
              if (_vm.biometricAvailable)
                _Transparent(
                  child: SwitchListTile(
                    key: const Key('biometric-switch'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.accentWhite,
                    value: prefs.biometricEnabled,
                    onChanged: _vm.saving ? null : _vm.setBiometric,
                    title: const Text(
                      'Desbloqueo con biometría',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Usa tu huella o rostro. Ningún dato biométrico sale del '
                      'dispositivo.',
                      style: _secondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tus datos', style: _sectionTitle),
              _LinkRow(
                label: 'Exportar mis datos',
                icon: Icons.download_outlined,
                onTap: _export,
              ),
              _LinkRow(
                label: 'Aviso de privacidad',
                icon: Icons.privacy_tip_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyNoticePage(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: _loggingOut ? 'Cerrando...' : 'Cerrar sesión',
          onPressed: _loggingOut ? null : _logout,
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

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
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Reintentar', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitRow<T extends Enum> extends StatelessWidget {
  const _UnitRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: _secondary)),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(value.name),
              selected: value == selected,
              onSelected: (_) => onSelected(value),
              selectedColor: AppColors.accentWhite,
              backgroundColor: AppColors.controlFillIdle,
              labelStyle: TextStyle(
                color: value == selected
                    ? AppColors.textOnAccent
                    : AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Transparent(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          label,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}

/// Material transparente para que las filas pinten su tinta sobre el vidrio.
class _Transparent extends StatelessWidget {
  const _Transparent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}
