**A minimal state management solution intended to work with flutters `ChangeNotifier`s,
It is lightweight, easy to understand and powerfull enough for most applications**

## Basics

This package has three main functions:

- Make it easy to pass objects down the widget tree.
- Listen to listenable objects
- Extend flutters base set of `Notifiers`

### Passing objects down the widget tree

To pass objects down the widget tree, we use a `Provider` widget:

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

If the created object is a `Listenable`, `Provider` will automatically dispose of it.

### Listener

A widget that listens to, and rebuilds its children when a listenable provided by a `Provider` notifies.

```dart
// listen to a listenable object MyNotifier registered in a Provider
Listener<MyNotifier>(
    builder: (context, notifier){
        return Text(notifier.value);
    },
)
```

### Providing listener

Sometimes you want to provide a listenable and listen to it at the same time, for that usecase you can use a `ProvidingListener`

```dart
ProvidingListener(
    create: (context) => MyNotifier(),
    builder: (context, notifier){
        return Text(notifier.value);
    },
)
```

### More notifiers

### The difference between this package and provider

Provider is a much more complex package, which aims to provide "values". It has widgets like `StreamProvider`, `FutureProvider` or methods to cascade providers with `ProxyProviders`.
All these providers may seem convenient but I find they add more complexity then value. I would much rather have one more flexible provider widget that enables me to do everything i need with a much more comprehensive syntax.

The implementation of this package is also much more straigthforward then `provider`s implementation.
