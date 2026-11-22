import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../exercises/data/exercise.dart';
import '../../exercises/data/exercises_api.dart';
import '../domain/workout_session_draft.dart';

/// Editor de series basado en identificadores reales del catálogo.
class SessionExerciseEditor extends StatefulWidget {
  const SessionExerciseEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.api,
  });
  final WorkoutSessionDraft? initial;
  final void Function(List<PlannedExercise>, List<PlannedSet>) onChanged;
  final ExercisesApi? api;
  @override
  State<SessionExerciseEditor> createState() => _SessionExerciseEditorState();
}

class _Block {
  _Block(this.id, this.name, this.sets);
  final String id;
  final String name;
  final List<PlannedSet> sets;
  int revision = 0;
}

class _SessionExerciseEditorState extends State<SessionExerciseEditor> {
  ApiClient? _client;
  late final ExercisesApi _api =
      widget.api ?? ExercisesApi(_client = ApiClient());
  final List<_Block> _blocks = [];
  @override
  void initState() {
    super.initState();
    final draft = widget.initial;
    if (draft == null) return;
    for (final exercise in draft.exercises) {
      final exact = draft.sets
          ?.where((s) => s.exerciseId == exercise.exerciseId)
          .toList();
      _blocks.add(
        _Block(
          exercise.exerciseId,
          exercise.exerciseName.isEmpty
              ? 'Ejercicio ${exercise.exerciseId}'
              : exercise.exerciseName,
          exact != null && exact.isNotEmpty
              ? exact
              : List.generate(
                  exercise.targetSets,
                  (i) => PlannedSet(
                    exerciseId: exercise.exerciseId,
                    order: i + 1,
                    weightKg: 0,
                    reps: exercise.targetReps,
                  ),
                ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  void _changed() {
    var order = 0;
    widget.onChanged(
      [
        for (var i = 0; i < _blocks.length; i++)
          PlannedExercise(
            exerciseId: _blocks[i].id,
            exerciseName: _blocks[i].name,
            position: i,
            targetSets: _blocks[i].sets.length,
            targetReps: _blocks[i].sets.first.reps,
          ),
      ],
      [
        for (final block in _blocks)
          for (final set in block.sets)
            PlannedSet(
              exerciseId: set.exerciseId,
              order: ++order,
              weightKg: set.weightKg,
              reps: set.reps,
            ),
      ],
    );
  }

  Future<void> _add() async {
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (_) => _ExercisePicker(api: _api),
    );
    if (!mounted || exercise == null) return;
    setState(() {
      _blocks.add(
        _Block(exercise.id, exercise.nameEs ?? exercise.name, [
          PlannedSet(exerciseId: exercise.id, order: 1, weightKg: 0, reps: 10),
        ]),
      );
      _changed();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in _blocks)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(block.name)),
                    IconButton(
                      tooltip: 'Quitar ejercicio',
                      onPressed: () => setState(() {
                        _blocks.remove(block);
                        _changed();
                      }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Text(
                  '${block.sets.length} series × ${block.sets.first.reps} reps',
                ),
                for (var i = 0; i < block.sets.length; i++)
                  Row(
                    children: [
                      Text('Serie ${i + 1}'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(
                            '${identityHashCode(block)}-${block.revision}-$i-reps',
                          ),
                          initialValue: '${block.sets[i].reps}',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Reps'),
                          onChanged: (v) {
                            final n = int.tryParse(v) ?? 0;
                            final old = block.sets[i];
                            block.sets[i] = PlannedSet(
                              exerciseId: old.exerciseId,
                              order: old.order,
                              weightKg: old.weightKg,
                              reps: n,
                            );
                            _changed();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(
                            '${identityHashCode(block)}-${block.revision}-$i-weight',
                          ),
                          initialValue: '${block.sets[i].weightKg}',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Peso kg',
                          ),
                          onChanged: (v) {
                            final n = double.tryParse(v) ?? -1;
                            final old = block.sets[i];
                            block.sets[i] = PlannedSet(
                              exerciseId: old.exerciseId,
                              order: old.order,
                              weightKg: n,
                              reps: old.reps,
                            );
                            _changed();
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar serie',
                        onPressed: block.sets.length == 1
                            ? null
                            : () => setState(() {
                                block.sets.removeAt(i);
                                block.revision++;
                                _changed();
                              }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                TextButton(
                  onPressed: () => setState(() {
                    final last = block.sets.last;
                    block.sets.add(
                      PlannedSet(
                        exerciseId: block.id,
                        order: block.sets.length + 1,
                        weightKg: last.weightKg,
                        reps: last.reps,
                      ),
                    );
                    _changed();
                  }),
                  child: const Text('Añadir serie'),
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Añadir ejercicio'),
      ),
    ],
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.api});
  final ExercisesApi api;
  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  late Future<ExercisePage> _page;
  final _search = TextEditingController();
  int _number = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _page = widget.api.fetchPage(query: _search.text, page: _number);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Elegir ejercicio'),
    content: SizedBox(
      width: 400,
      height: 420,
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Buscar',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {
                  _number = 1;
                  _load();
                }),
              ),
            ),
            onSubmitted: (_) => setState(() {
              _number = 1;
              _load();
            }),
          ),
          Expanded(
            child: FutureBuilder<ExercisePage>(
              future: _page,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('No se pudo cargar. Reintentar'),
                  );
                }
                final page = snapshot.data!;
                if (page.items.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          for (final e in page.items)
                            ListTile(
                              title: Text(e.nameEs ?? e.name),
                              onTap: () => Navigator.pop(context, e),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: page.hasPrevious
                              ? () => setState(() {
                                  _number--;
                                  _load();
                                })
                              : null,
                          child: const Text('Anterior'),
                        ),
                        Text('${page.page} / ${page.totalPages}'),
                        TextButton(
                          onPressed: page.hasNext
                              ? () => setState(() {
                                  _number++;
                                  _load();
                                })
                              : null,
                          child: const Text('Siguiente'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
    ],
  );
}
