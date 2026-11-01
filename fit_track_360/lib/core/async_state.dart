/// Estado de una carga remota (F6): cargando, datos, error o vacio.
///
/// Uso tipico en un view model:
///
/// ```dart
/// AsyncState<List<Workout>> state = const AsyncLoading();
///
/// final widget = state.when(
///   loading: () => const CircularProgressIndicator(),
///   data: (workouts) => WorkoutList(workouts),
///   error: (error, _) => ErrorView(onRetry: load),
///   empty: () => const EmptyView(),
/// );
/// ```
///
/// Al ser `sealed`, tambien se puede usar `switch` exhaustivo:
///
/// ```dart
/// switch (state) {
///   AsyncLoading() => ...,
///   AsyncData(:final data) => ...,
///   AsyncError(:final error) => ...,
///   AsyncEmpty() => ...,
/// }
/// ```
sealed class AsyncState<T> {
  const AsyncState();

  /// Construye [AsyncEmpty] si [data] es una coleccion vacia o null;
  /// en otro caso [AsyncData].
  factory AsyncState.fromData(T? data) {
    if (data == null) return AsyncEmpty<T>();
    if (data is Iterable && data.isEmpty) return AsyncEmpty<T>();
    if (data is Map && data.isEmpty) return AsyncEmpty<T>();
    return AsyncData<T>(data);
  }

  bool get isLoading => this is AsyncLoading<T>;

  /// Los datos si el estado es [AsyncData]; null en cualquier otro caso.
  T? get dataOrNull => switch (this) {
    AsyncData<T>(:final data) => data,
    _ => null,
  };

  /// Resuelve los cuatro casos de forma exhaustiva.
  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace? stackTrace) error,
    required R Function() empty,
  }) {
    return switch (this) {
      AsyncLoading<T>() => loading(),
      AsyncData<T>(data: final value) => data(value),
      AsyncError<T>(error: final e, :final stackTrace) => error(e, stackTrace),
      AsyncEmpty<T>() => empty(),
    };
  }

  /// Igual que [when], pero los casos omitidos caen en [orElse].
  R maybeWhen<R>({
    R Function()? loading,
    R Function(T data)? data,
    R Function(Object error, StackTrace? stackTrace)? error,
    R Function()? empty,
    required R Function() orElse,
  }) {
    return switch (this) {
      AsyncLoading<T>() => loading?.call() ?? orElse(),
      AsyncData<T>(data: final value) => data != null ? data(value) : orElse(),
      AsyncError<T>(error: final e, :final stackTrace) =>
        error != null ? error(e, stackTrace) : orElse(),
      AsyncEmpty<T>() => empty?.call() ?? orElse(),
    };
  }
}

/// La peticion esta en curso.
final class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();

  @override
  bool operator ==(Object other) => other is AsyncLoading<T>;

  @override
  int get hashCode => (AsyncLoading<T>).hashCode;

  @override
  String toString() => 'AsyncLoading<$T>()';
}

/// La peticion termino con datos para mostrar.
final class AsyncData<T> extends AsyncState<T> {
  const AsyncData(this.data);

  final T data;

  @override
  bool operator ==(Object other) => other is AsyncData<T> && other.data == data;

  @override
  int get hashCode => Object.hash(AsyncData<T>, data);

  @override
  String toString() => 'AsyncData<$T>($data)';
}

/// La peticion fallo. [stackTrace] es opcional.
final class AsyncError<T> extends AsyncState<T> {
  const AsyncError(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      other is AsyncError<T> && other.error == error;

  @override
  int get hashCode => Object.hash(AsyncError<T>, error);

  @override
  String toString() => 'AsyncError<$T>($error)';
}

/// La peticion termino bien pero no hay nada que mostrar.
final class AsyncEmpty<T> extends AsyncState<T> {
  const AsyncEmpty();

  @override
  bool operator ==(Object other) => other is AsyncEmpty<T>;

  @override
  int get hashCode => (AsyncEmpty<T>).hashCode;

  @override
  String toString() => 'AsyncEmpty<$T>()';
}
