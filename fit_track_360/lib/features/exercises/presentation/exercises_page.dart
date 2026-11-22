import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/remote_state_views.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../../auth/data/auth_api.dart';
import '../data/exercise.dart';
import '../data/exercises_api.dart';
import 'widgets/exercise_card.dart';
import 'widgets/exercise_filters.dart';

/// Catálogo de ejercicios: búsqueda, filtros y carga incremental.
class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key, this.api, this.connectivityService});

  final ExercisesApi? api;
  final ConnectivityService? connectivityService;

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  static const int _pageSize = ExercisesApi.defaultPageSize;
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  // El cliente solo se crea (y se libera) si la página no recibió una API.
  late final ApiClient? _ownedClient = widget.api == null ? ApiClient() : null;
  late final ExercisesApi _api = widget.api ?? ExercisesApi(_ownedClient!);
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  final ScrollController _scrollController = ScrollController();
  bool _loadingMore = false;
  bool _moreError = false;

  AsyncState<ExercisePage> _state = const AsyncLoading<ExercisePage>();

  String? _bodyPart;
  String? _equipment;
  String? _target;
  int _page = 1;

  /// Descarta respuestas viejas cuando el usuario cambia de filtro rápido.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = _connectivity.onStatusChange.listen(
      _onConnectivityChange,
      onError: (_) {}, // Un fallo del plugin no debe tumbar la pantalla.
    );
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _ownedClient?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Una carga explícita (filtro, página, reintento) descarta el debounce
    // pendiente; si no, vencería después y volvería a la página 1.
    _searchTimer?.cancel();
    final requestId = ++_requestId;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _page = 1;
      _loadingMore = false;
      _moreError = false;
      _state = const AsyncLoading<ExercisePage>();
    });
    try {
      final result = await _api.fetchPage(
        query: _searchController.text,
        bodyPart: _bodyPart,
        equipment: _equipment,
        target: _target,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _state = result.items.isEmpty
            ? const AsyncEmpty<ExercisePage>()
            : AsyncData<ExercisePage>(result);
      });
    } on SessionExpiredException {
      if (mounted && requestId == _requestId) context.go('/login');
    } catch (error, stackTrace) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = AsyncError<ExercisePage>(error, stackTrace));
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) _loadMore();
  }

  Future<void> _loadMore() async {
    final state = _state;
    if (state is! AsyncData<ExercisePage> ||
        _loadingMore ||
        _moreError ||
        !state.data.hasNext ||
        _searchTimer?.isActive == true) {
      return;
    }
    final previous = state.data;
    final requestId = _requestId;
    setState(() => _loadingMore = true);
    try {
      final result = await _api.fetchPage(
        query: _searchController.text,
        bodyPart: _bodyPart,
        equipment: _equipment,
        target: _target,
        page: previous.page + 1,
        pageSize: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;
      final ids = previous.items.map((item) => item.id).toSet();
      setState(() {
        _page = result.page;
        _loadingMore = false;
        _state = AsyncData(
          ExercisePage(
            items: [
              ...previous.items,
              ...result.items.where((item) => ids.add(item.id)),
            ],
            total: result.total,
            page: result.page,
            pageSize: result.pageSize,
          ),
        );
      });
    } on SessionExpiredException {
      if (mounted && requestId == _requestId) context.go('/login');
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loadingMore = false;
        _moreError = true;
      });
    }
  }

  /// Al recuperar la red, recarga solo si la última carga falló.
  void _onConnectivityChange(bool online) {
    if (online && mounted && _state is AsyncError) _load();
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _requestId++;
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() => _page = 1);
      _load();
    });
  }

  void _onBodyPartChanged(String? value) {
    setState(() {
      _bodyPart = value;
      _page = 1;
    });
    _load();
  }

  void _onEquipmentChanged(String? value) {
    setState(() {
      _equipment = value;
      _page = 1;
    });
    _load();
  }

  void _onTargetChanged(String? value) {
    setState(() {
      _target = value;
      _page = 1;
    });
    _load();
  }

  void _clearFilters() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _bodyPart = null;
      _equipment = null;
      _target = null;
      _page = 1;
    });
    _load();
  }

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty ||
      _bodyPart != null ||
      _equipment != null ||
      _target != null;

  void _openDetail(Exercise exercise) {
    context.push('/app/ejercicios/${exercise.id}');
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OfflineBanner(service: _connectivity, onRetry: _load),
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: DsTextField(
                    controller: _searchController,
                    label: 'Buscar',
                    hint: 'Nombre del ejercicio',
                    onChanged: _onSearchChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: ExerciseFilters(
                    bodyPart: _bodyPart,
                    equipment: _equipment,
                    target: _target,
                    onBodyPartChanged: _onBodyPartChanged,
                    onEquipmentChanged: _onEquipmentChanged,
                    onTargetChanged: _onTargetChanged,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: AsyncStateView<ExercisePage>(
                    state: _state,
                    onRetry: _load,
                    loadingMessage: 'Cargando ejercicios...',
                    emptyBuilder: _empty,
                    errorBuilder: (error, _) => _error(error),
                    dataBuilder: _results,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('Ejercicios', style: AppTypography.pageTitle)),
        ],
      ),
    );
  }

  Widget _results(ExercisePage page) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: page.items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              _resultsLabel(page.total),
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        if (index <= page.items.length) {
          final exercise = page.items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ExerciseCard(
              exercise: exercise,
              onTap: () => _openDetail(exercise),
            ),
          );
        }
        if (_loadingMore) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_moreError) {
          return TextButton(
            onPressed: () {
              setState(() => _moreError = false);
              _loadMore();
            },
            child: const Text('Reintentar carga de ejercicios'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  String _resultsLabel(int total) =>
      total == 1 ? '1 resultado' : '$total resultados';

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _hasFilters
                  ? 'No encontramos ejercicios con esos filtros.'
                  : 'El catálogo todavía no tiene ejercicios.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (_hasFilters) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Limpiar filtros',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _error(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error is AuthApiException ? error.message : 'No se pudo conectar',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.dangerText),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Reintentar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
