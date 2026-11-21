import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/remote_state_views.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../data/foods_api_repository.dart';
import '../data/meals_api_repository.dart';
import '../domain/daily_summary.dart';
import '../domain/food_search_repository.dart';
import '../domain/meal_entry.dart';
import '../domain/meals_repository.dart';
import 'meal_format.dart';
import 'meals_view_model.dart';

/// Vista 2: resumen diario de consumidos por tipo de comida.
class MealsPage extends StatefulWidget {
  const MealsPage({
    super.key,
    this.mealsRepository,
    this.foodsRepository,
    this.connectivityService,
  });

  final MealsRepository? mealsRepository;
  final FoodSearchRepository? foodsRepository;
  final ConnectivityService? connectivityService;

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  ApiClient? _client;
  late final MealsViewModel _viewModel;
  late final FoodSearchRepository _foods;
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;

  ApiClient get _api => _client ??= ApiClient();

  @override
  void initState() {
    super.initState();
    _viewModel = MealsViewModel(
      widget.mealsRepository ?? MealsApiRepository.fromClient(_api),
    )..addListener(_onChange);
    _foods = widget.foodsRepository ?? FoodsApiRepository.fromClient(_api);
    _connectivitySubscription = _connectivity.onStatusChange.listen(
      _onConnectivityChange,
      onError: (_) {}, // Un fallo del plugin no debe tumbar la pantalla.
    );
    _load();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _viewModel
      ..removeListener(_onChange)
      ..dispose();
    _client?.dispose();
    super.dispose();
  }

  /// Sesión expirada al cargar o al agregar: a `/login`, como en Perfil.
  void _onChange() {
    if (_viewModel.sessionExpired && mounted) context.go('/login');
  }

  Future<void> _load() => _viewModel.load();

  /// Al recuperar la red, recarga solo si la última carga falló.
  void _onConnectivityChange(bool online) {
    if (!online || !mounted || _viewModel.sessionExpired) return;
    if (_viewModel.state is AsyncError) _load();
  }

  Future<void> _openSearch() async {
    final entry = await context.push<NewMealEntry>(
      appFoodSearchPath,
      extra: _foods,
    );
    if (entry == null || !mounted) return;
    final ok = await _viewModel.add(entry);
    if (!ok && mounted && !_viewModel.sessionExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo agregar el alimento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              OfflineBanner(service: _connectivity, onRetry: _load),
              Text('Comidas de hoy', style: AppTypography.pageTitle),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(label: 'Agregar alimento', onPressed: _openSearch),
              const SizedBox(height: AppSpacing.md),
              AsyncStateView<DailySummary>(
                state: _viewModel.state,
                onRetry: _load,
                loadingMessage: 'Cargando comidas...',
                emptyTitle: 'Aún no registras comidas hoy',
                emptyMessage: 'Agrega un alimento para ver el resumen del día.',
                errorTitle: 'No se pudo cargar',
                errorBuilder: (error, _) => RemoteErrorView(
                  title: 'No se pudo cargar',
                  message: error is AuthApiException
                      ? error.message
                      : 'No se pudo cargar tus comidas',
                  onRetry: _load,
                ),
                dataBuilder: (summary) => _SummaryView(summary: summary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final secondary = AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Consumido hoy', style: secondary),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${formatAmount(summary.totals.kcal)} kcal',
                key: const Key('daily-kcal'),
                style: AppTypography.pageTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Proteína ${formatAmount(summary.totals.proteinG)} g · '
                'Carbohidratos ${formatAmount(summary.totals.carbsG)} g · '
                'Grasa ${formatAmount(summary.totals.fatG)} g',
                style: secondary,
              ),
            ],
          ),
        ),
        for (final section in summary.sections) ...[
          const SizedBox(height: AppSpacing.sm),
          GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${section.mealType.label} · '
                  '${formatAmount(section.totals.kcal)} kcal',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (section.entries.isEmpty)
                  Text('Sin alimentos', style: secondary)
                else
                  for (final entry in section.entries)
                    for (final item in entry.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          '${item.name} · ${formatAmount(item.servingG)} g\n'
                          '${formatMacros(item.macros)}',
                          style: secondary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
