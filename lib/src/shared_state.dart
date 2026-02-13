import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef AsyncCallback<T> = Future<T> Function();

abstract class AsyncComputation<T> {
  const AsyncComputation();

  Future<T> call();
}

/// A [Shared] is a simple wrapper around a value that allows listeners to be notified when the value changes.
class Shared<TValue> implements Listenable {
  Shared(TValue initialValue) : _value = initialValue;

  /// The current value of the [Shared] instance.
  TValue get value => _value;

  TValue _value;

  final _listeners = HashSet<VoidCallback>();

  bool _debugDisposed = false;

  void set(TValue value) {
    if (_debugDisposed && kDebugMode) {
      debugPrint('Called [set] in $runtimeType after the object was disposed.');
    }
    _value = value;
    _notify();
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Removes all listeners from the object and marks it as disposed.
  ///
  /// This will cause any further state updates to print warnings in the console in debug mode.
  @mustCallSuper
  void dispose() {
    _listeners.clear();
    _debugDisposed = true;
  }
}

/// A [Shared] that wraps an [AsyncSnapshot] and provides convenient getters for the snapshot's state.
abstract class SharedAsync<TValue> extends Shared<AsyncSnapshot<TValue>> {
  SharedAsync(super.initialValue);

  bool get hasError => value.hasError;
  Object? get error => value.error;
  StackTrace? get stackTrace => value.stackTrace;
  bool get hasData => value.hasData;
  TValue? get data => value.data;
  TValue get requireData => value.requireData;
}

/// A [Shared] that wraps a [Future] and updates its state when the future completes.
class SharedFuture<TValue> extends SharedAsync<TValue> {
  /// Creates a [SharedFuture] that wraps the future returned by [computation].
  SharedFuture(this.computation) : super(.waiting()) {
    _doComputation();
  }

  /// The function that computes the future this [SharedFuture] instance wraps.
  final Future<TValue> Function() computation;

  void _doComputation() async {
    try {
      final value = await computation();
      set(.withData(.done, value));
    } catch (e, st) {
      set(.withError(.done, e, st));
    }
  }

  /// Recomputes the future and updates the state when the future completes.
  void refresh() {
    _doComputation();
  }

  /// Resets the state to waiting and fetches the data again.
  void reload() {
    set(.waiting());
    _doComputation();
  }

  /// Do a computation and defer the error handling to the [SharedFuture] instance.
  Future<void> defer(
    AsyncCallback<void> computation, {
    bool refresh = false,
  }) async {
    try {
      await computation();
    } catch (e, st) {
      set(.withError(.done, e, st));
    }
  }

  /// Do a computation and write the result to the [SharedFuture] instance.
  Future<void> write(AsyncCallback<TValue> computation) async {
    try {
      final value = await computation();
      set(.withData(.done, value));
    } catch (e, st) {
      set(.withError(.done, e, st));
    }
  }
}

/// A [Shared] that wraps a [Stream] and updates its state when the stream emits new values or errors.
class SharedStream<TValue> extends SharedAsync<TValue> {
  SharedStream(this.stream) : super(.waiting()) {
    subscribe();
  }

  /// The stream this [SharedStream] instance wraps
  final Stream<TValue> stream;
  StreamSubscription<TValue>? _subscription;

  bool get isSubscribed => _subscription != null;
  bool get isPaused => _subscription?.isPaused ?? false;

  /// Pauses the subscription. Buffered events (if supported by the stream)
  /// will be delivered when [resume] is called.
  void pause() {
    _subscription?.pause();
  }

  /// Resume the subscription to the stream, this will release all events that happened after [pause].
  void resume() {
    _subscription?.resume();
  }

  ///Subscribe to the stream if there is no active subscription yet
  void subscribe() {
    _subscription ??= stream.listen(
      (data) => set(.withData(.active, data)),
      onError: (e, st) => set(.withError(.active, e, st)),
      onDone: () {
        _handleSubscriptionClose();
      },
    );
  }

  ///unsubscribe from the stream if a subscription is active, this stops the SharedStream notifying listeners
  void unsubscribe() {
    _subscription?.cancel();
    _subscription = null;

    _handleSubscriptionClose();
  }

  void _handleSubscriptionClose() {
    if (value.hasData) {
      set(.withData(.done, value.requireData));
    } else if (value.hasError) {
      set(.withError(.done, value.error!, value.stackTrace!));
    } else {
      set(.nothing());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;

    super.dispose();
  }
}

/// A [Shared] that computes its value based on other [Listenable]s and updates when any of the dependencies change.
class SharedComputed<T> extends Shared<T> {
  SharedComputed(this.compute, {required this.deps}) : super(compute()) {
    for (final d in deps) {
      d.addListener(_recompute);
    }
  }

  final T Function() compute;
  final List<Listenable> deps;

  void _recompute() => set(compute());

  @override
  void dispose() {
    for (final d in deps) {
      d.removeListener(_recompute);
    }
    super.dispose();
  }
}
