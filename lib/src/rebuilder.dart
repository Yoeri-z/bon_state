import 'package:bon_state/bon_state.dart';
import 'package:flutter/widgets.dart';

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
    final newState = (this as BuildContext).read<T>();

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
    if (T is Shared<int>) {
      print('Selector result');
      print(castedWidget.selector?.call(this, _state!));
    }

    if (castedWidget.selector?.call(this, _state!) ?? true) {
      markNeedsBuild();
    }
  }

  @override
  void performRebuild() {
    if (_isFirstBuild) _updateState();
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
    final inherited =
        dependOnInheritedWidgetOfExactType<InheritedProvider<T>>();
    assert(inherited != null, 'Listenable of type $T is not provided.');

    final providingElement =
        getElementForInheritedWidgetOfExactType<InheritedProvider<T>>()
            as InheritedProviderElement<T>;

    return providingElement.state;
  }
}
