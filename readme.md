**A minimal state management solution intended to work with flutters `ChangeNotifier`s,
It is lightweight, easy to understand and powerfull enough for most applications**

## Basics

This package has three main functions:

- Make it easy to pass objects down the widget tree.
- Listen to listenable objects
- Extend flutters base set of `Notifiers` with a new type of primitive: `SharedValue`

### Passing objects down the widget tree

At the core of this package stands `Provider`, `Provider` can provide an object down the widget tree.

```dart
// create a new object and provide it down the widget tree
Provider(
    create: (context) => MyNotifier(),
    child: SubWidget(),
);


// provide an already existing object
Provider.value(
    value: myNotifier,
    child: SubWidget(),
)

// provide multiple objects in one widget
MultiProvider(
    providers:[
        Provider(
            create: (context) => MyFirstNotifier(),
        ),
        Provider.value(
            value: myNotifier,
        ),
    ],
    child: SubWidget(),
);
```

If the created object is a `ChangeNotifier` or `SharedValue`, `Provider` will automatically dispose of it.

### Rebuilder

A widget that listens to, and rebuilds its children when a listenable provided by a `Provider` notifies.

```dart
// listen to a listenable object MyNotifier registered in a Provider
Rebuilder<MyNotifier>(
    builder: (context, notifier){
        return Text(notifier.value);
    },
)
```

### Providing listener

Sometimes you want to provide a listenable and rebuild when it changes at the same time, for that usecase you can use a `RebuildingProvider`

```dart
RebuildingProvider(
    create: (context) => MyNotifier(),
    builder: (context, notifier){
        return Text(notifier.value);
    },
)
```

### Shared Value

This package adds a new type of notifying object, called `SharedValue`. It also adds some prebuilt classes that extend `SharedValue`.

```dart
final sharedValue = SharedValue(0);
sharedValue.addListener(() => print(sharedValue.value))

// prints 1
sharedValue.set(1)

// SharedFuture is a SharedValue that wraps and asyncsnapshot and manages a future call.
final sharedFuture = SharedFuture(() => someApiCall())
sharedValue.addListener(() => print(sharedValue.value))

sharedFuture.refresh() // refresh the value while keeping the old one until the new one is fetched

sharedFuture.reload() // reload the value and discard the old one, putting the value into a loading state.


// SharedStream is a SharedValue that wraps an asyncsnapshot and manages a stream.
final sharedStream = SharedStream(myStream)

sharedStream.unsubscribe() //we can manually unsubscribe from the stream.

/// Shared computed computes a new value from other shared values.
final sharedComputed = SharedComputed(
    () {
        return sharedValue *10
    },
    deps: [sharedValue]
);
```

### The difference between this package and provider

Provider is a much more complex package, which aims to provide "values". It has widgets like `StreamProvider`, `FutureProvider` or methods to cascade providers with `ProxyProviders`.
All these providers may seem convenient but I find they add more complexity then value. I would much rather have one more flexible provider widget that enables me to do everything i need with a much more comprehensive syntax.

To compensate for the lack of these stream and future providers i added the sharedvalue classes. This makes the package much more composable then provider with barely any extra boilerplate.

The implementation of this package is also much more straigthforward then `provider`s implementation.
