import 'package:redux/redux.dart';
import 'package:reframe_middleware/reframe_middleware.dart';
import 'package:test/test.dart';
import 'package:meta/meta.dart';

// Normally for dependency injection; here, unused.
@immutable
class Effects {}


// Defining sync and async events for our reframe reducer+middleware.
@immutable
class IncrementEvent extends Event<int, Effects> {
  @override
  ReframeResponse<int> handle(int state, Effects effects) =>
      ReframeResponse.stateUpdate(state + 1);
}

@immutable
class AsyncIncrementEvent extends Event<int, Effects> {
  final Duration waitTime;

  const AsyncIncrementEvent(this.waitTime);

  @override
  ReframeResponse<int> handle(int state, Effects effects) =>
      ReframeResponse.sideEffect(() =>
          Future.delayed(waitTime)
              .then((_) => [IncrementEvent()]));
}

void main() {
  group('ReframeReducer and ReframeMiddleware can handle', () {
    // simple tests to show the sync and async logic work
    test('pure, synchronous action', () {
      final store = Store<int>(reframeReducer,
          initialState: 0, middleware: [reframeMiddleware(Effects())]);
      store.dispatch(IncrementEvent());
      expect(store.state, equals(1));
    });

    test('side-effectful, asynchronous action', () async {
      final store = Store<int>(reframeReducer,
          initialState: 0, middleware: [reframeMiddleware(Effects())]);

      final waitTime = Duration(milliseconds: 1000);

      expect(store.state, equals(0));
      store.dispatch(AsyncIncrementEvent(waitTime));

      await Future.delayed(waitTime);

      expect(store.state, equals(1));
    });
  });
}
