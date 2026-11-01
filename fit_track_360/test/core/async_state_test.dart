import 'package:fit_track_360/core/async_state.dart';
import 'package:flutter_test/flutter_test.dart';

String describe(AsyncState<List<int>> state) => state.when(
  loading: () => 'cargando',
  data: (items) => 'datos:${items.length}',
  error: (error, _) => 'error:$error',
  empty: () => 'vacio',
);

void main() {
  group('AsyncState.when', () {
    test('resuelve los cuatro casos', () {
      expect(describe(const AsyncLoading()), 'cargando');
      expect(describe(const AsyncData([1, 2, 3])), 'datos:3');
      expect(describe(const AsyncError('timeout')), 'error:timeout');
      expect(describe(const AsyncEmpty()), 'vacio');
    });

    test('AsyncError conserva el stack trace opcional', () {
      final trace = StackTrace.current;
      final state = AsyncError<int>('falla', trace);

      final captured = state.when<StackTrace?>(
        loading: () => null,
        data: (_) => null,
        error: (_, stackTrace) => stackTrace,
        empty: () => null,
      );

      expect(captured, same(trace));
      expect(const AsyncError<int>('falla').stackTrace, isNull);
    });
  });

  group('switch exhaustivo', () {
    test('cubre las cuatro variantes sin default', () {
      String label(AsyncState<String> state) => switch (state) {
        AsyncLoading() => 'L',
        AsyncData(:final data) => 'D:$data',
        AsyncError(:final error) => 'E:$error',
        AsyncEmpty() => 'V',
      };

      expect(label(const AsyncLoading()), 'L');
      expect(label(const AsyncData('hola')), 'D:hola');
      expect(label(const AsyncError('x')), 'E:x');
      expect(label(const AsyncEmpty()), 'V');
    });
  });

  group('maybeWhen', () {
    test('usa orElse en los casos omitidos', () {
      String onlyData(AsyncState<int> s) =>
          s.maybeWhen(data: (n) => 'n=$n', orElse: () => 'otro');

      expect(onlyData(const AsyncData(5)), 'n=5');
      expect(onlyData(const AsyncLoading()), 'otro');
      expect(onlyData(const AsyncError('e')), 'otro');
      expect(onlyData(const AsyncEmpty()), 'otro');
    });
  });

  group('AsyncState.fromData', () {
    test('lista vacia o null produce AsyncEmpty', () {
      expect(AsyncState<List<int>>.fromData(const []), isA<AsyncEmpty>());
      expect(AsyncState<List<int>>.fromData(null), isA<AsyncEmpty>());
      expect(
        AsyncState<Map<String, int>>.fromData(const {}),
        isA<AsyncEmpty>(),
      );
    });

    test('datos con contenido producen AsyncData', () {
      final state = AsyncState<List<int>>.fromData(const [7]);
      expect(state, const AsyncData<List<int>>([7]));
      expect(state.dataOrNull, [7]);
    });
  });

  test('helpers isLoading y dataOrNull', () {
    expect(const AsyncLoading<int>().isLoading, isTrue);
    expect(const AsyncData(1).isLoading, isFalse);
    expect(const AsyncError<int>('e').dataOrNull, isNull);
  });
}
