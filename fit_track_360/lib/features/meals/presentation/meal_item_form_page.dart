import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/ds_text_field.dart';
import '../domain/macros.dart';
import '../domain/meal_item.dart';
import 'meals_view_model.dart';

/// Edición de nombre, porción y macros de un MealItem ya guardado.
class MealItemFormPage extends StatefulWidget {
  const MealItemFormPage({super.key, required this.item, required this.onSave});

  final MealItem item;
  final Future<MealMutationResult> Function(MealItem item) onSave;

  @override
  State<MealItemFormPage> createState() => _MealItemFormPageState();
}

class _MealItemFormPageState extends State<MealItemFormPage> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _portion = TextEditingController(
    text: _number(widget.item.servingG),
  );
  late final _kcal = TextEditingController(
    text: _number(widget.item.macros.kcal),
  );
  late final _protein = TextEditingController(
    text: _number(widget.item.macros.proteinG),
  );
  late final _carbs = TextEditingController(
    text: _number(widget.item.macros.carbsG),
  );
  late final _fat = TextEditingController(
    text: _number(widget.item.macros.fatG),
  );

  late double _lastPortion = widget.item.servingG;

  bool _saving = false;
  String? _error;

  static String _number(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }

  double? _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  double? _optionalMacro(TextEditingController controller) =>
      controller.text.trim().isEmpty ? 0 : _parse(controller);

  @override
  void dispose() {
    for (final controller in [_name, _portion, _kcal, _protein, _carbs, _fat]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/app/comidas');
    }
  }

  void _onPortionChanged(String _) {
    final grams = _parse(_portion);
    if (grams == null || !grams.isFinite || grams <= 0 || _lastPortion <= 0) {
      return;
    }
    final ratio = grams / _lastPortion;
    for (final controller in [_kcal, _protein, _carbs, _fat]) {
      final value = _parse(controller);
      if (value == null || !value.isFinite) continue;
      controller.text = _number(value * ratio);
    }
    _lastPortion = grams;
    setState(() => _error = null);
  }

  String? _validationError({
    required String name,
    required double? portion,
    required double? kcal,
    required double? protein,
    required double? carbs,
    required double? fat,
  }) {
    if (name.isEmpty) return 'Escribe el nombre del alimento';
    if (portion == null || !portion.isFinite || portion <= 0) {
      return 'La porción debe ser un número mayor que cero';
    }
    if (kcal == null || !kcal.isFinite || kcal < 0) {
      return 'Las calorías deben ser un número no negativo';
    }
    for (final (label, value) in [
      ('proteína', protein),
      ('carbohidratos', carbs),
      ('grasa', fat),
    ]) {
      if (value == null || !value.isFinite || value < 0) {
        return 'El valor de $label debe ser un número no negativo';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final portion = _parse(_portion);
    final kcal = _parse(_kcal);
    final protein = _optionalMacro(_protein);
    final carbs = _optionalMacro(_carbs);
    final fat = _optionalMacro(_fat);
    final error = _validationError(
      name: name,
      portion: portion,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final item = MealItem(
      id: widget.item.id,
      fdcId: widget.item.fdcId,
      name: name,
      servingG: portion!,
      macros: Macros(
        kcal: kcal!,
        proteinG: protein!,
        carbsG: carbs!,
        fatG: fat!,
      ),
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.onSave(item);
    if (!mounted) return;
    if (result == MealMutationResult.success ||
        result == MealMutationResult.notFound) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() {
      _saving = false;
      _error = result == MealMutationResult.busy
          ? 'Espera a que termine la operación en curso'
          : 'No se pudo guardar el alimento. Intenta de nuevo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    const numeric = TextInputType.numberWithOptions(decimal: true);
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Volver',
                  onPressed: _saving ? null : _back,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Editar alimento',
                    style: AppTypography.pageTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DsTextField(
              key: const Key('edit-name'),
              controller: _name,
              label: 'Nombre',
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.sm),
            DsTextField(
              key: const Key('edit-portion'),
              controller: _portion,
              label: 'Porción (g)',
              keyboardType: numeric,
              enabled: !_saving,
              onChanged: _onPortionChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            DsTextField(
              key: const Key('edit-kcal'),
              controller: _kcal,
              label: 'Calorías (kcal)',
              keyboardType: numeric,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.sm),
            DsTextField(
              key: const Key('edit-protein'),
              controller: _protein,
              label: 'Proteína (g)',
              keyboardType: numeric,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.sm),
            DsTextField(
              key: const Key('edit-carbs'),
              controller: _carbs,
              label: 'Carbohidratos (g)',
              keyboardType: numeric,
              enabled: !_saving,
            ),
            const SizedBox(height: AppSpacing.sm),
            DsTextField(
              key: const Key('edit-fat'),
              controller: _fat,
              label: 'Grasa (g)',
              keyboardType: numeric,
              enabled: !_saving,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.body.copyWith(color: AppColors.dangerText),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_saving) ...[
              const Center(
                child: CircularProgressIndicator(color: AppColors.accentWhite),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            PrimaryButton(
              label: _saving ? 'Guardando...' : 'Guardar cambios',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
