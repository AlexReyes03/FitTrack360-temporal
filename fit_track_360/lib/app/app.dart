import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/network/api_client.dart';
import '../core/session_storage.dart';
import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radii.dart';
import '../design_system/tokens/app_typography.dart';
import '../features/notifications/data/notifications_api_repository.dart';
import '../features/notifications/data/push_device_lifecycle_service.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import '../features/notifications/presentation/notifications_view_model.dart';
import '../features/notifications/presentation/push_device_scope.dart';
import 'router.dart';

/// Idioma único de la app: español de México (pickers, menú de texto y
/// etiquetas de accesibilidad de Material salen en español y en 24 h).
const Locale fitTrackLocale = Locale('es', 'MX');

const List<Locale> fitTrackSupportedLocales = <Locale>[fitTrackLocale];

const List<LocalizationsDelegate<dynamic>> fitTrackLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

/// Selección monocroma de los pickers: fondo accentWhite con texto textOnAccent.
/// `WidgetStateColor` sirve tanto donde se pide `Color?` (selector de hora)
/// como donde se pide `WidgetStateProperty<Color?>` (selector de fecha).
WidgetStateColor _selectedFill({Color idle = Colors.transparent}) =>
    WidgetStateColor.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? AppColors.accentWhite : idle,
    );

WidgetStateColor _selectedText({Color idle = AppColors.textPrimary}) =>
    WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.textOnAccent;
      if (states.contains(WidgetState.disabled)) return AppColors.textMuted;
      return idle;
    });

final ButtonStyle _pickerActionStyle = TextButton.styleFrom(
  foregroundColor: AppColors.accentWhite,
);

const ShapeBorder _pickerShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
  side: BorderSide(color: AppColors.glassBorder),
);

/// Velo de diálogos y hojas. Sin token de scrim: `bgDeep` al 80 %.
/// Cambiar a token `scrim` de #221 (mismo valor que `glassBarrierColor`).
final Color _scrim = AppColors.bgDeep.withValues(alpha: 0.8);

/// Chips monocromos: seleccionado en accentWhite con texto textOnAccent; en
/// reposo vidrio tenue. Evita el teal/silver de `secondaryContainer`.
final ChipThemeData _chipTheme = ChipThemeData(
  color: WidgetStateColor.resolveWith((states) {
    if (states.contains(WidgetState.selected)) return AppColors.accentWhite;
    return AppColors.glassFillSoft;
  }),
  selectedColor: AppColors.accentWhite,
  disabledColor: AppColors.glassFillSoft,
  checkmarkColor: AppColors.textOnAccent,
  side: WidgetStateBorderSide.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.selected)
          ? AppColors.accentWhite
          : AppColors.glassBorderStrong,
    ),
  ),
  shape: const StadiumBorder(),
  labelStyle: TextStyle(
    color: _selectedText(idle: AppColors.zinc200),
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
  secondaryLabelStyle: const TextStyle(
    color: AppColors.textOnAccent,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
  iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 18),
);

final ThemeData fitTrackDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bgDeep,
  // Todos los roles de color quedan en la paleta monocroma: sin esto,
  // secondary/tertiary heredan el teal por defecto de Material (p. ej. el
  // periodo del día seleccionado en el selector de hora).
  colorScheme: const ColorScheme.dark(
    surface: AppColors.bgDeep,
    primary: AppColors.accentWhite,
    onPrimary: AppColors.textOnAccent,
    primaryContainer: AppColors.accentSilver,
    onPrimaryContainer: AppColors.textOnAccent,
    secondary: AppColors.accentSilver,
    onSecondary: AppColors.textOnAccent,
    secondaryContainer: AppColors.accentSilver,
    onSecondaryContainer: AppColors.textOnAccent,
    tertiary: AppColors.accentWhite,
    onTertiary: AppColors.textOnAccent,
    tertiaryContainer: AppColors.accentWhite,
    onTertiaryContainer: AppColors.textOnAccent,
    inversePrimary: AppColors.textOnAccent,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.glassBorderStrong,
    outlineVariant: AppColors.glassBorder,
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: AppColors.bgMid,
    surfaceTintColor: Colors.transparent,
    shape: _pickerShape,
    headerBackgroundColor: AppColors.bgMid,
    headerForegroundColor: AppColors.textPrimary,
    weekdayStyle: const TextStyle(color: AppColors.textSecondary),
    dividerColor: AppColors.glassBorder,
    dayForegroundColor: _selectedText(),
    dayBackgroundColor: _selectedFill(),
    dayOverlayColor: const WidgetStatePropertyAll(
      AppColors.glassFillPressedStrong,
    ),
    todayForegroundColor: _selectedText(),
    todayBackgroundColor: _selectedFill(),
    todayBorder: const BorderSide(color: AppColors.accentWhite),
    yearForegroundColor: _selectedText(),
    yearBackgroundColor: _selectedFill(),
    yearOverlayColor: const WidgetStatePropertyAll(
      AppColors.glassFillPressedStrong,
    ),
    rangeSelectionBackgroundColor: AppColors.glassFillPressedStrong,
    rangePickerBackgroundColor: AppColors.bgMid,
    rangePickerHeaderBackgroundColor: AppColors.bgMid,
    rangePickerHeaderForegroundColor: AppColors.textPrimary,
    cancelButtonStyle: _pickerActionStyle,
    confirmButtonStyle: _pickerActionStyle,
  ),
  timePickerTheme: TimePickerThemeData(
    backgroundColor: AppColors.bgMid,
    shape: _pickerShape,
    helpTextStyle: const TextStyle(color: AppColors.textSecondary),
    hourMinuteColor: _selectedFill(idle: AppColors.glassFillStrong),
    hourMinuteTextColor: _selectedText(),
    dayPeriodColor: _selectedFill(),
    dayPeriodTextColor: _selectedText(idle: AppColors.textSecondary),
    dayPeriodBorderSide: const BorderSide(color: AppColors.glassBorder),
    dialBackgroundColor: AppColors.glassFillStrong,
    dialHandColor: AppColors.accentWhite,
    dialTextColor: _selectedText(),
    entryModeIconColor: AppColors.textSecondary,
    timeSelectorSeparatorColor: const WidgetStatePropertyAll(
      AppColors.textPrimary,
    ),
    cancelButtonStyle: _pickerActionStyle,
    confirmButtonStyle: _pickerActionStyle,
  ),
  // Superficies emergentes Material que aún no usan los componentes glass
  // del DS (`GlassDialog`, `showGlassBottomSheet`, `showAppSnackBar`) se ven
  // igual de oscuras y monocromas.
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.bgMid,
    surfaceTintColor: Colors.transparent,
    barrierColor: _scrim,
    shape: _pickerShape,
    titleTextStyle: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    contentTextStyle: AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.bgMid,
    elevation: 0,
    contentTextStyle: AppTypography.body,
    actionTextColor: AppColors.accentWhite,
    disabledActionTextColor: AppColors.textMuted,
    closeIconColor: AppColors.textSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.banner)),
      side: BorderSide(color: AppColors.glassBorderStrong),
    ),
  ),
  chipTheme: _chipTheme,
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColors.bgMid,
    modalBackgroundColor: AppColors.bgMid,
    surfaceTintColor: Colors.transparent,
    modalBarrierColor: _scrim,
    elevation: 0,
    modalElevation: 0,
    showDragHandle: true,
    dragHandleColor: AppColors.glassBorderStrong,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
      side: BorderSide(color: AppColors.glassBorder),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.accentWhite,
    linearTrackColor: AppColors.glassFillStrong,
    circularTrackColor: Colors.transparent,
    refreshBackgroundColor: AppColors.bgMid,
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: _selectedText(idle: AppColors.accentWhite),
      overlayColor: const WidgetStatePropertyAll(
        AppColors.glassFillPressedSoft,
      ),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.textOnAccent;
      }
      return AppColors.accentSilver;
    }),
    trackColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.accentWhite;
      return AppColors.controlFillIdle;
    }),
    trackOutlineColor: const WidgetStatePropertyAll(
      AppColors.glassBorderStrong,
    ),
  ),
);

class FitTrackApp extends StatefulWidget {
  const FitTrackApp({super.key, this.notifications, this.pushDeviceService});

  /// Inyectable en pruebas; en runtime se crea con el API real.
  final NotificationsViewModel? notifications;

  /// Inyectable en pruebas; en runtime se crea una sola instancia compartida.
  final PushDeviceLifecycle? pushDeviceService;

  @override
  State<FitTrackApp> createState() => _FitTrackAppState();
}

class _FitTrackAppState extends State<FitTrackApp> {
  ApiClient? _apiClient;
  late final NotificationsViewModel _notifications;
  late final bool _ownsNotifications;
  late final PushDeviceLifecycle _pushDeviceService;
  late final bool _ownsPushDeviceService;

  ApiClient _ensureApiClient() => _apiClient ??= ApiClient();

  @override
  void initState() {
    super.initState();
    final injectedNotifications = widget.notifications;
    _ownsNotifications = injectedNotifications == null;
    if (injectedNotifications != null) {
      _notifications = injectedNotifications;
    } else {
      _notifications = NotificationsViewModel(
        repository: NotificationsApiRepository(_ensureApiClient()),
      );
    }

    final injectedPush = widget.pushDeviceService;
    _ownsPushDeviceService = injectedPush == null;
    if (injectedPush != null) {
      _pushDeviceService = injectedPush;
    } else {
      _pushDeviceService = PushDeviceLifecycleService.fromClient(
        _ensureApiClient(),
      );
    }

    appSessionInvalidations.addListener(_onSessionInvalidated);
  }

  /// Una sesión expirada o cerrada no debe dejar avisos de la cuenta anterior.
  void _onSessionInvalidated() => _notifications.clearOnLogout();

  @override
  void dispose() {
    appSessionInvalidations.removeListener(_onSessionInvalidated);
    if (_ownsNotifications) _notifications.dispose();
    if (_ownsPushDeviceService) {
      unawaited(_pushDeviceService.dispose());
    }
    _apiClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PushDeviceScope(
      service: _pushDeviceService,
      child: NotificationsScope(
        notifier: _notifications,
        child: MaterialApp.router(
          title: 'FitTrack360',
          locale: fitTrackLocale,
          supportedLocales: fitTrackSupportedLocales,
          localizationsDelegates: fitTrackLocalizationsDelegates,
          themeMode: ThemeMode.dark,
          theme: fitTrackDarkTheme,
          darkTheme: fitTrackDarkTheme,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
