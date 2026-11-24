import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../workouts/domain/workout_session_draft.dart';
import '../../workouts/presentation/tracker_session_page.dart';
import '../domain/routine.dart';
import 'start_session_view_model.dart';

/// Ruta del tracker; recibe [TrackerSessionArgs] con el borrador en `extra`.
const workoutSessionRoute = workoutTrackerRoute;

/// Acción reutilizable «Entrenar ahora» para el detalle o editor de rutina.
///
/// Por omisión abre el tracker con los ejercicios y series de la rutina.
class StartSessionButton extends StatefulWidget {
  const StartSessionButton({
    super.key,
    required this.routine,
    this.onStarted,
    this.viewModel,
  });

  final Routine routine;
  final ValueChanged<WorkoutSessionDraft>? onStarted;
  final StartSessionViewModel? viewModel;

  @override
  State<StartSessionButton> createState() => _StartSessionButtonState();
}

class _StartSessionButtonState extends State<StartSessionButton> {
  late final StartSessionViewModel _viewModel =
      widget.viewModel ?? StartSessionViewModel();

  @override
  void didUpdateWidget(covariant StartSessionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routine != widget.routine && !widget.routine.isEmpty) {
      _viewModel.clearError();
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _viewModel.dispose();
    super.dispose();
  }

  void _start() {
    final draft = _viewModel.start(widget.routine);
    if (draft == null) return;
    final onStarted = widget.onStarted;
    if (onStarted != null) {
      onStarted(draft);
    } else {
      context.push(
        workoutSessionRoute,
        extra: TrackerSessionArgs(draft: draft),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: 'Entrenar ahora', onPressed: _start),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _viewModel.errorMessage!,
              style: AppTypography.body.copyWith(color: AppColors.dangerText),
            ),
          ],
        ],
      ),
    );
  }
}
