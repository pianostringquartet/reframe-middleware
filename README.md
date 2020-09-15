# reframe-middleware: the ‘action first’ approach to redux.dart
### Reframe-middleware is an alternative way of handling actions in redux.dart, inspired by Clojurescript’s Re-frame](https://github.com/day8/re-frame). 


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

Synchronous, pure action:

```dart
import 'package:reframe_middleware';

@immutable
class IncrementAction extends Action {
  @override
  ReframeResponse<AppState> handle(AppState state) =>
      ReframeResponse.stateUpdate(
        state.copy(count: state.count + 1));
}
```


### Step #3: Dispatch the action like normal:

```dart
store.dispatch(IncrementAction());
```


### Step #4: … There is no step #4! You’re done!


### What happens next:

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
AppState reframeReducer(AppState oldState, dynamic action) =>
	action is StateUpdate ? action.newState : oldState
```

`reframeMiddleware` will run the side-effect and dispatch the resulting additional actions:

```dart
	..effect().then((actions) => actions.forEach(store.dispatch));
```


****

# FAQ
### How do I handle async logic? Do I need to add thunkMiddleware?

Reframe-middleware already comes capable of handling async or impure logic — that’s what `ReframeResponse.effect` is for.

In reframe-middleware, asynchronous logic is ‘first class’ (built-in), not ‘second class’ (added as a dependency like `thunkMiddleware`).

Here’s an example of a side-effectful action: 

```dart
@immutable
class AsyncIncrementAction extends Action {
  @override
  ReframeResponse<int> handle(AppState state) =>
      ReframeResponse.sideEffect(() =>
          Future.delayed(milliseconds: 1000)
              .then((_) => [IncrementEvent()]));
}
```


### Does this replace redux.dart or flutter-redux?

No. Reframe-middleware is supposed to be used with redux.dart (in the same way e.g. Flutter redux_persist is). 

Reframe-middleware, like redux.dart, can be used with or without Brian Egan’s 
excellent [flutter-redux](https://pub.dev/packages/flutter_redux).


### What about [missing feature] from Clojurescript re-frame?

This library is only about re-frame-style middleware, adapted in a manner suitable for typed functional programming (as much as this can be done in Dart); it does not include all features of re-frame.

Derived calculations via subscriptions, etc. are thus not included. :’-(

Reframe-middleware also takes a slightly different approach to side-effects and does not use side-effect handlers as re-frame does — though it would be possible to add them, modeling an effect as an action, including e.g. ‘effect-handlers’, etc. 


### Isn’t this coupling reducers and actions, which is something Dan Abramov, the creator of redux.js, has warned against?

Short answer: Yes. 

Long answer: 

Dan has made several arguments (e.g. [here](https://github.com/pitzcarraldo/reduxible/issues/8#issue-124545582) and [here](https://github.com/reduxjs/redux/issues/1167#issuecomment-166641977)). 

The most often-cited concern appears to be about scale ([“big teams can work on overlapping features without constant merge conflicts”](https://github.com/reduxjs/redux/issues/1167#issuecomment-166641977)). 

This suspiciously appeals to outside contingencies to justify what is presented as a fundamental feature of redux ([“The whole point of Flux/Redux is to decouple actions and reducers”](https://github.com/reduxjs/redux/issues/1167)).

In contrast, Clojurescript’s re-frame has broader way of thinking about why your app looks the way it does, how it can change and — most importantly — *why* it changes.

That is, re-frame couples an action and its state-changes and side-effects *because this coupling represents a fundamental feature of how we think about how event-driven systems change.* 

([This part of the re-frame Readme](http://day8.github.io/re-frame/a-loop/) is worth reading, even if you never use Clojurescript or re-frame.)

See ‘Motivation’ below for a longer explanation and for code comparisons of re-frame vs. traditional redux.


****

# Motivation: Actions, not ‘pure state updates’ (reducers), are the core of redux
## The most important question in re-frame and redux is ‘What does an action mean?’ i.e. ‘Which state changes and side-effects does this action cause?’

Re-frame is the ‘action first’ way of reasoning about your app.

Libraries like Elm, re-frame, and redux.js are all fundamentally based on two principles:   
1. UI is explained by state (i.e. state at some time t), and
2. state is explained by actions (i.e. state at t0 + action => state at t1)

The change produced by an action is described by some function `f`:
`f(state at t0, action) => state at t1`

The most important thing, then, is to understand *what an action means* — i.e. *which state changes and side-effects does this action cause?* 


#### Re-frame makes this easy: 
1. each action has its own action-handler which describes both the state updates and the side-effects caused by the action, and
2. an action and its handler are co-defined, i.e. we cannot define an action without also defining its handler, and every dispatched action merely calls its own handler (`action.handle(state, …)`)

#### In contrast, traditional redux makes this hard:
1. an action can map to multiple reducers and/or middlewares, and so the resultant state changes and side-effects must be coordinated across (in the worst case) *every reducer and middleware*, and
2. an action is not bound to any given reducer or middleware; we have to manually connect them (e.g. `switch`, `if-else`, `TypedReducer` etc.) and write a test, and
3. side-effects are treated as second-class; we must add e.g. `thunkMiddleware` as a dependency.

(See below for an explanation of each point, along with code examples.)




****

# Motivation in depth, with code samples:
## Re-frame: An action’s event-handler is the single place to understand an action’s state updates and side-effects

```dart
@immutable
class SetCountAction extends Action {
  final int number;

  const SetCountAction(this.number);

  @override
  ReframeResponse<AppState> handle(AppState state) =>
      ReframeResponse.stateUpdate(
        state.copy(counter: state.counter.copy(count: number)));
}
```


## Traditional redux: There is no single place to understand an action’s state-updates and side-effects

```dart
// spread throughout our codebase, found via e.g. use search:
// my_dogs_module/x.dart:
reducerX(state, actionA)

// my_friends_module/k.dart:
reducerK(state, actionA)

// my_favorite_module/favorite.dart
reducerF(state, actionA)
```

(And those are just the reducers in traditional redux — don’t forget the middlewares too!)

Conflicts are also hard to spot when the state change and side effect logic of an action are not centralized. Let’s take a look inside `reducerX` and `reducerF`:

```dart
reducerX(state, actionA) => state.counter + 1
reducerF(state, actionA) => state.counter - 1 // oops!
```


## Re-frame: an action’s handler is co-defined and guaranteed to be called (no room for error)

Every action extends from this class and must implement `handle`:

```dart
@immutable
abstract class Action {
  const Action();

  ReframeResponse<AppState> handle(AppState state);
}
```

As we saw above, re-frame uses a single middleware whose only responsibility is to call `action.handle` and run the state changes and side-effects described in  the handler response. 


### Traditional redux: actions must be manually connected to reducer(s)/middleware(s) in a verbose, error-prone manner

An action is not bound to any given reducer or middleware; we have to manually connect them (e.g. `switch`, `if-else`, `TypedReducer` etc.) and write a test to ensure an actin is being consumed.

Consider a common way of matching a redux action to its reducer and/or middleware(s):

```
if action is ActionA: 
	return reducerA(action);
else if action is ActionB:
	return reducerB(action);
else if ...
else ...
```

Example from redux-dart docs:

```dart
// from redux-dart's combine_reducers.md:
// https://github.com/fluttercommunity/redux.dart/blob/master/doc/combine_reducers.md
  if (action is AddItemAction) {
    return new AppState(
      new List.from(state.items)..add(action.item), 
      state.searchQuery,
    );
  } else if (action is RemoveItemAction) {
    return new AppState(
      new List.from(state.items)..remove(action.item), 
      state.searchQuery,
    );
  } else if (action is PerformSearchAction) {
    return new AppState(state.items, action.query);
  } else {
    return state;
  }
```

A typed version of a reducer is sometimes offered as an alternative:

```
TypedReducer<A, Z>(reducerZ),
TypedReducer<B, Y>(reducerY),
TypedReducer<C, X> ...
```

Example from redux-dart docs:

```dart
// from redux-dart's combine_reducers.md:
// https://github.com/fluttercommunity/redux.dart/blob/master/doc/combine_reducers.md

// Compose these smaller functions into the full `itemsReducer`.
Reducer<List<String>> itemsReducer = combineReducers<List<String>>([
  // Each `TypedReducer` will glue Actions of a certain type to the given 
  // reducer! This means you don't need to write a bunch of `if` checks 
  // manually, and can quickly scan the list of `TypedReducer`s to see what 
  // reducer handles what action.
  new TypedReducer<List<String>, AddItemAction>(addItemReducer),
  new TypedReducer<List<String>, RemoveItemAction>(removeItemReducer),
]);
```

(Note the justification in the comment in the above code — if the goal is to quickly identify ‘which reducer handles which action’, isn’t it better to just have action-handlers?)



