import 'package:flutter/material.dart';

import '../../../core/resultado.dart';
import '../data/comidas_repositorio_falso.dart';
import '../domain/comida_demo.dart';

/// Pantalla de nivelacion T3: lista de comidas con tres estados via [Resultado].
///
/// Solo usa StatefulWidget y setState (sin Provider/Bloc/Riverpod).
class ListaTresEstadosPage extends StatefulWidget {
  const ListaTresEstadosPage({super.key, this.repositorio});

  final ComidasRepositorioFalso? repositorio;

  @override
  State<ListaTresEstadosPage> createState() => _ListaTresEstadosPageState();
}

class _ListaTresEstadosPageState extends State<ListaTresEstadosPage> {
  late final ComidasRepositorioFalso _repo =
      widget.repositorio ?? ComidasRepositorioFalso();

  // IA: estructura de pantalla con Resultado y switch exhaustivo (ajustada).
  Resultado<List<ComidaDemo>> _estado = const Cargando();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _estado = const Cargando());
    try {
      final comidas = await _repo.obtener();
      if (!mounted) return;
      setState(() => _estado = Exito(comidas));
    } catch (_) {
      if (!mounted) return;
        setState(
        () => _estado = const Error(
          'No se pudieron cargar las comidas.\n'
          'Revisa tu conexion e intenta de nuevo.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nivelacion T3 · Comidas')),
      body: switch (_estado) {
        Cargando() => const Center(child: CircularProgressIndicator()),
        Exito(:final dato) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dato.length,
          itemBuilder: (context, index) {
            final comida = dato[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(comida.nombre),
                subtitle: Text('${comida.tipo} · ${comida.calorias} kcal'),
                leading: CircleAvatar(child: Text('${index + 1}')),
              ),
            );
          },
        ),
        Error(:final mensaje) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _cargar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      },
    );
  }
}
