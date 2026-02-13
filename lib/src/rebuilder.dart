import 'package:flutter/widgets.dart';

import 'provider.dart';

typedef Selector<T> = bool Function(BuildContext context, T listenable);

/// A function that builds a widget tree from a [Listenable].
typedef RebuildCallback<T extends Listenable> =
    Widget Function(BuildContext context, T listenable);

/// A widget that listens to a [Listenable] and rebuilds when it changes.
class Rebuilder<T extends Listenable> extends Widget {
  /// Creates a [Rebuilder] widget.
  const Rebuilder({
    super.key,
    this.selector,
    this.guard,
    required this.builder,
  });

  /// If provided, controls when the widget rebuilds by doing some comparison check on the read listenable.
  final Selector<T>? selector;

  /// Acts as a gatekeeper for builder, use this to control when and where the builder gets run.
  final Guard<T>? guard;

  /// The builder that builds the widget tree.
  final RebuildCallback<T> builder;

  @override
  BindingElement<T> createElement() => BindingElement<T>(this);
}

/// Element responsible for binding a listenable object to its subtree.
/// Here binding means that the subtree rebuilds when the object notifies.
class BindingElement<T extends Listenable> extends ComponentElement {
  BindingElement(super.widget);

  T? _state;
  bool _isFirstBuild = true;

  Rebuilder<T> get castedWidget => widget as Rebuilder<T>;

  void _updateState() {
    final newState = (this as BuildContext).maybeRead<T>();

    if (newState == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'Tried to bind a [Rebuilder] to a [Provider] that does not exist.',
        ),
        ErrorDescription('''
The Provider that this Rebuilder is trying to bind to was not found in the widget tree.
Make sure that the Provider is an ancestor of this Rebuilder, and that they are both using the same type parameter T.
If you are unsure if the provider exists, you can set [throwIfAbsent] to false to prevent this error from being thrown.
'''),
      ]);
    }

    if (newState != _state) {
      _state?.removeListener(_listener);
      _state = newState;
      _state?.addListener(_listener);
    }
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    // component mounting completed
    _isFirstBuild = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateState();
  }

  @override
  void unmount() {
    _state?.removeListener(_listener);
    _state = null;
    super.unmount();
  }

  void _listener() {
    if (castedWidget.selector?.call(this, _state!) ?? true) {
      markNeedsBuild();
    }
  }

  @override
  void performRebuild() {
    if (_isFirstBuild) {
      _isFirstBuild = false;
      _updateState();
    }

    super.performRebuild();
  }

  Widget _runBuilder() {
    return castedWidget.builder(this, _state!);
  }

  @override
  Widget build() {
    return castedWidget.guard?.call(this, _state!, _runBuilder) ??
        _runBuilder();
  }
}

extension ReadState on BuildContext {
  T read<T extends Object>() {
    final state = maybeRead<T>();
    if (state == null) {
      throw FlutterError.fromParts([
        ErrorSummary('Tried to read a provider that does not exist.'),
        ErrorDescription('''
The provider was not found in the widget tree. 
If you are unsure if the provider exists, you can use [maybeRead] instead of [read] to get a nullable value.
          '''),
      ]);
    }

    return state;
  }

  T? maybeRead<T extends Object>() {
    final inherited =
        dependOnInheritedWidgetOfExactType<InheritedProvider<T>>();

    if (inherited == null) return null;

    final providingElement =
        getElementForInheritedWidgetOfExactType<InheritedProvider<T>>()
            as InheritedProviderElement<T>;

    return providingElement.state;
  }
}
