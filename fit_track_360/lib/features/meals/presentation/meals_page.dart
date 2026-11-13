import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
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
import 'food_search_page.dart';
import 'meal_format.dart';
import 'meals_view_model.dart';

/// Vista 2: resumen diario de consumidos por tipo de comida.
class MealsPage extends StatefulWidget {
  const MealsPage({super.key, this.mealsRepository, this.foodsRepository});

  final MealsRepository? mealsRepository;
  final FoodSearchRepository? foodsRepository;

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  ApiClient? _client;
  late final MealsViewModel _viewModel;
  late final FoodSearchRepository _foods;

  ApiClient get _api => _client ??= ApiClient();

  @override
  void initState() {
    super.initState();
    _viewModel = MealsViewModel(
      widget.mealsRepository ?? MealsApiRepository.fromClient(_api),
    );
    _foods = widget.foodsRepository ?? FoodsApiRepository.fromClient(_api);
    _load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _viewModel.load();
    final state = _viewModel.state;
    if (state is AsyncError<DailySummary> &&
        state.error is SessionExpiredException &&
        mounted) {
      context.go('/login');
    }
  }

  Future<void> _openSearch() async {
    final entry = await Navigator.of(context).push<NewMealEntry>(
      MaterialPageRoute(builder: (_) => FoodSearchPage(repository: _foods)),
    );
    if (entry == null || !mounted) return;
    final ok = await _viewModel.add(entry);
    if (!ok && mounted) {
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
              Text('Comidas de hoy', style: AppTypography.pageTitle),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(label: 'Agregar alimento', onPressed: _openSearch),
              const SizedBox(height: AppSpacing.md),
              _viewModel.state.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentWhite,
                  ),
                ),
                data: (summary) => _SummaryView(summary: summary),
                error: (error, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error is AuthApiException
                          ? error.message
                          : 'No se pudo cargar tus comidas',
                      style: AppTypography.body.copyWith(
                        color: AppColors.dangerText,
                      ),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                empty: () => Text(
                  'Aún no registras comidas hoy',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        '${entry.name} · ${formatAmount(entry.portionG)} g\n'
                        '${formatMacros(entry.macros)}',
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
