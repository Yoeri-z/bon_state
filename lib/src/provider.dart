import 'package:bon_state/src/shared_state.dart';
import 'package:flutter/widgets.dart';
import 'package:nested/nested.dart';

import 'rebuilder.dart';

/// A function that creates an object of type [T].
typedef Create<T extends Object> = T Function(BuildContext context);

/// A function that disposes an object of type [T].
typedef Dispose<T extends Object> =
    void Function(BuildContext context, T value);

/// A [Dispose] function that does nothing.
void _noDispose<T extends Object>(BuildContext context, T value) {}

/// The default [Dispose] function, which disposes a [ChangeNotifier].
void _defaultDispose<T extends Object>(BuildContext context, T value) {
  if (value is ChangeNotifier) {
    value.dispose();
  }
  if (value is SharedState) {
    value.dispose();
  }
}

/// A delegate for providing and disposing an object.
class ProvidingDelegate<T extends Object> {
  /// Creates a [ProvidingDelegate].
  const ProvidingDelegate({required this.create, required this.dispose});

  /// The function that creates the object.
  final Create<T> create;

  /// The function that disposes the object.
  final Dispose<T> dispose;

  @override
  bool operator ==(Object other) =>
      other is ProvidingDelegate<T> &&
      other.runtimeType == runtimeType &&
      other.create == create &&
      other.dispose == dispose;

  @override
  int get hashCode => Object.hash(create, dispose);
}

/// Provides an object to its descendants.
/// If the object is a subclass of[ChangeNotifier], it will be disposed automatically.
class Provider<T extends Object> extends SingleChildStatelessWidget {
  /// Creates a [Provider] that creates an object using the `create` function.
  Provider({
    super.key,
    required Create<T> create,
    Dispose<T>? dispose,
    super.child,
  }) : _delegate = ProvidingDelegate(
         create: create,
         dispose: dispose ?? _defaultDispose,
       );

  /// Creates a [Provider] that provides an existing `value`.
  Provider.value({super.key, required T value, super.child})
    : _delegate = ProvidingDelegate(create: (_) => value, dispose: _noDispose);

  /// The delegate that holds the create and dispose functions.
  final ProvidingDelegate<T> _delegate;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return InheritedProvider(
      delegate: _delegate,
      child: child ?? SizedBox.shrink(),
    );
  }
}

// Combine multiple providers into a flat list
class MultiProvider extends Nested {
  // Combine multiple providers into a flat list
  MultiProvider({
    super.key,
    required List<Provider> providers,
    required Widget child,
  }) : super(children: providers, child: child);
}

/// A widget that provides a [Listenable] and rebuilds when it notifies listeners.
class RebuildingProvider<T extends Listenable> extends StatelessWidget {
  /// Creates a [RebuildingProvider] that creates a [Listenable] using `create`.
  RebuildingProvider({
    super.key,
    required Create<T> create,
    Dispose<T>? dispose,
    required this.builder,
  }) : _delegate = ProvidingDelegate(
         create: create,
         dispose: dispose ?? _defaultDispose,
       );

  /// Creates a [RebuildingProvider] that provides an existing `value`.
  RebuildingProvider.value({super.key, required T value, required this.builder})
    : _delegate = ProvidingDelegate(create: (_) => value, dispose: _noDispose);

  /// The delegate that holds the create and dispose functions.
  final ProvidingDelegate<T> _delegate;

  /// A function that builds a widget tree from a [Listenable].
  final RebuildCallback<T> builder;

  @override
  Widget build(BuildContext context) {
    return InheritedProvider(
      delegate: _delegate,
      child: Rebuilder<T>(builder: builder),
    );
  }
}

/// An [InheritedWidget] that provides an object to its descendants.
class InheritedProvider<T extends Object> extends InheritedWidget {
  /// Creates an [InheritedProvider].
  const InheritedProvider({
    super.key,
    required this.delegate,
    required super.child,
  });

  /// The delegate that holds the create and dispose functions.
  final ProvidingDelegate<T> delegate;

  @override
  InheritedProviderElement<T> createElement() => InheritedProviderElement(this);

  @override
  bool updateShouldNotify(InheritedProvider<T> oldWidget) {
    return false;
  }
}

/// An [Element] for [InheritedProvider].
class InheritedProviderElement<T extends Object> extends InheritedElement {
  /// Creates an [InheritedProviderElement].
  InheritedProviderElement(super.widget);

  /// The delegate that holds the create and dispose functions.
  ProvidingDelegate<T> get delegate =>
      (widget as InheritedProvider<T>).delegate;

  /// The provided object instance.
  T? state;
  bool _isFirstBuild = true;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _isFirstBuild = false;
  }

  @override
  void performRebuild() {
    if (_isFirstBuild) state = delegate.create(this);
    super.performRebuild();
  }

  @override
  void unmount() {
    delegate.dispose(this, state!);
    super.unmount();
  }
}
