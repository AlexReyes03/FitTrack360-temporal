import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/security/biometric_service.dart';
import '../../auth/data/logout_service.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_validation.dart';
import '../domain/user_profile.dart';

/// Textos de P3 según `docs/permisos.md` («Si se niega»).
const reminderDeniedMessage =
    'Sin permiso no podemos enviarte el recordatorio. La app sigue '
    'funcionando y te lo mostraremos al abrirla.';
const reminderPermanentlyDeniedMessage =
    'Las notificaciones están apagadas en el sistema. Actívalas en los '
    'ajustes para recibir el recordatorio.';
const biometricFailedMessage =
    'No se pudo verificar tu identidad. El desbloqueo con biometría sigue '
    'desactivado; puedes usar tu contraseña.';
const exportUnavailableMessage =
    'La exportación aún no está disponible. Intenta más tarde.';
const saveFailedMessage =
    'No se pudieron guardar los cambios. Intenta de nuevo.';

/// Hora local del recordatorio diario (P3, programación inexacta).
const reminderHour = 20;
const reminderMinute = 0;

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required ProfileRepository profileRepository,
    required ReminderService reminderService,
    required BiometricService biometricService,
    required LogoutService logoutService,
  }) : _repository = profileRepository,
       _reminders = reminderService,
       _biometrics = biometricService,
       _logout = logoutService;

  final ProfileRepository _repository;
  final ReminderService _reminders;
  final BiometricService _biometrics;
  final LogoutService _logout;

  AsyncState<UserProfile> state = const AsyncLoading();
  int? workoutCount;
  bool reminderSupported = false;
  bool biometricAvailable = false;
  bool saving = false;
  Map<String, String> fieldErrors = const {};

  /// Aviso no bloqueante (éxito o fallo) para mostrar en la vista.
  String? message;

  /// true cuando el permiso de P3 quedó denegado permanentemente.
  bool showOpenSettings = false;

  bool _disposed = false;

  UserProfile? get profile => state.dataOrNull;

  Future<void> load() async {
    state = const AsyncLoading();
    _notify();
    try {
      final result = await _repository.fetchProfile();
      state = AsyncState.fromData(result);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
    reminderSupported = await _safe(_reminders.isSupported);
    biometricAvailable = await _safe(_biometrics.isAvailable);
    try {
      workoutCount = await _repository.countWorkouts();
    } catch (_) {
      workoutCount = null; // El resumen se omite si el API no responde.
    }
    _notify();
  }

  Future<bool> _safe(Future<bool> Function() check) async {
    try {
      return await check();
    } catch (_) {
      return false;
    }
  }

  /// Valida en cliente y, si pasa, envía nombre, metas y preferencias.
  Future<bool> save(
    ProfileForm form, {
    required WeightUnit weightUnit,
    required DistanceUnit distanceUnit,
  }) async {
    final current = profile;
    if (current == null) return false;
    final result = validateProfileForm(form);
    fieldErrors = result.errors;
    message = null;
    if (!result.isValid) {
      _notify();
      return false;
    }
    final saved = await _update(
      ProfileUpdate(
        displayName: result.displayName,
        goals: result.goals,
        preferences: current.preferences.copyWith(
          weightUnit: weightUnit,
          distanceUnit: distanceUnit,
          restSeconds: result.restSeconds,
        ),
      ),
    );
    if (saved) message = 'Cambios guardados.';
    _notify();
    return saved;
  }

  Future<bool> _update(ProfileUpdate update) async {
    saving = true;
    _notify();
    try {
      final updated = await _repository.updateProfile(update);
      state = AsyncData(updated);
      return true;
    } catch (_) {
      message = saveFailedMessage;
      return false;
    } finally {
      saving = false;
    }
  }

  /// P3: pedir permiso al activar; revertir si se niega.
  Future<void> setReminder(bool enabled) async {
    final current = profile;
    if (current == null || !reminderSupported) return;
    message = null;
    showOpenSettings = false;
    if (!enabled) {
      await _reminders.cancel();
      await _update(
        ProfileUpdate(
          preferences: current.preferences.copyWith(
            notificationsEnabled: false,
          ),
        ),
      );
      _notify();
      return;
    }
    final permission = await _reminders.requestPermission();
    switch (permission) {
      case ReminderPermission.granted:
        await _reminders.scheduleDaily(
          hour: reminderHour,
          minute: reminderMinute,
        );
        await _update(
          ProfileUpdate(
            preferences: current.preferences.copyWith(
              notificationsEnabled: true,
            ),
          ),
        );
      case ReminderPermission.denied:
        message = reminderDeniedMessage;
      case ReminderPermission.permanentlyDenied:
        message = reminderPermanentlyDeniedMessage;
        showOpenSettings = true;
    }
    _notify();
  }

  Future<void> openSystemSettings() => _reminders.openSystemSettings();

  /// O1: exige autenticar antes de activar; desactivar no la pide.
  Future<void> setBiometric(bool enabled) async {
    final current = profile;
    if (current == null || !biometricAvailable) return;
    message = null;
    if (enabled) {
      var ok = false;
      try {
        ok = await _biometrics.authenticate(
          reason: 'Confirma tu identidad para activar el desbloqueo.',
        );
      } catch (_) {
        ok = false;
      }
      if (!ok) {
        message = biometricFailedMessage;
        _notify();
        return;
      }
    }
    await _update(
      ProfileUpdate(
        preferences: current.preferences.copyWith(biometricEnabled: enabled),
      ),
    );
    _notify();
  }

  /// Devuelve el JSON exportado, o null si la exportación no está disponible.
  Future<String?> exportData() async {
    message = null;
    try {
      return await _repository.exportData();
    } catch (_) {
      message = exportUnavailableMessage;
      _notify();
      return null;
    }
  }

  Future<void> logout() => _logout.logout();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
