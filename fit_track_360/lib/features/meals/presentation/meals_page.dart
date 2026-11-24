import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/remote_state_views.dart';
import '../../../design_system/components/app_snack_bar.dart';
import '../../../design_system/components/glass_dialog.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/components/status_banner.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/data/auth_api.dart';
import '../../home/presentation/widgets/home_navigation_shell.dart';
import '../data/foods_api_repository.dart';
import '../data/meals_api_repository.dart';
import '../domain/daily_summary.dart';
import '../domain/food_search_repository.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_item.dart';
import '../domain/meals_repository.dart';
import 'meal_format.dart';
import 'meal_item_form_page.dart';
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

  /// Sesión expirada al cargar o escribir: a `/login`, como en Perfil.
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
      _showMessage(
        'No se pudo agregar el alimento',
        variant: StatusBannerVariant.danger,
      );
    }
  }

  Future<void> _editItem(MealEntry entry, int index) async {
    if (!entry.canEdit) {
      await _showLegacyMessage();
      return;
    }
    final result = await Navigator.of(context).push<MealMutationResult>(
      MaterialPageRoute(
        builder: (_) => MealItemFormPage(
          item: entry.items[index],
          onSave: (item) => _viewModel.updateItem(entry, index, item),
        ),
      ),
    );
    if (!mounted || result != MealMutationResult.notFound) return;
    _showMessage(
      'El alimento ya no existe',
      variant: StatusBannerVariant.warning,
    );
  }

  Future<void> _deleteItem(MealEntry entry, int index) async {
    final item = entry.items[index];
    if (!await _confirmDelete(entry, item) || !mounted) return;
    final result = await _viewModel.removeItem(entry, index);
    if (!mounted) return;
    switch (result) {
      case MealMutationResult.success:
        _showMessage(
          'Alimento eliminado',
          variant: StatusBannerVariant.success,
        );
        break;
      case MealMutationResult.notFound:
        _showMessage(
          'El alimento ya no existe',
          variant: StatusBannerVariant.warning,
        );
        break;
      case MealMutationResult.failure:
        if (!_viewModel.sessionExpired) {
          _showMessage(
            'No se pudo eliminar el alimento',
            variant: StatusBannerVariant.danger,
          );
        }
        break;
      case MealMutationResult.busy:
        break;
    }
  }

  Future<bool> _confirmDelete(MealEntry entry, MealItem item) async {
    final last = entry.items.length == 1;
    return showGlassConfirmDialog(
      context: context,
      title: 'Eliminar alimento',
      message: last
          ? '«${item.name}» es el último alimento de esta comida. '
                'Se eliminará el registro completo.'
          : '¿Eliminar «${item.name}»? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
  }

  Future<void> _showLegacyMessage() => showGlassDialog<void>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: 'No se puede editar',
      message:
          'Este registro antiguo no guarda porción ni macros separadas. '
          'Editarlo podría convertir sus valores en cero. Puedes eliminarlo y '
          'registrarlo de nuevo.',
      actions: [
        PrimaryButton(
          label: 'Entendido',
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );

  void _showMessage(
    String message, {
    StatusBannerVariant variant = StatusBannerVariant.neutral,
  }) {
    showAppSnackBar(context, message: message, variant: variant);
  }

  @override
  Widget build(BuildContext context) {
    final embedded = HomeNavigationShell.isEmbedded(context);
    final content = ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          embedded ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          OfflineBanner(service: _connectivity, onRetry: _load),
          Text('Comidas de hoy', style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Agregar alimento',
            onPressed: _viewModel.busy ? null : _openSearch,
          ),
          if (_viewModel.busy) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(
              key: Key('meals-busy'),
              color: AppColors.accentWhite,
              backgroundColor: Colors.transparent,
            ),
          ],
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
            dataBuilder: (summary) => _SummaryView(
              summary: summary,
              actionsEnabled: !_viewModel.busy,
              onEdit: _editItem,
              onDelete: _deleteItem,
            ),
          ),
        ],
      ),
    );
    if (embedded) {
      return Scaffold(backgroundColor: Colors.transparent, body: content);
    }
    return AppScaffoldTemplate(body: SafeArea(child: content));
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.summary,
    required this.actionsEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final DailySummary summary;
  final bool actionsEnabled;
  final void Function(MealEntry entry, int index) onEdit;
  final void Function(MealEntry entry, int index) onDelete;

  @override
  Widget build(BuildContext context) {
    final secondary = AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
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
          const SizedBox(height: AppSpacing.sectionGap),
          GlassSurface(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
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
                    for (final (index, item) in entry.items.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.name} · '
                                '${formatAmount(item.servingG)} g\n'
                                '${formatMacros(item.macros)}',
                                style: secondary,
                              ),
                            ),
                            PopupMenuButton<_ItemAction>(
                              key: Key('item-menu-${entry.id}-$index'),
                              enabled: actionsEnabled,
                              tooltip: 'Opciones de ${item.name}',
                              color: AppColors.bgMid,
                              iconSize: 20,
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.textSecondary,
                              ),
                              onSelected: (action) {
                                if (action == _ItemAction.edit) {
                                  onEdit(entry, index);
                                } else {
                                  onDelete(entry, index);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: _ItemAction.edit,
                                  child: Text(
                                    'Editar',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: _ItemAction.delete,
                                  child: Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

enum _ItemAction { edit, delete }
