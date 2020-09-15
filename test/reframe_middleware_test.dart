import 'package:redux/redux.dart';
import 'package:reframe_middleware/reframe_middleware.dart';
import 'package:test/test.dart';
import 'package:meta/meta.dart';

// Normally for dependency injection; here, unused.
@immutable
class Effects {}


// Defining sync and async events for our reframe reducer+middleware.
@immutable
class IncrementAction extends ReframeAction<int, Effects> {
  @override
  ReframeResponse<int> handle(int state, Effects effects) =>
      ReframeResponse.stateUpdate(state + 1);
}

@immutable
class AsyncIncrementAction extends ReframeAction<int, Effects> {
  final Duration waitTime;

  const AsyncIncrementAction(this.waitTime);

  @override
  ReframeResponse<int> handle(int state, Effects effects) =>
      ReframeResponse.sideEffect(() =>
          Future.delayed(waitTime)
              .then((_) => [IncrementAction()]));
}


void main() {
  // simple tests to show the sync and async logic work
  group('ReframeReducer and ReframeMiddleware can handle', () {

    test('pure, synchronous action', () {
      final store = Store<int>(reframeReducer,
          initialState: 0, middleware: [reframeMiddleware(Effects())]);
      store.dispatch(IncrementAction());
      expect(store.state, equals(1));
    });

    test('side-effectful, asynchronous action', () async {
      final store = Store<int>(reframeReducer,
          initialState: 0, middleware: [reframeMiddleware(Effects())]);

      final waitTime = Duration(milliseconds: 1000);

      expect(store.state, equals(0));
      store.dispatch(AsyncIncrementAction(waitTime));

      await Future.delayed(waitTime);

      expect(store.state, equals(1));
    });
  });
}
