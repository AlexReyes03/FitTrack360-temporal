import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
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

/// Catálogo de ejercicios: búsqueda, filtros, contador y paginación.
class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key, this.api});

  final ExercisesApi? api;

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  static const int _pageSize = ExercisesApi.defaultPageSize;
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  // El cliente solo se crea (y se libera) si la página no recibió una API.
  late final ApiClient? _ownedClient = widget.api == null ? ApiClient() : null;
  late final ExercisesApi _api = widget.api ?? ExercisesApi(_ownedClient!);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

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
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _ownedClient?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Una carga explícita (filtro, página, reintento) descarta el debounce
    // pendiente; si no, vencería después y volvería a la página 1.
    _searchTimer?.cancel();
    final requestId = ++_requestId;
    setState(() => _state = const AsyncLoading<ExercisePage>());
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
      if (mounted) context.go('/login');
    } catch (error, stackTrace) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = AsyncError<ExercisePage>(error, stackTrace));
    }
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
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

  void _goToPage(int page) {
    if (page < 1) return;
    setState(() => _page = page);
    _load();
  }

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
                  child: _state.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentWhite,
                      ),
                    ),
                    data: (page) => _results(page),
                    error: (error, _) => _error(error),
                    empty: _empty,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        Text(
          _resultsLabel(page.total),
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final exercise in page.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ExerciseCard(
              exercise: exercise,
              onTap: () => _openDetail(exercise),
            ),
          ),
        _pagination(page),
      ],
    );
  }

  String _resultsLabel(int total) =>
      total == 1 ? '1 resultado' : '$total resultados';

  Widget _pagination(ExercisePage page) {
    return Row(
      children: [
        TextButton(
          onPressed: page.hasPrevious ? () => _goToPage(page.page - 1) : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            disabledForegroundColor: AppColors.textMuted,
          ),
          child: const Text('Anterior'),
        ),
        Expanded(
          child: Text(
            'Página ${page.page} de ${page.totalPages}',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: page.hasNext ? () => _goToPage(page.page + 1) : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            disabledForegroundColor: AppColors.textMuted,
          ),
          child: const Text('Siguiente'),
        ),
      ],
    );
  }

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
