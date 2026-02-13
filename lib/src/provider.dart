import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:nested/nested.dart';

import 'shared_state.dart';
import 'rebuilder.dart';

/// A function that creates an object of type [T].
typedef Create<T extends Object> = T Function(BuildContext context);

/// A function that disposes an object of type [T].
typedef Dispose<T extends Object> =
    void Function(BuildContext context, T value);

typedef Guard<T extends Object> =
    Widget Function(
      BuildContext context,
      T obj,
      Widget Function() childBuilder,
    );

/// A [Dispose] function that does nothing.
void _noDispose<T extends Object>(BuildContext context, T value) {}

/// The default [Dispose] function, which disposes a [ChangeNotifier].
void _defaultDispose<T extends Object>(BuildContext context, T value) {
  if (value is ChangeNotifier) {
    value.dispose();
  }
  if (value is Shared) {
    value.dispose();
  }
}

/// A delegate for providing and disposing an object.
class ProviderConfig<T extends Object> with Diagnosticable {
  /// Creates a [ProviderConfig].
  const ProviderConfig({
    this.create,
    this.value,
    required this.lazy,
    required this.dispose,
  }) : assert(
         create != null || value != null,
         'Either create or value must be provided',
       );

  /// The function that creates the object.
  final Create<T>? create;

  /// The object if it was already created.
  final T? value;

  /// Whether the object should be fetched lazily or not.
  final bool lazy;

  /// The function that disposes the object.
  final Dispose<T> dispose;

  bool get manageLifecycle => value == null;

  // Create and dispose do not participate in the equality.
  // They are usually a lambda function which is treated as a new instance every time,
  // eventhough its often sementically the same.
  @override
  bool operator ==(Object other) =>
      other is ProviderConfig<T> &&
      other.runtimeType == runtimeType &&
      other.value == value &&
      other.lazy == lazy;

  @override
  int get hashCode => Object.hash(value, lazy);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(DiagnosticsProperty('lazy', lazy));
    properties.add(DiagnosticsProperty('manageLifecycle', manageLifecycle));
    properties.add(
      DiagnosticsProperty<T>('value', value, ifNull: 'depends on create'),
    );

    super.debugFillProperties(properties);
  }
}

/// Provides an object to its descendants.
/// If the object is a subclass of[ChangeNotifier], it will be disposed automatically.
class Provider<T extends Object> extends SingleChildStatelessWidget {
  /// Creates a [Provider] that creates an object using the `create` function.
  Provider({
    super.key,
    required Create<T> create,
    bool lazy = true,
    Dispose<T>? dispose,
    super.child,
  }) : _config = ProviderConfig(
         create: create,
         lazy: lazy,
         dispose: dispose ?? _defaultDispose,
       );

  /// Creates a [Provider] that provides an existing `value`.
  Provider.value({super.key, required T value, bool lazy = true, super.child})
    : _config = ProviderConfig(value: value, lazy: lazy, dispose: _noDispose);

  /// The delegate that holds the create and dispose functions.
  final ProviderConfig<T> _config;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return InheritedProvider<T>(
      config: _config,
      child: child ?? SizedBox.shrink(),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(DiagnosticsProperty<ProviderConfig<T>>('config', _config));
    super.debugFillProperties(properties);
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
    this.selector,
    this.guard,
    bool lazy = true,
    required this.builder,
  }) : _config = ProviderConfig(
         create: create,
         lazy: lazy,
         dispose: dispose ?? _defaultDispose,
       );

  /// Creates a [RebuildingProvider] that provides an existing `value`.
  RebuildingProvider.value({
    super.key,
    required T value,
    this.selector,
    this.guard,
    bool lazy = true,
    required this.builder,
  }) : _config = ProviderConfig(
         create: (_) => value,
         lazy: lazy,
         dispose: _noDispose,
       );

  /// The delegate that holds the create and dispose functions.
  final ProviderConfig<T> _config;

  /// A function that builds a widget tree from a [Listenable].
  final RebuildCallback<T> builder;

  /// If provided, controls when the widget rebuilds by doing some comparison check on the read listenable.
  final Selector<T>? selector;

  /// Acts as a gatekeeper for builder, use this to control when and where the builder gets run.
  final Guard<T>? guard;

  @override
  Widget build(BuildContext context) {
    return InheritedProvider<T>(
      config: _config,
      child: Rebuilder<T>(builder: builder, selector: selector, guard: guard),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(DiagnosticsProperty<ProviderConfig<T>>('config', _config));
    super.debugFillProperties(properties);
  }
}

/// An [InheritedWidget] that provides an object to its descendants.
class InheritedProvider<T extends Object> extends InheritedWidget {
  /// Creates an [InheritedProvider].
  const InheritedProvider({
    super.key,
    required this.config,
    required super.child,
  });

  /// The delegate that holds the create and dispose functions.
  final ProviderConfig<T> config;

  @override
  InheritedProviderElement<T> createElement() => InheritedProviderElement(this);

  @override
  bool updateShouldNotify(InheritedProvider<T> oldWidget) {
    return config != oldWidget.config;
  }
}

/// An [Element] for [InheritedProvider].
class InheritedProviderElement<T extends Object> extends InheritedElement {
  /// Creates an [InheritedProviderElement].
  InheritedProviderElement(super.widget);

  /// The delegate that holds the create and dispose functions.
  ProviderConfig<T> get config => (widget as InheritedProvider<T>).config;

  T? _state;

  /// The provided object instance.
  T get state {
    _state ??= config.create?.call(this) ?? config.value;
    return _state!;
  }

  bool get _needsInitialization => _state == null;

  @override
  void performRebuild() {
    if (_needsInitialization && !config.lazy) {
      _state = config.create?.call(this) ?? config.value;
    }
    super.performRebuild();
  }

  @override
  void unmount() {
    if (!_needsInitialization && config.manageLifecycle) {
      config.dispose(this, _state!);
    }

    super.unmount();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(DiagnosticsProperty<ProviderConfig<T>>('config', config));
    properties.add(DiagnosticsProperty<T?>('state', _state));

    super.debugFillProperties(properties);
  }
}
