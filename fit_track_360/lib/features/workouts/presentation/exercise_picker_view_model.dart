import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../auth/data/auth_api.dart';
import '../../exercises/data/exercise.dart';
import '../../exercises/data/exercises_api.dart';

/// ViewModel del selector de ejercicios: búsqueda con espera corta y carga
/// incremental (sin «Anterior/Siguiente»).
class ExercisePickerViewModel extends ChangeNotifier {
  ExercisePickerViewModel({
    required this._api,
    this.debounce = const Duration(milliseconds: 350),
    this.pageSize = ExercisesApi.defaultPageSize,
  });

  final ExercisesApi _api;
  final Duration debounce;
  final int pageSize;

  AsyncState<List<Exercise>> _state = const AsyncLoading();
  final List<Exercise> _items = [];
  String _query = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _loadMoreError;
  int _requestId = 0;
  Timer? _debounceTimer;
  bool _disposed = false;

  AsyncState<List<Exercise>> get state => _state;
  String get query => _query;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  String? get loadMoreError => _loadMoreError;

  /// Carga la primera página de la búsqueda actual.
  Future<void> load() async {
    final requestId = ++_requestId;
    _items.clear();
    _page = 0;
    _hasMore = true;
    _loadMoreError = null;
    _loadingMore = false;
    _state = const AsyncLoading();
    _notify();
    try {
      final page = await _api.fetchPage(
        query: _query,
        page: 1,
        pageSize: pageSize,
      );
      if (_disposed || requestId != _requestId) return;
      _items.addAll(page.items);
      _page = page.page;
      _hasMore = page.hasNext;
      _state = AsyncState.fromData(List.unmodifiable(_items));
    } catch (error, stackTrace) {
      if (_disposed || requestId != _requestId) return;
      _state = AsyncError(error, stackTrace);
    }
    _notify();
  }

  /// Cambia el texto de búsqueda y recarga tras [debounce].
  void search(String value) {
    final next = value.trim();
    if (next == _query) return;
    _query = next;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(load()));
  }

  /// Pide la siguiente página si hay más y no hay otra en curso.
  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _state is! AsyncData<List<Exercise>>) {
      return;
    }
    final requestId = _requestId;
    _loadingMore = true;
    _loadMoreError = null;
    _notify();
    try {
      final page = await _api.fetchPage(
        query: _query,
        page: _page + 1,
        pageSize: pageSize,
      );
      if (_disposed || requestId != _requestId) return;
      _items.addAll(page.items);
      _page = page.page;
      _hasMore = page.hasNext && page.items.isNotEmpty;
      _state = AsyncData(List.unmodifiable(_items));
    } catch (error) {
      if (_disposed || requestId != _requestId) return;
      _loadMoreError = error is AuthApiException
          ? error.message
          : 'No se pudieron cargar más ejercicios.';
    } finally {
      if (!_disposed && requestId == _requestId) _loadingMore = false;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
