# reframe-middleware: the ‘action first’ approach to redux.dart
### Reframe-middleware is an alternative way of handling actions in redux.dart, inspired by Clojurescript’s re-frame. 

****

# How to use
### Step #1: Add `reframeReducer` and `reframeMiddleware` to your redux.dart `Store`:

```dart
import 'package:reframe_middleware';

final store = Store<AppState>(
	reframeReducer,
  initialState: AppState(), 
	middleware: [reframeMiddleware(), thirdPartyMiddleware, ...]);
```


### Step #2: Define an action that `extends Action` and implements `handle` :

```dart
import 'package:reframe_middleware';

@immutable
class IncrementAction extends Action {
  @override
  ReframeResponse<AppState> handle(AppState state) =>
      ReframeResponse.stateUpdate(
        state.copy(counter: state.counter.copy(state.counter + 1)));
}
```


### Step #3: Dispatch the action like normal:

```dart
store.dispatch(IncrementAction());
```


### Step #4: … There is no step #4! You’re done!

`reframeMiddleware` will accept your dispatched action and call `action.handle(state)`:

```dart
// Type signature required by redux-dart
typedef ReduxMiddleware = void Function(Store<AppState>, dynamic, NextDispatcher);

Middleware reframeMiddleware() => (store, action, next) {
	if (action is Action)
		action.handle(store.state)	
			// StateUpdate: special action, ferries new state to reframeReducer
			..nextState.ifPresent((newState) => store.dispatch(StateUpdate(newState)))
			..effect().then((actions) => actions.forEach(store.dispatch));

	// propagate action to any 3rd party middleware
	// and, eventually, to reframeReducer
	next(actions);
};
```

Calling `action.handle(state)` returns a `ReframeResponse`, which contains a state update and/or a side-effect:

```dart
// A side-effect asynchronously resolves to a list of additional Actions.
typedef SideEffect = Future<List<Action>> Function();
Future<List<Action>> noEffect() async => [];

@immutable
class ReframeResponse<S> {
  final Optional<S> nextState;
  final SideEffect effect;

  const ReframeResponse({
    this.nextState = const Optional.absent(),
    this.effect = noEffect,
  });
```

`reframeMiddleware` will dispatch a `StateUpdate` action that ferries the new state to the reducer:

```dart
..nextState.ifPresent((newState) => store.dispatch(StateUpdate(newState)))
```

`reframeReducer` does the actual state swap:

```dart
// Type signature required by flutter-redux
AppState reframeReducer(AppState oldState, dynamic event) =>
	event is StateUpdate ? event.newState : oldState
```

`reframeMiddleware` will run the side-effect and dispatch the resulting additional actions:

```dart
	..effect().then((actions) => actions.forEach(store.dispatch));
```


****

# Motivation: re-frame vs. traditional redux

## The most important question in re-frame and redux: ‘What does this action mean?’ i.e. ‘Which state changes and side-effects does this action cause?’

Re-frame is the ‘action first’ way of reasoning about your app.

Libraries like Elm, re-frame, and redux.js are all fundamentally based on two principles:   
1. UI is explained by state (i.e. state at some time t), and
2. state is explained by actions (i.e. state at t0 + action => state at t1)

The change produced by an action is described by some function `f`:
`f(state at t0, action) => state at t1`

The most important thing, then, is to understand *what an action means* — i.e. *which state changes and side-effects does this action cause?* 

~Re-frame makes this easy:~ 
1. each action has its own action-handler which describes both the state updates and the side-effects caused by the action, and
2. an action and its handler are co-defined, i.e. we cannot define an action without also defining its handler, and every dispatched action merely calls its own handler (`action.handle(state, …)`)

~In contrast, traditional redux makes this hard:~ 
1. an action can map to multiple reducers and/or middleware, and so the resultant state changes and side-effects must be coordinated across (in the worst case) *every reducer and middleware*, and
2. an action is not bound to any given reducer or middleware; we have to manually connect them (e.g. `switch`, `if-else`, `TypedReducer` etc.) and write a test, and
3. side-effects are treated as second-class; we must add e.g. `thunkMiddleware` as dependency.
