import 'package:bon_state/bon_state.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return RebuildingProvider(
      create: (context) => Shared(0),
      // only update the counter when the number is even
      selector: (context, listenable) => listenable.value % 2 == 0,
      builder: (context, sharedValue) => Provider(
        create: (context) => SharedStream(
          // simple stream that counts up every second
          Stream.periodic(Duration(seconds: 1), (ticks) => ticks),
        ),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,

            title: Text(title),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: .center,
              children: [
                const Text('You have pushed the button this many times:'),
                Text(
                  '${sharedValue.value}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text('App runtime (seconds):'),
                Rebuilder<SharedStream<int>>(
                  builder: (context, sharedStream) {
                    return Text(
                      '${sharedStream.value.data}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    );
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => sharedValue.set(sharedValue.value + 1),
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
