import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bon_state/src/provider.dart';
import 'package:bon_state/src/rebuilder.dart';
import 'package:bon_state/src/shared_state.dart';

// Helper class to track disposal
class TestDisposable extends ChangeNotifier {
  bool disposed = false;
  int value;

  TestDisposable([this.value = 0]);

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  // Wrap with Directionality for all tests
  Widget buildTestWidget(Widget child) {
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  group('Inherited Provider', () {
    testWidgets(
      'provides value and manages lifecycle if configured with create',
      (tester) async {
        final disposable = TestDisposable(42);
        bool createCalled = false;

        await tester.pumpWidget(
          buildTestWidget(
            Provider<TestDisposable>(
              create: (context) {
                createCalled = true;
                return disposable;
              },
              child: Builder(
                builder: (context) {
                  final val = context.read<TestDisposable>();
                  return Text('Value: ${val.value}');
                },
              ),
            ),
          ),
        );

        expect(createCalled, isTrue);
        expect(find.text('Value: 42'), findsOneWidget);
        expect(disposable.disposed, isFalse);

        // Unmount to trigger dispose
        await tester.pumpWidget(const SizedBox());

        expect(disposable.disposed, isTrue);
      },
    );

    testWidgets(
      'provides value and does not manage lifecycle if configured without create',
      (tester) async {
        final disposable = TestDisposable(10);

        await tester.pumpWidget(
          buildTestWidget(
            Provider<TestDisposable>.value(
              value: disposable,
              child: Builder(
                builder: (context) {
                  final val = context.read<TestDisposable>();
                  return Text('Value: ${val.value}');
                },
              ),
            ),
          ),
        );

        expect(find.text('Value: 10'), findsOneWidget);
        expect(disposable.disposed, isFalse);

        // Unmount
        await tester.pumpWidget(const SizedBox());

        // Should NOT be disposed because we used .value constructor
        expect(disposable.disposed, isFalse);
      },
    );

    testWidgets('is lazy if configured with lazy true', (tester) async {
      bool createCalled = false;
      await tester.pumpWidget(
        buildTestWidget(
          Provider<String>(
            create: (_) {
              createCalled = true;
              return 'Lazy';
            },
            lazy: true,
            child: const SizedBox(),
          ),
        ),
      );

      // Should not be created yet
      expect(createCalled, isFalse);

      // Now read it
      await tester.pumpWidget(
        buildTestWidget(
          Provider<String>(
            create: (_) {
              createCalled = true;
              return 'Lazy';
            },
            lazy: true,
            child: Builder(
              builder: (context) {
                context.read<String>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(createCalled, isTrue);
    });
  });

  group('Rebuilder', () {
    testWidgets('rebuilder binds to provider if available', (tester) async {
      final notifier = ValueNotifier<int>(0);

      await tester.pumpWidget(
        buildTestWidget(
          Provider<ValueNotifier<int>>.value(
            value: notifier,
            child: RebuildingProvider<ValueNotifier<int>>.value(
              value: notifier,
              builder: (context, n) => Text('Count: ${n.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      notifier.value = 1;
      await tester.pumpAndSettle();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('rebuilder throws if provider is not available', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          Rebuilder<ValueNotifier<int>>(
            builder: (context, n) => const Text('Should not render'),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isFlutterError);
      expect(error.toString(), contains('Tried to bind a [Rebuilder]'));
    });
  });

  group('Shared', () {
    test('Value', () {
      final shared = Shared<int>(0);
      expect(shared.value, 0);

      bool notified = false;
      shared.addListener(() => notified = true);

      shared.set(1);
      expect(shared.value, 1);
      expect(notified, isTrue);
    });

    group('Future', () {
      test('notifies when computation completes with value', () async {
        final completer = Completer<int>();
        final shared = SharedFuture<int>(() => completer.future);

        expect(shared.value.connectionState, ConnectionState.waiting);

        bool notified = false;
        shared.addListener(() => notified = true);

        completer.complete(100);
        await Future.delayed(Duration.zero);

        expect(shared.connectionState, ConnectionState.done);
        expect(shared.data, 100);
        expect(notified, isTrue);
      });

      test('notifies when computation completes with error', () async {
        final completer = Completer<int>();
        final shared = SharedFuture<int>(() => completer.future);

        completer.completeError('Error occurred');
        await Future.delayed(Duration.zero);

        expect(shared.connectionState, ConnectionState.done);
        expect(shared.hasError, isTrue);
        expect(shared.error, 'Error occurred');
      });

      test('refresh recomputes while keeping the state alive', () async {
        int counter = 0;
        final shared = SharedFuture<int>(() async => ++counter);

        // Initial load
        await Future.delayed(Duration.zero);
        expect(shared.data, 1);

        // Refresh
        shared.refresh();
        await Future.delayed(Duration.zero);

        expect(shared.data, 2);
      });

      test(
        'reload recomputes the state and resets the state to loading',
        () async {
          int callCount = 0;
          final shared = SharedFuture<int>(() async {
            callCount++;
            await Future.delayed(const Duration(milliseconds: 10));
            return callCount;
          });

          // Initial wait
          expect(shared.connectionState, ConnectionState.waiting);
          await Future.delayed(const Duration(milliseconds: 20));
          expect(shared.connectionState, ConnectionState.done);
          expect(shared.data, 1);

          // Reload
          shared.reload();
          expect(
            shared.connectionState,
            ConnectionState.waiting,
          ); // Should be waiting immediately

          await Future.delayed(const Duration(milliseconds: 20));
          expect(shared.connectionState, ConnectionState.done);
          expect(shared.data, 2);
        },
      );

      test('write sets the state to the new computed value', () async {
        final shared = SharedFuture<int>(() async => 0);
        await Future.delayed(Duration.zero);
        expect(shared.data, 0);

        await shared.write(() async => 42);
        expect(shared.data, 42);
      });

      test('write sets the state to error if computations fails', () async {
        final shared = SharedFuture<int>(() async => 0);
        await shared.write(() async => throw 'Write Error');
        expect(shared.hasError, isTrue);
        expect(shared.error, 'Write Error');
      });

      test(' defer sets the state to error if computations fails', () async {
        final shared = SharedFuture<int>(() async => 0);
        await shared.defer(() async => throw 'Defer Error');
        expect(shared.hasError, isTrue);
        expect(shared.error, 'Defer Error');
      });

      test('defer recomputes the state if refresh property is true', () async {
        int count = 0;
        final shared = SharedFuture<int>(() async => ++count);
        await Future.delayed(Duration.zero);
        expect(shared.data, 1);

        await shared.defer(() async {}, refresh: true);
        await Future.delayed(Duration.zero);

        expect(shared.data, 2);
      });
    });

    group('Stream', () {
      test('notifies when value is emited', () async {
        final controller = StreamController<int>();
        final shared = SharedStream<int>(controller.stream);

        expect(shared.connectionState, ConnectionState.waiting);

        controller.add(1);
        await Future.delayed(Duration.zero);

        expect(shared.connectionState, ConnectionState.active);
        expect(shared.data, 1);

        controller.close();
      });

      test('notifies when error is emited ', () async {
        final controller = StreamController<int>();
        final shared = SharedStream<int>(controller.stream);

        controller.addError('Stream Error');
        await Future.delayed(Duration.zero);

        expect(shared.hasError, isTrue);
        expect(shared.error, 'Stream Error');

        controller.close();
      });

      test('pauses and resumes', () async {
        final controller = StreamController<int>();
        final shared = SharedStream<int>(controller.stream);

        shared.pause();
        expect(shared.isPaused, isTrue);

        shared.resume();
        expect(shared.isPaused, isFalse);

        controller.close();
      });

      test('unsubscribe prevents updating', () async {
        final controller = StreamController<int>();
        final shared = SharedStream<int>(controller.stream);

        controller.add(1);
        await Future.delayed(Duration.zero);
        expect(shared.data, 1);

        shared.unsubscribe();
        expect(shared.isSubscribed, isFalse);

        controller.add(2);
        await Future.delayed(Duration.zero);
        // _handleSubscriptionClose is called on unsubscribe.

        expect(shared.data, 1);

        controller.close();
      });

      test(
        'subscribe subscribes to a new stream if no stream is present',
        () async {
          // Must use broadcast stream to allow re-subscription
          final controller = StreamController<int>.broadcast();
          final shared = SharedStream<int>(controller.stream);

          shared.unsubscribe();
          expect(shared.isSubscribed, isFalse);

          shared.subscribe();
          expect(shared.isSubscribed, isTrue);

          controller.add(99);
          await Future.delayed(Duration.zero);
          expect(shared.data, 99);

          controller.close();
        },
      );
    });
  });
}
