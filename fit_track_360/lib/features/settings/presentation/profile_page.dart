import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/notifications/local_reminder_service.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/local_biometric_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/remote_state_views.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/app_background.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../auth/data/logout_service.dart';
import '../../home/presentation/widgets/home_navigation_shell.dart';
import '../../notifications/data/push_device_lifecycle_service.dart';
import '../../notifications/presentation/notifications_scope.dart';
import '../../notifications/presentation/push_device_scope.dart';
import '../data/profile_api_repository.dart';
import '../data/share_plus_export_sharer.dart';
import '../domain/export_sharer.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_validation.dart';
import '../domain/user_profile.dart';
import 'privacy_notice_page.dart';
import 'profile_view_model.dart';
import 'widgets/profile_controls.dart';

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

/// Perfil (W12-12, UX-11): datos, metas, preferencias, P3, O1, exportación,
/// aviso de privacidad, eliminación de cuenta y cierre de sesión.
///
/// Regla de guardado: el formulario (nombre, metas y descanso) se guarda con
/// «Guardar cambios»; unidades e interruptores se guardan al tocarlos.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.repository,
    this.reminderService,
    this.biometricService,
    this.logoutService,
    this.connectivityService,
    this.exportSharer,
    this.pushDeviceService,
  });

  final ProfileRepository? repository;
  final ReminderService? reminderService;
  final BiometricService? biometricService;
  final LogoutService? logoutService;
  final ConnectivityService? connectivityService;
  final ExportSharer? exportSharer;
  final PushDeviceLifecycle? pushDeviceService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ApiClient? _ownedClient;
  PushDeviceLifecycle? _ownedPushDeviceService;
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  late final ProfileViewModel _vm;
  bool _initialized = false;
  final _exportKey = GlobalKey();

  ApiClient _ensureOwnedClient() => _ownedClient ??= ApiClient();

  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _rest = TextEditingController();
  UserProfile? _filledFrom;
  bool _loggingOut = false;
  bool _redirectingToLogin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final pushDeviceService =
        widget.pushDeviceService ??
        PushDeviceScope.maybeOf(context) ??
        (_ownedPushDeviceService = PushDeviceLifecycleService.fromClient(
          _ensureOwnedClient(),
        ));
    _vm = ProfileViewModel(
      profileRepository:
          widget.repository ?? ProfileApiRepository(_ensureOwnedClient()),
      reminderService: widget.reminderService ?? LocalReminderService(),
      biometricService: widget.biometricService ?? LocalBiometricService(),
      logoutService:
          widget.logoutService ??
          LogoutService(pushDeviceService: pushDeviceService),
      exportSharer: widget.exportSharer ?? SharePlusExportSharer(),
      pushDeviceService: pushDeviceService,
    );
    unawaited(_vm.load());
    _vm.addListener(_onChange);
  }

  void _onChange() {
    if (_vm.sessionExpired) {
      _goToLogin();
      return;
    }
    final profile = _vm.profile;
    if (profile != null && _formChanged(_filledFrom, profile)) {
      _fill(profile);
    }
    if (mounted) setState(() {});
  }

  /// Una preferencia guardada al instante no debe borrar lo que el usuario
  /// lleva escrito en el formulario.
  bool _formChanged(UserProfile? before, UserProfile after) =>
      before == null ||
      before.displayName != after.displayName ||
      before.goals != after.goals ||
      before.preferences.restSeconds != after.preferences.restSeconds;

  void _fill(UserProfile profile) {
    _filledFrom = profile;
    _name.text = profile.displayName;
    _calories.text = '${profile.goals.dailyCalorieGoal}';
    _protein.text = '${profile.goals.proteinGoalG}';
    _carbs.text = '${profile.goals.carbsGoalG}';
    _fat.text = '${profile.goals.fatGoalG}';
    _rest.text = '${profile.preferences.restSeconds}';
  }

  /// Igual que Inicio: una sesión rechazada por el API vuelve a `/login`.
  void _goToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    context.go('/login');
  }

  @override
  void dispose() {
    if (_initialized) {
      _vm.removeListener(_onChange);
      _vm.dispose();
    }
    final ownedPush = _ownedPushDeviceService;
    if (ownedPush != null) {
      unawaited(ownedPush.dispose());
    }
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
    );
  }

  /// Comparte el archivo; si el plugin falla, muestra el JSON para copiarlo.
  Future<void> _export() async {
    final json = await _vm.exportData(origin: _exportOrigin());
    if (json == null || !mounted) return;
    await showProfileGlassDialog<void>(
      context: context,
      builder: (context) => _ExportFallbackDialog(json: json),
    );
  }

  /// Confirmación destructiva antes de eliminar la cuenta.
  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showProfileGlassDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await _vm.deleteAccount();
    if (!deleted || !mounted) return;
    NotificationsScope.maybeOf(context)?.clearOnLogout();
    _goToLogin();
  }

  /// Rectángulo global de la fila «Exportar mis datos» (ancla en iPad).
  Rect? _exportOrigin() {
    final box = _exportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await _vm.logout();
    if (!mounted) return;
    NotificationsScope.maybeOf(context)?.clearOnLogout();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final embedded = HomeNavigationShell.isEmbedded(context);
    final showBack = !embedded || context.canPop();
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OfflineBanner(service: _connectivity, onRetry: _vm.load),
            Padding(
              padding: EdgeInsets.fromLTRB(
                showBack ? 8 : 24,
                embedded ? 12 : 8,
                24,
                0,
              ),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/app'),
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
              // Con datos, el contenido trae su propio scroll; carga, error y
              // vacío usan las vistas remotas del DS dentro de una lista.
              child: _vm.profile != null
                  ? _content(_vm.profile!, embedded: embedded)
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        AsyncStateView<UserProfile>(
                          state: _vm.state,
                          loadingMessage: 'Cargando tu perfil...',
                          errorTitle: 'No pudimos cargar tu perfil.',
                          errorMessage:
                              'Revisa tu conexión e intenta de nuevo.',
                          onRetry: _vm.load,
                          emptyTitle: 'Aún no hay datos de perfil.',
                          emptyMessage: 'Intenta cargarlo de nuevo.',
                          emptyIcon: Icons.person_outline_rounded,
                          emptyActionLabel: 'Reintentar',
                          onEmptyAction: _vm.load,
                          dataBuilder: (_) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: embedded ? content : AppBackground(child: SafeArea(child: content)),
    );
  }

  Widget _content(UserProfile profile, {required bool embedded}) {
    final errors = _vm.fieldErrors;
    final prefs = profile.preferences;
    final formFeedback = _vm.formFeedback;
    final preferencesFeedback = _vm.preferencesFeedback;
    final dataFeedback = _vm.dataFeedback;
    final prefsBusy = _vm.updatingPreferences || _vm.savingForm;
    return ListView(
      padding: EdgeInsets.fromLTRB(24, embedded ? 12 : 24, 24, 32),
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
              const SizedBox(height: 4),
              const Text(
                'Edita tus datos y pulsa «Guardar cambios».',
                style: _secondary,
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
              const SizedBox(height: 12),
              DsTextField(
                controller: _rest,
                label: 'Descanso entre series (s)',
                keyboardType: TextInputType.number,
                errorText: errors['restSeconds'],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _vm.savingForm ? 'Guardando...' : 'Guardar cambios',
                onPressed: _vm.savingForm || _vm.updatingPreferences
                    ? null
                    : _save,
              ),
              if (formFeedback != null)
                ProfileFeedbackBanner(
                  key: const Key('profile-form-feedback'),
                  feedback: formFeedback,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Preferencias', style: _sectionTitle),
              const SizedBox(height: 4),
              const Text(
                'Estos ajustes se guardan en cuanto los cambias.',
                style: _secondary,
              ),
              const SizedBox(height: 8),
              ProfileSegmentedSelector<WeightUnit>(
                key: const Key('weight-unit-selector'),
                label: 'Unidad de peso',
                values: WeightUnit.values,
                selected: prefs.weightUnit,
                labelOf: (unit) => unit.label,
                onSelected: prefsBusy ? null : _vm.setWeightUnit,
              ),
              ProfileSegmentedSelector<DistanceUnit>(
                key: const Key('distance-unit-selector'),
                label: 'Unidad de distancia',
                values: DistanceUnit.values,
                selected: prefs.distanceUnit,
                labelOf: (unit) => unit.label,
                onSelected: prefsBusy ? null : _vm.setDistanceUnit,
              ),
              const SizedBox(height: 4),
              ProfileSwitchRow(
                key: const Key('reminder-switch'),
                title: 'Recordatorio diario',
                subtitle: _vm.reminderSupported
                    ? 'Te avisamos una vez al día para entrenar o registrar '
                          'tu comida. Te pediremos permiso al activarlo.'
                    : 'Tu dispositivo no admite recordatorios por ahora.',
                value: _vm.reminderSupported && prefs.notificationsEnabled,
                onChanged: _vm.reminderSupported && !prefsBusy
                    ? _vm.setReminder
                    : null,
              ),
              if (_vm.biometricAvailable)
                ProfileSwitchRow(
                  key: const Key('biometric-switch'),
                  title: 'Desbloqueo con biometría',
                  subtitle:
                      'Usa tu huella o rostro. Ningún dato biométrico sale del '
                      'dispositivo.',
                  value: prefs.biometricEnabled,
                  onChanged: prefsBusy ? null : _vm.setBiometric,
                ),
              if (preferencesFeedback != null)
                ProfileFeedbackBanner(
                  key: const Key('profile-preferences-feedback'),
                  feedback: preferencesFeedback,
                  action: _vm.showOpenSettings
                      ? ProfileGlassButton(
                          label: 'Abrir ajustes',
                          onPressed: _vm.openSystemSettings,
                        )
                      : null,
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
              KeyedSubtree(
                key: _exportKey,
                child: ProfileActionRow(
                  label: _vm.exporting ? 'Exportando...' : 'Exportar mis datos',
                  icon: Icons.ios_share,
                  busy: _vm.exporting,
                  onTap: _export,
                ),
              ),
              ProfileActionRow(
                label: 'Aviso de privacidad',
                icon: Icons.privacy_tip_outlined,
                // TODO(#230): usar la ruta `/aviso-privacidad` cuando exista.
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyNoticePage(),
                  ),
                ),
              ),
              ProfileActionRow(
                key: const Key('delete-account-row'),
                label: _vm.deletingAccount
                    ? 'Eliminando...'
                    : 'Eliminar mi cuenta',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                busy: _vm.deletingAccount,
                onTap: _confirmDeleteAccount,
              ),
              if (dataFeedback != null)
                ProfileFeedbackBanner(
                  key: const Key('profile-data-feedback'),
                  feedback: dataFeedback,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          key: const Key('profile-logout-button'),
          label: _loggingOut ? 'Cerrando...' : 'Cerrar sesión',
          variant: PrimaryButtonVariant.destructive,
          onPressed: _loggingOut ? null : _logout,
        ),
      ],
    );
  }
}

/// Respaldo cuando la hoja de compartir no abre: JSON seleccionable y
/// botón «Copiar» al portapapeles.
class _ExportFallbackDialog extends StatefulWidget {
  const _ExportFallbackDialog({required this.json});

  final String json;

  @override
  State<_ExportFallbackDialog> createState() => _ExportFallbackDialogState();
}

class _ExportFallbackDialogState extends State<_ExportFallbackDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.json));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tus datos exportados', style: _sectionTitle),
        const SizedBox(height: 6),
        const Text(
          'Copia este texto y guárdalo donde prefieras.',
          style: _secondary,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB807080C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.json,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          key: const Key('export-copy-button'),
          label: _copied ? 'Copiado' : 'Copiar',
          onPressed: _copy,
        ),
        const SizedBox(height: 10),
        ProfileGlassButton(
          label: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Confirmación destructiva: devuelve true solo si el usuario confirma.
class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Eliminar tu cuenta?', style: _sectionTitle),
        const SizedBox(height: 8),
        const Text(
          'Borraremos tu perfil, entrenamientos, rutinas, comidas, medidas y '
          'fotos. No podrás recuperarlos. Si quieres conservar una copia, '
          'exporta tus datos antes.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          key: const Key('delete-account-confirm'),
          label: 'Sí, eliminar mi cuenta',
          variant: PrimaryButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 10),
        ProfileGlassButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
