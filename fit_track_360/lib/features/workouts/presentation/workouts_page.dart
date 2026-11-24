import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/remote_state_views.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../../home/presentation/widgets/home_navigation_shell.dart';
import '../data/workout_session.dart';
import '../data/workouts_api.dart';
import '../domain/workout_session_draft.dart';
import 'tracker_session_page.dart';
import 'workout_detail_format.dart';
import 'workout_form_page.dart';
import 'widgets/tracker_controls.dart';

/// Ruta del listado de rutinas (plantillas para «Entrenar ahora»).
const routinesRoute = '/app/rutinas';

/// Ruta de esta pestaña; al volver a ella se recarga el historial.
const workoutsRoute = '/app/entrenamientos';

/// Pestaña Entrenamientos: acciones para entrenar e historial en tarjetas.
///
/// Flujo único: rutina o borrador → tracker («Entrenar ahora»). El formulario
/// ([WorkoutFormPage]) es solo para «Registrar entrenamiento pasado».
class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({
    super.key,
    this.api,
    this.draft,
    this.profileClient,
    this.apiClientFactory = ApiClient.new,
    this.connectivityService,
  });

  final WorkoutsApi? api;
  final ApiClient? profileClient;

  /// Crea el cliente HTTP propio solo cuando no se inyecta [api].
  final ApiClient Function() apiClientFactory;

  /// Borrador recibido por la ruta (enlaces anteriores a #228): se abre en el
  /// tracker, que es el único flujo para entrenar.
  final WorkoutSessionDraft? draft;
  final ConnectivityService? connectivityService;

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  ApiClient? _ownClient;
  late final WorkoutsApi _api =
      widget.api ?? WorkoutsApi(_ownClient = widget.apiClientFactory());
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  AsyncState<List<WorkoutSession>> _state = const AsyncLoading();
  GoRouter? _router;
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = _connectivity.onStatusChange.listen(
      _onConnectivityChange,
      onError: (_) {}, // Un fallo del plugin no debe tumbar la pantalla.
    );
    _load();
    if (widget.draft case final draft?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTracker(TrackerSessionArgs(draft: draft));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _lastPath = _currentPath();
    router?.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _connectivitySubscription?.cancel();
    _ownClient?.dispose();
    super.dispose();
  }

  /// Ruta visible en primer plano, incluidas las abiertas con `push`.
  String? _currentPath() {
    final delegate = _router?.routerDelegate;
    if (delegate == null || delegate.currentConfiguration.isEmpty) return null;
    return delegate.state.uri.path;
  }

  /// Al volver a esta pestaña (p. ej. tras finalizar en el tracker o borrar
  /// una sesión en su detalle) recarga el historial.
  void _onRouteChanged() {
    final path = _currentPath();
    final previous = _lastPath;
    _lastPath = path;
    if (path == workoutsRoute && previous != workoutsRoute && mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _state = const AsyncLoading());
    try {
      final sessions = await _api.list();
      if (!mounted) return;
      setState(() => _state = AsyncState.fromData(sessions));
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _state = AsyncError(error, stackTrace));
    }
  }

  /// Al recuperar la red, recarga solo si la última carga falló.
  void _onConnectivityChange(bool online) {
    if (online && mounted && _state is AsyncError) _load();
  }

  /// Al volver, [_onRouteChanged] recarga el historial.
  void _startTracker([TrackerSessionArgs? args]) {
    context.push(workoutTrackerRoute, extra: args);
  }

  Future<void> _registerPast() async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutFormPage(
          api: _api,
          profileClient: _ownClient ?? widget.profileClient,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Entrenamiento registrado')));
    await _load();
  }

  void _openSession(WorkoutSession session) {
    context.push('$workoutsRoute/${session.id}');
  }

  @override
  Widget build(BuildContext context) {
    final embedded = HomeNavigationShell.isEmbedded(context);
    final list = ListView(
      key: const Key('workouts-scroll'),
      padding: EdgeInsets.fromLTRB(24, embedded ? 12 : 24, 24, 28),
      children: [
        OfflineBanner(service: _connectivity, onRetry: _load),
        Row(
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textSecondary,
                ),
              ),
            const Expanded(
              child: Text('Entrenamientos', style: AppTypography.pageTitle),
            ),
            TrackerGlassButton(
              label: 'Rutinas',
              icon: Icons.list_alt_rounded,
              compact: true,
              onPressed: () => context.push(routinesRoute),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(label: 'Entrenar ahora', onPressed: _startTracker),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Elige un ejercicio o una de tus rutinas y registra tus series en '
          'vivo.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                'Historial',
                style: AppTypography.cta.copyWith(color: AppColors.textPrimary),
              ),
            ),
            Semantics(
              label: 'Registrar entrenamiento pasado',
              button: true,
              excludeSemantics: true,
              child: TrackerGlassButton(
                label: 'Nuevo',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: _registerPast,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '¿Entrenaste sin la app? Usa «Nuevo» para registrarlo.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        AsyncStateView<List<WorkoutSession>>(
          state: _state,
          onRetry: _load,
          loadingMessage: 'Cargando sesiones...',
          emptyTitle: 'Aún no tienes sesiones',
          emptyMessage:
              'Entrena ahora o registra un entrenamiento pasado para empezar '
              'tu historial.',
          errorBuilder: (error, _) => RemoteErrorView(
            title: 'No se pudo cargar',
            message: error is AuthApiException
                ? error.message
                : 'No se pudo conectar',
            onRetry: _load,
          ),
          dataBuilder: (sessions) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final session in sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: WorkoutHistoryCard(
                    session: session,
                    onTap: () => _openSession(session),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    if (embedded) {
      return Scaffold(backgroundColor: Colors.transparent, body: list);
    }
    return AppScaffoldTemplate(body: SafeArea(child: list));
  }
}

/// Tarjeta glass de una sesión del historial.
class WorkoutHistoryCard extends StatelessWidget {
  const WorkoutHistoryCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  final WorkoutSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ended = session.endedAt;
    final duration = ended == null
        ? null
        : formatDuration(ended.difference(session.startedAt));
    final exercises = {
      for (final set in session.sets) set.exerciseId ?? set.exerciseName,
    }.length;
    final summary = [
      if (exercises > 0)
        exercises == 1 ? '1 ejercicio' : '$exercises ejercicios',
      formatSetCount(session.sets.length),
    ].join(' · ');
    final notes = session.notes?.trim();

    return GlassSurface(
      padding: EdgeInsets.zero,
      radius: AppRadii.inner,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.inner),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatDateTime(session.startedAt),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (duration != null) TrackerTagChip(label: duration),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(summary, style: AppTypography.caption),
                      const SizedBox(height: 4),
                      Text(
                        notes == null || notes.isEmpty ? 'Sin notas' : notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
