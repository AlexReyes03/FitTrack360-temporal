import 'dart:async';
import 'dart:ui' show Rect;

import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/core/notifications/reminder_service.dart';
import 'package:fit_track_360/core/security/biometric_service.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/notifications/data/push_device_lifecycle_service.dart';
import 'package:fit_track_360/features/settings/domain/export_sharer.dart';
import 'package:fit_track_360/features/settings/domain/profile_repository.dart';
import 'package:fit_track_360/features/settings/domain/user_profile.dart';

const sampleGoals = NutritionGoals(
  dailyCalorieGoal: 2000,
  proteinGoalG: 150,
  carbsGoalG: 250,
  fatGoalG: 65,
);

const samplePreferences = UserPreferences(
  weightUnit: WeightUnit.kg,
  distanceUnit: DistanceUnit.km,
  restSeconds: 90,
  notificationsEnabled: false,
  biometricEnabled: false,
);

const sampleProfile = UserProfile(
  id: '1',
  email: 'ana@test.com',
  username: 'ana',
  displayName: 'Ana',
  goals: sampleGoals,
  preferences: samplePreferences,
);

UserProfile sampleProfileWithNotifications(bool enabled) => UserProfile(
  id: sampleProfile.id,
  email: sampleProfile.email,
  username: sampleProfile.username,
  displayName: sampleProfile.displayName,
  goals: sampleProfile.goals,
  preferences: samplePreferences.copyWith(notificationsEnabled: enabled),
);

Map<String, dynamic> sampleProfileJson() => {
  'id': '1',
  'email': 'ana@test.com',
  'username': 'ana',
  'displayName': 'Ana',
  'goals': sampleGoals.toJson(),
  'preferences': samplePreferences.toJson(),
  'workoutCount': 3,
};

/// Repositorio en memoria: aplica el PATCH y lo devuelve en el siguiente GET.
/// Como el API, `workoutCount` solo viaja en el GET (null = API sin el campo).
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({UserProfile? profile, this.workouts = 3})
    : profile = profile ?? sampleProfile;

  UserProfile? profile;
  int? workouts;
  Object? fetchError;
  Object? updateError;
  String? exportJson;
  final updates = <ProfileUpdate>[];
  int fetchCalls = 0;

  @override
  Future<UserProfile?> fetchProfile() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    final current = profile;
    if (current == null) return null;
    return UserProfile(
      id: current.id,
      email: current.email,
      username: current.username,
      displayName: current.displayName,
      goals: current.goals,
      preferences: current.preferences,
      workoutCount: workouts,
    );
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async {
    updates.add(update);
    if (updateError != null) throw updateError!;
    final current = profile!;
    profile = UserProfile(
      id: current.id,
      email: current.email,
      username: current.username,
      displayName: update.displayName ?? current.displayName,
      goals: update.goals ?? current.goals,
      preferences: update.preferences ?? current.preferences,
    );
    return profile!;
  }

  @override
  Future<String> exportData() async {
    if (exportJson == null) throw const ExportUnavailableException();
    return exportJson!;
  }
}

/// Hoja de compartir simulada: registra lo compartido o falla a voluntad.
class FakeExportSharer implements ExportSharer {
  FakeExportSharer({this.error});

  Object? error;
  final shared = <({String json, String fileName, Rect? origin})>[];

  @override
  Future<void> shareJson({
    required String json,
    required String fileName,
    Rect? origin,
  }) async {
    if (error != null) throw error!;
    shared.add((json: json, fileName: fileName, origin: origin));
  }
}

class FakeReminderService implements ReminderService {
  FakeReminderService({
    this.supported = true,
    this.permission = ReminderPermission.granted,
  });

  bool supported;
  ReminderPermission permission;
  int requests = 0;
  int scheduled = 0;
  int cancelled = 0;
  int settingsOpened = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<ReminderPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    scheduled++;
  }

  @override
  Future<void> cancel() async => cancelled++;

  @override
  Future<void> openSystemSettings() async => settingsOpened++;
}

class FakeBiometricService implements BiometricService {
  FakeBiometricService({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;
  int attempts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    attempts++;
    return succeeds;
  }
}

class FakeSessionStorage implements SessionStorage {
  String? accessToken = 'access';
  String? refreshToken = 'refresh';

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

class FakePushDeviceLifecycle implements PushDeviceLifecycle {
  final syncCalls =
      <({bool notificationsEnabled, bool requestPermissionIfNeeded})>[];
  int revokeCalls = 0;
  int disposeCalls = 0;
  Object? syncError;
  Object? revokeError;

  @override
  Future<void> syncForActiveSession({
    required bool notificationsEnabled,
    bool requestPermissionIfNeeded = false,
  }) async {
    if (syncError != null) throw syncError!;
    syncCalls.add((
      notificationsEnabled: notificationsEnabled,
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    ));
  }

  @override
  Future<void> deactivateAndRevoke() async {
    revokeCalls++;
    if (revokeError != null) throw revokeError!;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;
  final _controller = StreamController<bool>.broadcast();

  /// Simula un cambio de red: actualiza [online] y lo emite.
  void emit(bool value) {
    online = value;
    _controller.add(value);
  }

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<bool> isOnline() async => online;
}
