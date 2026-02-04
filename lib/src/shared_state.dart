import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class Shared<TValue> implements Listenable {
  Shared(TValue initialValue) : _value = initialValue;

  TValue get value => _value;

  TValue _value;

  final listeners = HashSet<VoidCallback>();

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
    listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners.remove(listener);
  }

  void _notify() {
    for (var listener in listeners) {
      listener();
    }
  }

  @mustCallSuper
  /// Removes all listeners from the object and marks it as disposed.
  ///
  /// This will cause any further state updates to print warnings in the console in debug mode.
  void dispose() {
    listeners.clear();
    _debugDisposed = true;
  }
}

class SharedFuture<TValue> extends Shared<AsyncSnapshot<TValue>> {
  SharedFuture(this.computation) : super(.waiting()) {
    _doComputation();
  }

  final Future<TValue> Function() computation;

  bool get hasError => value.hasError;
  Object? get error => value.error;
  StackTrace? get stackTrace => value.stackTrace;
  bool get hasData => value.hasData;
  TValue? get data => value.data;
  TValue get requireData => value.requireData;

  void _doComputation() {
    computation().then(
      (value) => set(.withData(.done, value)),
      onError: (e, st) => set(.withError(.done, e, st)),
    );
  }

  void refresh() {
    _doComputation();
  }

  void reload() {
    set(.waiting());
    _doComputation();
  }
}

class SharedStream<TValue> extends Shared<AsyncSnapshot<TValue>> {
  SharedStream(this.stream) : super(.waiting()) {
    subscribe();
  }

  /// The stream this [SharedStream] instance wraps
  final Stream<TValue> stream;
  StreamSubscription<TValue>? _subscription;

  bool get hasError => value.hasError;
  Object? get error => value.error;
  StackTrace? get stackTrace => value.stackTrace;
  bool get hasData => value.hasData;
  TValue? get data => value.data;
  TValue get requireData => value.requireData;

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
