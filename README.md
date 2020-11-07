# reframe-middleware: the ‘action first’ approach to redux

### Reframe-middleware makes actions first class in redux.dart. 

![pub package](https://img.shields.io/pub/v/reframe_middleware.svg)

Inspired by Clojurescript's [re-frame](https://github.com/day8/re-frame). 

[Flutter demo](https://github.com/pianostringquartet/reframe-middleware-sample-app).

## How to use

#### 1. Add `reframe_middleware` to your `pubspec.yaml`:

```yaml
dependencies:
  reframe_middleware: ^1.0.0
``` 

#### 2. Add `reframeReducer` and `reframeMiddleware` to your redux.dart `Store`: 

```dart
import 'package:reframe_middleware';

final store = Store<AppState>(
	reframeReducer, // produces new state
    initialState: AppState(), 
    middleware: [reframeMiddleware(), // handles actions
	             thirdPartyMiddleware, ...]);
```


#### 3. Define an action: 

Synchronous, pure action:

```dart
import 'package:reframe_middleware';

@immutable
class IncrementAction extends ReframeAction {
  @override
  ReframeResponse<AppState> handle(AppState state) =>
      ReframeResponse.stateUpdate(
        state.copy(count: state.count + 1));
}
```

Asynchronous, impure action (side-effect):

```dart
import 'package:reframe_middleware';

@immutable
class AsyncIncrementAction extends ReframeAction {
  @override
  ReframeResponse<AppState> handle(AppState state) =>
      ReframeResponse.sideEffect(() =>
          Future.delayed(Duration(milliseconds: 1000))
              .then((_) => [IncrementEvent()]));
}
```

An action that does both:

```dart
@immutable
class DoubleIncrementAction extends ReframeAction {
  @override
  ReframeResponse<AppState> handle(AppState state, Effects effects) {
    return ReframeResponse(
        nextState: Optional.of(state.copy(count: state.count + 1)),
        effect: () => Future.delayed(Duration(milliseconds: 1000))
            .then((_) => [IncrementAction()]));
  }
```



#### 4. Dispatch... and done.

```dart
store.dispatch(IncrementAction());
```


## How it works


Actions are handled by their own `handle` method:

```dart
action.handle(store.state) -> ReframeResponse
``` 

A `ReframeResponse` contains a new state and side effect.

```dart
@immutable
class ReframeResponse<S> {
  final Optional<S> nextState;
  final SideEffect effect;

  const ReframeResponse({
    this.nextState = const Optional.absent(),
    this.effect = noEffect,
  });
  
// A side-effect is a closure that becomes a list of actions
typedef SideEffect = Future<List<Action>> Function();
Future<List<Action>> noEffect() async => [];
```

For state updates, `reframeMiddleware` dispatches a special action `StateUpdate` to carry the new state to the `reframeReducer`.

For side-effects, `reframeMiddleware` runs the Future and dispatches the resulting actions.

```dart
// middleware
Middleware<S> reframeMiddleware<S, E>(E effects) =>
    (Store<S> store, dynamic event, NextDispatcher next) {
      if (event is ReframeAction) {
        event.handle(store.state, effects)
            // sends new state to reducer via StateUpdate action
          ..nextState
              .ifPresent((newState) => store.dispatch(StateUpdate(newState)))
           // runs side effects and dispatch resulting actions:
          ..effect().then((events) => events.forEach(store.dispatch));
      }

      // passes (1) the event to next middleware (e.g. 3rd party middleware)
      // and (2) a StateUpdate to the reducer
      next(event);
    };


// reducer
AppState reframeReducer<S>(AppState state, dynamic event) =>
    event is StateUpdate ? event.state : state;
```

****

# FAQ

### Do I need thunkMiddleware?

No. Reframe-middleware already does async logic -- that’s what `ReframeResponse`'s `effect` is for.


### Does this replace redux.dart or flutter-redux?

No. Reframe-middleware is supposed to be used with redux.dart (in the same way e.g. Flutter [redux_persist](https://pub.dev/packages/redux_persist) is). 

Reframe-middleware, like redux.dart, can be used with or without the
excellent [flutter-redux](https://pub.dev/packages/flutter_redux).

### Doesn't this couple reducers and actions, which is discouraged?

Short answer: Yes. 

Long answer: 

There have been [objections](https://github.com/pitzcarraldo/reduxible/issues/8#issue-124545582) to 1:1 mappings between actions and reducers. ([“The whole point of Flux/Redux is to decouple actions and reducers”](https://github.com/reduxjs/redux/issues/1167)).

But the decoupling of actions and reducers is an *implementation detail of redux.js*. 

In contrast, Clojurescript [re-frame](https://github.com/day8/re-frame) *intentionally couples* an event (action) with its handler (reducer + middleware). Why?

Every redux system* -- Elm, re-frame, redux.js, redux-dart etc. -- is characterized by two fundamental principles:

1. UI is explained by state ("state causes UI")
2. state is explained by actions ("actions cause state")

When we dispatch an action we ask, "What does this action *mean*, what updates or side-effects will it cause?" 

If you need to reuse state modification logic, reuse a function -- don't reuse a reducer. 

*(In contrast, [SwiftUI](https://developer.apple.com/xcode/swiftui/) has 1 but not 2, and so is not a redux sytem.)

