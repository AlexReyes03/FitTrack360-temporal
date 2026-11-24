import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart' show SessionExpiredException;
import '../../../core/notifications/reminder_service.dart';
import '../../../core/security/biometric_service.dart';
import '../../auth/data/logout_service.dart';
import '../../notifications/data/push_device_lifecycle_service.dart';
import '../domain/export_sharer.dart';
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
const exportShareFailedMessage =
    'No se pudo abrir el menú para compartir. Copia tus datos desde la '
    'ventana que abrimos.';
const saveFailedMessage =
    'No se pudieron guardar los cambios. Intenta de nuevo.';
const formSavedMessage = 'Cambios guardados.';
const preferenceSavedMessage = 'Preferencia guardada.';
const preferenceFailedMessage =
    'No se pudo guardar la preferencia. Intenta de nuevo.';
const accountDeletionFailedMessage =
    'No pudimos eliminar tu cuenta. Revisa tu conexión e intenta de nuevo.';

/// Tono del aviso: éxito (neutro con palomita), aviso (ámbar) o error (rojo).
enum ProfileFeedbackKind { success, warning, error }

/// Aviso no bloqueante que la vista muestra junto a la acción que lo causó.
class ProfileFeedback {
  const ProfileFeedback(this.text, this.kind);

  const ProfileFeedback.success(this.text) : kind = ProfileFeedbackKind.success;
  const ProfileFeedback.warning(this.text) : kind = ProfileFeedbackKind.warning;
  const ProfileFeedback.error(this.text) : kind = ProfileFeedbackKind.error;

  final String text;
  final ProfileFeedbackKind kind;
}

/// Hora local del recordatorio diario (P3, programación inexacta).
const reminderHour = 20;
const reminderMinute = 0;

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required ProfileRepository profileRepository,
    required ReminderService reminderService,
    required BiometricService biometricService,
    required LogoutService logoutService,
    required ExportSharer exportSharer,
    PushDeviceLifecycle? pushDeviceService,
    DateTime Function()? clock,
  }) : _repository = profileRepository,
       _reminders = reminderService,
       _biometrics = biometricService,
       _logout = logoutService,
       _sharer = exportSharer,
       _pushLifecycle = pushDeviceService,
       _clock = clock ?? DateTime.now;

  final ProfileRepository _repository;
  final ReminderService _reminders;
  final BiometricService _biometrics;
  final LogoutService _logout;
  final ExportSharer _sharer;
  final PushDeviceLifecycle? _pushLifecycle;
  final DateTime Function() _clock;

  AsyncState<UserProfile> state = const AsyncLoading();

  /// Resumen histórico del último GET; el PATCH no lo trae y no lo borra.
  int? workoutCount;
  bool reminderSupported = false;
  bool biometricAvailable = false;
  Map<String, String> fieldErrors = const {};

  /// Regla de guardado: el formulario (nombre, metas y descanso) se guarda
  /// con «Guardar cambios»; unidades e interruptores, al instante.
  bool savingForm = false;
  bool updatingPreferences = false;
  bool exporting = false;
  bool deletingAccount = false;

  /// El API rechazó la sesión: la vista debe volver a `/login`.
  bool sessionExpired = false;

  /// Avisos por sección, para mostrarlos junto a su acción.
  ProfileFeedback? formFeedback;
  ProfileFeedback? preferencesFeedback;
  ProfileFeedback? dataFeedback;
  ProfileFeedback? _lastFeedback;

  /// Texto del aviso más reciente, de cualquier sección.
  String? get message => _lastFeedback?.text;

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
      workoutCount = result?.workoutCount;
      if (result != null && result.preferences.notificationsEnabled) {
        unawaited(_syncPush(notificationsEnabled: true));
      }
    } on SessionExpiredException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      workoutCount = null;
      sessionExpired = true;
      _notify();
      return;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      workoutCount = null; // El resumen se omite si el API no responde.
    }
    reminderSupported = await _safe(_reminders.isSupported);
    biometricAvailable = await _safe(_biometrics.isAvailable);
    _notify();
  }

  Future<bool> _safe(Future<bool> Function() check) async {
    try {
      return await check();
    } catch (_) {
      return false;
    }
  }

  /// Valida en cliente y, si pasa, envía nombre, metas y descanso. Las
  /// unidades no viajan desde aquí: se guardan al tocarlas.
  Future<bool> save(ProfileForm form) async {
    final current = profile;
    if (current == null || savingForm) return false;
    final result = validateProfileForm(form);
    fieldErrors = result.errors;
    _setFeedback(form: null);
    if (!result.isValid) {
      _notify();
      return false;
    }
    savingForm = true;
    _notify();
    final error = await _patch(
      ProfileUpdate(
        displayName: result.displayName,
        goals: result.goals,
        preferences: current.preferences.copyWith(
          restSeconds: result.restSeconds,
        ),
      ),
    );
    savingForm = false;
    if (error == _PatchResult.ok) {
      _setFeedback(form: const ProfileFeedback.success(formSavedMessage));
    } else if (error == _PatchResult.failed) {
      _setFeedback(form: const ProfileFeedback.error(saveFailedMessage));
    }
    _notify();
    return error == _PatchResult.ok;
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    final current = profile;
    if (current == null || current.preferences.weightUnit == unit) return;
    await _savePreferences(current.preferences.copyWith(weightUnit: unit));
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    final current = profile;
    if (current == null || current.preferences.distanceUnit == unit) return;
    await _savePreferences(current.preferences.copyWith(distanceUnit: unit));
  }

  /// Guarda una preferencia al instante y avisa en su sección.
  Future<bool> _savePreferences(UserPreferences preferences) async {
    if (updatingPreferences) return false;
    _setFeedback(preferences: null);
    updatingPreferences = true;
    _notify();
    final result = await _patch(ProfileUpdate(preferences: preferences));
    updatingPreferences = false;
    if (result == _PatchResult.ok) {
      _setFeedback(
        preferences: const ProfileFeedback.success(preferenceSavedMessage),
      );
    } else if (result == _PatchResult.failed) {
      _setFeedback(
        preferences: const ProfileFeedback.error(preferenceFailedMessage),
      );
    }
    _notify();
    return result == _PatchResult.ok;
  }

  Future<_PatchResult> _patch(ProfileUpdate update) async {
    try {
      final updated = await _repository.updateProfile(update);
      state = AsyncData(updated);
      return _PatchResult.ok;
    } on SessionExpiredException {
      sessionExpired = true;
      return _PatchResult.sessionExpired;
    } catch (_) {
      return _PatchResult.failed;
    }
  }

  /// Reemplaza el aviso de cada sección indicada; el resto queda igual.
  void _setFeedback({
    Object? form = _keep,
    Object? preferences = _keep,
    Object? data = _keep,
  }) {
    ProfileFeedback? apply(Object? next, ProfileFeedback? previous) {
      if (identical(next, _keep)) return previous;
      if (next == null && identical(_lastFeedback, previous)) {
        _lastFeedback = null;
      }
      if (next != null) _lastFeedback = next as ProfileFeedback;
      return next as ProfileFeedback?;
    }

    formFeedback = apply(form, formFeedback);
    preferencesFeedback = apply(preferences, preferencesFeedback);
    dataFeedback = apply(data, dataFeedback);
  }

  /// P3: pedir permiso al activar; revertir si se niega. Se guarda al
  /// instante, como el resto de preferencias.
  Future<void> setReminder(bool enabled) async {
    final current = profile;
    if (current == null || !reminderSupported || updatingPreferences) return;
    _setFeedback(preferences: null);
    showOpenSettings = false;
    if (!enabled) {
      await _reminders.cancel();
      await _savePreferences(
        current.preferences.copyWith(notificationsEnabled: false),
      );
      await _revokePush();
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
        final saved = await _savePreferences(
          current.preferences.copyWith(notificationsEnabled: true),
        );
        if (saved) {
          await _syncPush(
            notificationsEnabled: true,
            requestPermissionIfNeeded: true,
          );
        }
      case ReminderPermission.denied:
        _setFeedback(
          preferences: const ProfileFeedback.warning(reminderDeniedMessage),
        );
      case ReminderPermission.permanentlyDenied:
        _setFeedback(
          preferences: const ProfileFeedback.warning(
            reminderPermanentlyDeniedMessage,
          ),
        );
        showOpenSettings = true;
    }
    _notify();
  }

  Future<void> openSystemSettings() => _reminders.openSystemSettings();

  /// O1: exige autenticar antes de activar; desactivar no la pide.
  Future<void> setBiometric(bool enabled) async {
    final current = profile;
    if (current == null || !biometricAvailable || updatingPreferences) return;
    _setFeedback(preferences: null);
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
        _setFeedback(
          preferences: const ProfileFeedback.warning(biometricFailedMessage),
        );
        _notify();
        return;
      }
    }
    await _savePreferences(
      current.preferences.copyWith(biometricEnabled: enabled),
    );
  }

  /// Exporta y comparte el JSON como archivo (O10).
  ///
  /// Devuelve el JSON solo cuando la vista debe mostrarlo en el diálogo de
  /// respaldo (el plugin falló); null si se compartió, si no hay exportación
  /// o si ya hay una exportación en curso.
  Future<String?> exportData({Rect? origin}) async {
    if (exporting) return null;
    exporting = true;
    _setFeedback(data: null);
    _notify();
    try {
      final String json;
      try {
        json = await _repository.exportData();
      } on SessionExpiredException {
        sessionExpired = true;
        return null;
      } catch (_) {
        _setFeedback(
          data: const ProfileFeedback.error(exportUnavailableMessage),
        );
        return null;
      }
      try {
        await _sharer.shareJson(
          json: json,
          fileName: exportFileName(_clock()),
          origin: origin,
        );
        return null;
      } catch (_) {
        _setFeedback(
          data: const ProfileFeedback.warning(exportShareFailedMessage),
        );
        return json;
      }
    } finally {
      exporting = false;
      _notify();
    }
  }

  /// Elimina la cuenta en el API y, si lo logra, limpia lo local (recordatorio,
  /// token FCM y sesión). Devuelve true si la vista debe ir a `/login`.
  Future<bool> deleteAccount() async {
    if (deletingAccount) return false;
    deletingAccount = true;
    _setFeedback(data: null);
    _notify();
    try {
      await _repository.deleteAccount();
    } on SessionExpiredException {
      sessionExpired = true;
      deletingAccount = false;
      _notify();
      return false;
    } catch (_) {
      _setFeedback(
        data: const ProfileFeedback.error(accountDeletionFailedMessage),
      );
      deletingAccount = false;
      _notify();
      return false;
    }
    try {
      await _reminders.cancel();
    } catch (_) {
      // Sin recordatorio programado no hay nada que cancelar.
    }
    try {
      await _logout.logout();
    } catch (_) {
      // La cuenta ya no existe: la sesión local se descarta de todos modos.
    }
    deletingAccount = false;
    _notify();
    return true;
  }

  /// Sincroniza el token FCM sin romper la carga del perfil si falla.
  Future<void> _syncPush({
    required bool notificationsEnabled,
    bool requestPermissionIfNeeded = false,
  }) async {
    final service = _pushLifecycle;
    if (service == null) return;
    try {
      await service.syncForActiveSession(
        notificationsEnabled: notificationsEnabled,
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      );
    } catch (_) {
      // El ciclo FCM es best-effort.
    }
  }

  /// Revoca el token FCM sin bloquear el cambio de preferencia.
  Future<void> _revokePush() async {
    final service = _pushLifecycle;
    if (service == null) return;
    try {
      await service.deactivateAndRevoke();
    } catch (_) {
      // El ciclo FCM es best-effort.
    }
  }

  Future<void> logout() => _logout.logout();

  static const Object _keep = Object();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

enum _PatchResult { ok, failed, sessionExpired }
