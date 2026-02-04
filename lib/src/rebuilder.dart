import 'package:flutter/widgets.dart';

import 'provider.dart';

/// A function that builds a widget tree from a [Listenable].
typedef RebuildCallback<T extends Listenable> =
    Widget Function(BuildContext context, T listenable);

/// A widget that listens to a [Listenable] and rebuilds when it changes.
class Rebuilder<T extends Listenable> extends Widget {
  /// Creates a [Rebuilder] widget.
  const Rebuilder({super.key, required this.builder, this.guard});

  /// The builder that builds the widget tree.
  final RebuildCallback<T> builder;

  final Guard<T>? guard;

  @override
  BindingElement<T> createElement() => BindingElement<T>(this);
}

/// Element responsible for binding a listenable object to its subtree.
/// Here binding means that the subtree rebuilds when the object notifies.
class BindingElement<T extends Listenable> extends ComponentElement {
  BindingElement(super.widget);

  T? _state;
  bool _isFirstBuild = true;

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

  void _listener() => markNeedsBuild();

  @override
  void performRebuild() {
    if (_isFirstBuild) _updateState();
    super.performRebuild();
  }

  Widget _build() {
    return (widget as Rebuilder<T>).builder(this, _state!);
  }

  @override
  Widget build() {
    final rebuilder = (widget as Rebuilder<T>);

    return rebuilder.guard?.call(this, _state!, _build) ?? _build();
  }

  @override
  void update(covariant Widget newWidget) {
    super.update(newWidget);
    rebuild(force: true);
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

    assert(
      providingElement.state != null,
      //TODO: Make this more descriptive
      '$T was not created yet in the provider, this should not be possible.',
    );

    return providingElement.state!;
  }
}
