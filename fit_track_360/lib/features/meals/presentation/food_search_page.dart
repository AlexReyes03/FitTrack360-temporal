import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../domain/food_item.dart';
import '../domain/food_search_repository.dart';
import '../domain/macros.dart';
import '../domain/meal_type.dart';
import 'food_search_view_model.dart';
import 'meal_format.dart';

/// Vista 8: búsqueda USDA (vía proxy), porción, destino y captura manual.
/// Devuelve con `Navigator.pop` la NewMealEntry a agregar.
class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key, required this.repository, this.now});

  final FoodSearchRepository repository;
  final DateTime Function()? now;

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  late final FoodSearchViewModel _viewModel = FoodSearchViewModel(
    widget.repository,
  )..addListener(_onChange);

  final _query = TextEditingController();
  final _portion = TextEditingController(text: '100');
  final _name = TextEditingController();
  final _manualPortion = TextEditingController(text: '100');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  bool _manual = false;
  String? _manualError;

  DateTime _now() => (widget.now ?? DateTime.now)();

  void _onChange() {
    if (_viewModel.sessionExpired && mounted) context.go('/login');
  }

  @override
  void dispose() {
    _viewModel.dispose();
    for (final controller in [
      _query,
      _portion,
      _name,
      _manualPortion,
      _kcal,
      _protein,
      _carbs,
      _fat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _addSelected() {
    final entry = _viewModel.buildEntry(_now());
    if (entry != null) Navigator.of(context).pop(entry);
  }

  void _addManual() {
    final kcal = _parse(_kcal);
    final protein = _parse(_protein) ?? 0;
    final carbs = _parse(_carbs) ?? 0;
    final fat = _parse(_fat) ?? 0;
    final entry = _viewModel.buildManualEntry(
      name: _name.text,
      portionG: _parse(_manualPortion),
      macros: kcal == null
          ? null
          : Macros(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat),
      eatenAt: _now(),
    );
    if (entry == null) {
      setState(
        () => _manualError =
            'Revisa nombre, porción y calorías (valores no negativos)',
      );
      return;
    }
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    );
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('Agregar alimento', style: AppTypography.pageTitle),
              const SizedBox(height: AppSpacing.sm),
              Text('Comida de destino', style: AppTypography.body),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final type in MealType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _viewModel.destination == type,
                      onSelected: (_) => _viewModel.setDestination(type),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (!_manual) ..._searchSection(secondary),
              if (_manual) ..._manualSection(secondary),
              const SizedBox(height: AppSpacing.sm),
              // Con el aviso de error o sin resultados, ese aviso ya ofrece la captura manual.
              if (_manual || !_viewModel.offersManualCapture)
                TextButton(
                  onPressed: () => setState(() {
                    _manual = !_manual;
                    _manualError = null;
                  }),
                  child: Text(
                    _manual ? 'Volver a la búsqueda' : 'Captura manual',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _searchSection(TextStyle secondary) {
    final selected = _viewModel.selected;
    return [
      DsTextField(
        key: const Key('food-search'),
        controller: _query,
        label: 'Búsqueda',
        hint: 'En inglés, por ejemplo «oats»',
        onChanged: _viewModel.onQueryChanged,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text('USDA registra los alimentos en inglés.', style: secondary),
      const SizedBox(height: AppSpacing.sm),
      if (_viewModel.results case final results?)
        results.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentWhite),
          ),
          data: (items) => Column(
            children: [
              for (final food in items) _resultTile(food, selected, secondary),
            ],
          ),
          error: (_, _) => _fallback(
            'La búsqueda no está disponible. ¿Quieres capturarlo a mano?',
          ),
          empty: () => _fallback('Sin resultados. ¿Quieres capturarlo a mano?'),
        ),
      if (selected != null) ...[
        const SizedBox(height: AppSpacing.sm),
        DsTextField(
          key: const Key('food-portion'),
          controller: _portion,
          label: 'Porción (g)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _viewModel.setPortion(_parse(_portion) ?? 0),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(formatMacros(_viewModel.selectedMacros), style: secondary),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: 'Agregar a ${_viewModel.destination.label}',
          onPressed: _viewModel.buildEntry(_now()) == null
              ? null
              : _addSelected,
        ),
      ],
    ];
  }

  Widget _resultTile(FoodItem food, FoodItem? selected, TextStyle secondary) {
    final isSelected = identical(food, selected);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GestureDetector(
        onTap: () => _viewModel.select(food),
        child: GlassSurface(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSelected ? '✓ ${food.name}' : food.name,
                style: AppTypography.body,
              ),
              Text(
                '${formatAmount(food.baseServingG)} g · '
                '${formatMacros(food.macros)}',
                style: secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(String message) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: AppTypography.body),
      TextButton(
        key: const Key('open-manual'),
        onPressed: () => setState(() {
          _manual = true;
          _name.text = _query.text.trim();
        }),
        child: const Text(
          'Captura manual',
          style: TextStyle(color: AppColors.accentWhite),
        ),
      ),
    ],
  );

  List<Widget> _manualSection(TextStyle secondary) {
    const numeric = TextInputType.numberWithOptions(decimal: true);
    return [
      Text('Captura manual', style: AppTypography.body),
      const SizedBox(height: AppSpacing.xs),
      Text('Captura los valores de la porción que comiste.', style: secondary),
      const SizedBox(height: AppSpacing.sm),
      DsTextField(
        key: const Key('manual-name'),
        controller: _name,
        label: 'Nombre',
      ),
      const SizedBox(height: AppSpacing.sm),
      DsTextField(
        key: const Key('manual-portion'),
        controller: _manualPortion,
        label: 'Porción (g)',
        keyboardType: numeric,
      ),
      const SizedBox(height: AppSpacing.sm),
      DsTextField(
        key: const Key('manual-kcal'),
        controller: _kcal,
        label: 'Calorías (kcal)',
        keyboardType: numeric,
      ),
      const SizedBox(height: AppSpacing.sm),
      DsTextField(
        controller: _protein,
        label: 'Proteína (g)',
        keyboardType: numeric,
      ),
      const SizedBox(height: AppSpacing.sm),
      DsTextField(
        controller: _carbs,
        label: 'Carbohidratos (g)',
        keyboardType: numeric,
      ),
      const SizedBox(height: AppSpacing.sm),
      DsTextField(controller: _fat, label: 'Grasa (g)', keyboardType: numeric),
      if (_manualError != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          _manualError!,
          style: AppTypography.body.copyWith(color: AppColors.dangerText),
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      PrimaryButton(
        label: 'Agregar a ${_viewModel.destination.label}',
        onPressed: _addManual,
      ),
    ];
  }
}
