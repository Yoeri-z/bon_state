**A minimal state management solution made to work with flutters `ChangeNotifiers`. Lightweight, easy to understand, and powerful enough for most applications.**

---

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  bon_state: ^0.0.1
```

or run

```
flutter pub add bon_state
```

---

## 1. Basics: Providing Data

The core of this package is the `Provider`. It allows you to pass any object down the widget tree without manually passing it through every constructor.

### Providing and Reading

You can provide a simple value like a `String` and retrieve it anywhere in the subtree using `context.read<T>()`.

```dart
// 1. Provide the value
Provider(
    create: (context) => "Hello World",
    child: MyWidget(),
);

// 2. Read the value
class MyWidget extends StatelessWidget {
    const MyWidget();

    Widget build(BuildContext context) {
        return Text(context.read<String>());
    }
}

```

You can also provide an existing value by using `Provider.value`.

```dart
final myString = "Hello world";

Provider.value(
    value: myString,
    child: MyWidget(),
)
```

### Lifecycle & Memory Management

One of the most important features of `Provider` is how it handles the lifecycle of the provided object:

- **Automatic Disposal:** If the object you provide is a `ChangeNotifier` (or a `Shared` object), `Provider` will **automatically call `.dispose()`** when the Provider is removed from the widget tree.
- **Manual Disposal:** If you are providing a custom object that needs specific cleanup, use the `dispose` parameter:

```dart
Provider(
    create: (context) => MyCustomResource(),
    dispose: (context, resource) => resource.close(),
    child: SubWidget(),
)
```

- **Existing Objects:** If you use `Provider.value`, the package assumes you are managing the object's lifecycle elsewhere. **It will NOT dispose** of the object automatically. Use this for objects that live longer than the specific widget tree. This also means that you should **NOT** create new objects inside a `Provider.value` since they will not be marked for disposal.

---

## 2. Reactivity with ChangeNotifiers

To make your UI update when data changes, you use `Rebuilder`.

### Rebuilder

This widget listens to an existing notifier, and rebuilds when it notifies. It only rebuilds the part of the UI inside its `builder` function, allowing finegrained control over rebuilds.

```dart
Rebuilder<MyNotifier>(
    builder: (context, notifier) {
        return Text(notifier.statusMessage);
    },
)

```

### RebuildingProvider

If you want to create a new notifier and start listening to it immediately, `RebuildingProvider` combines both steps into one widget.

```dart
RebuildingProvider(
    create: (context) => MyCounter(),
    builder: (context, counter) {
        return Text("Count: ${counter.value}");
    },
)

```

---

## 3. Shared Values

The package introduces `Shared` objects—pre-built listenables that eliminate the boilerplate of writing full classes for simple state.

| Type                    | Description                                                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **`Shared<T>`**         | A simple observable wrapper for any value.                                                                                      |
| **`SharedFuture<T>`**   | Manages `AsyncSnapshot` for a Future; supports `refresh()` (keep data while loading) and `reload()` (clear data while loading). |
| **`SharedStream<T>`**   | Manages a Stream subscription and provides the latest snapshot.                                                                 |
| **`SharedComputed<T>`** | Automatically re-calculates its value when its specified `deps` (dependencies) change.                                          |

```dart
final sharedNumber = Shared(0);
sharedNumber.set(10); // Automatically notifies listeners
```

Note that these shared values are intented for simple states, if your problem requires a more custom solution you are encouraged to make a custom `ChangeNotifier` or `ValueNotifier` instead.

---

## 4. The Guard Property

When working with `Rebuilder` or `RebuildingProvider`, you often need to stop the main `builder` from running if the data isn't ready (e.g., still loading or crashed with an error).

The `guard` property acts as a gatekeeper.

To let the UI render normally, you **must** call and return `childBuilder()`. If you return a different widget (like a loader), the main builder is ignored.

### Example: Guarding an Async Call

```dart
RebuildingProvider<SharedFuture<String>>(
    create: (context) => SharedFuture(() => api.fetchUsername()),
    guard: (context, future, childBuilder) {
        // 1. Handle Loading
        if (future.isLoading) {
            return const Center(child: CircularProgressIndicator());
        }
        // 2. Handle Errors
        if (future.hasError) {
            return const Center(child: Text("Error!"));
        }

        // 3. Data is safe! Proceed to the main builder.
        return childBuilder();
    },
    builder: (context, future) {
        // This code ONLY runs if the guard calls childBuilder()
        return Text("Welcome, ${future.requireData}");
    },
)

```

---

## 5. Caveats

### Lazy Initialization

By default, the `create` function is **lazy**. This means your object is not created the moment the `Provider` is added to the tree; instead, it is created only when the first widget tries to **read** it (via `context.read` or a `Rebuilder`).

If you need an object to be created immediately (e.g., to start a background process even if no UI is listening), you can set `lazy: false`:

```dart
Provider(
    create: (context) => BackgroundService()..init(),
    lazy: false,
    child: MyWidget(),
)

```

### State Persistence

By design, the `create` function is only called **once** when the `Provider` first enters the widget tree. Even if the `Provider` widget is rebuilt with a new `create` function, the internal state will stay the same. This behaviour was intentionally chosen because the create function is often a lamda which is created as a new object every rebuild, while it is often semantically the same. If you use `Provider.value` the widget **will** notify dependents that its internal state changed.

### How to Force a Reset

If you need to destroy the old state and create a fresh one (for example, when a `userId` changes), provide a unique **`Key`** to the `Provider`. This tells Flutter to treat it as a brand-new widget.

```dart
// This will recreate the state whenever the userId changes
Provider<AuthService>(
  key: ValueKey(userId),
  create: (context) => AuthService(userId),
  child: MyApp(),
)

```

---

## Using flutter devtools

Every `Provider` and `RebuildingProvider` has a diagnostics property called `config` that quickly shows the configuration of the provider. To inspect the internal state of a `Provider` you have to toggle _Show implementation widgets_ on and look for the `InheritedProvider` widget. This widget contains diagnostics for the internal state.

## Credit

While this package was **written from scratch** to be a lightweight and focused alternative, some features were heavily inspired by other packages in the Flutter ecosystem. Namely:

1. **Provider**: Inspiration for the familiar `Provider`, `MultiProvider`, and `context.read` API patterns.
2. **Signals**: Inspiration for the `Shared` and `SharedComputed` reactive primitives.

## Contributing

This package is opensource and uses the MIT license, feel free to submit issues on the issueboard or suggest changes.

---
