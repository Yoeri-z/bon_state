import 'package:flutter/foundation.dart';

/// A counter part to flutters [State] that is shareable and not tied to the widget tree.
abstract class SharedState implements Listenable {
  final _listeners = Set<VoidCallback>.identity();
  bool _debugLocked = false;
  bool _notifying = true;

  void _checkNotLocked() {
    if (_debugLocked && kDebugMode) {
      // ignore: avoid_print
      print('Attemped to interact with notifier after it was disposed');
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _checkNotLocked();
    _listeners.remove(listener);
  }

  @override
  void addListener(VoidCallback listener) {
    _checkNotLocked();
    _listeners.add(listener);
  }

  void setState(VoidCallback change) {
    change();
    _notifying = true;
    for (var listener in _listeners) {
      listener();
    }
    _notifying = false;
  }

  void dispose() {
    assert(
      _notifying == false,
      'Called dispose during notify phase, this is likely to cause errors',
    );
    _listeners.clear();
    _debugLocked = true;
  }
}
