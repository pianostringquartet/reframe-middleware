import 'dart:core';

import 'package:quiver/core.dart';
import 'package:meta/meta.dart';
import 'package:redux/redux.dart';

import 'action.dart';

// A side-effect asynchronously resolves to a list of additional Events.
typedef SideEffect = Future<List<ReframeAction>> Function();

Future<List<ReframeAction>> noEffect() async => [];

// A HandlerResponse is a description of how the app changes due to an event,
// i.e. (1) how the state changes and/or (2) which side-effects to run.
@immutable
class ReframeResponse<S> {
  final Optional<S> nextState;
  final SideEffect effect;

  const ReframeResponse({
    this.nextState = const Optional.absent(),
    this.effect = noEffect,
  });

  static ReframeResponse<S> stateUpdate<S>(S state) =>
      ReframeResponse<S>(nextState: Optional.of(state));

  static ReframeResponse<S> sideEffect<S>(SideEffect sideEffect) =>
      ReframeResponse<S>(effect: sideEffect);

  ReframeResponse<B> map<B>(B Function(S) f) =>
      ReframeResponse<B>(nextState: nextState.transform(f), effect: effect);

  @override
  String toString() {
    return 'ReframeResponse{nextState: $nextState, effect: $effect}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReframeResponse &&
          runtimeType == other.runtimeType &&
          nextState == other.nextState &&
          effect == other.effect;

  @override
  int get hashCode => nextState.hashCode ^ effect.hashCode;
}



// Type signature required by redux-dart
typedef Middleware<S> = void Function(Store<S>, dynamic, NextDispatcher);

/* Reframe uses a single middleware,
 which runs the descriptions of state-updates and side-effects
 returned by an event's handler. */
Middleware<S> reframeMiddleware<S, E>(E effects) =>
    (Store<S> store, dynamic event, NextDispatcher next) {
      if (event is ReframeAction) {
        event.handle(store.state, effects)
          ..nextState
              // StateUpdate will bring the new-state to the reframe-style reducer
              .ifPresent((newState) => store.dispatch(StateUpdate(newState)))
          ..effect().then((events) => events.forEach(store.dispatch));
      }

      // pass (1) the event to next middleware (e.g. 3rd party middleware)
      // and (2) a StateUpdate to the reducer
      next(event);
    };

/* Reframe uses a single reducer,
 which exchanges the app's old state for the new state.
 Typical Redux reducers (logic for pure state updates) is instead part of
 an Event's handle method. */
//AppState reframeReducer(AppState state, dynamic event) =>
//    event is StateUpdate ? event.state : state;

// ... when is this given its own proper type S?
// ... it will treat the S as dynamic, no?

typedef Reducer<S> = S Function(S, dynamic);

// Type signature required by redux-dart
S reframeReducer<S>(S state, dynamic event) =>
    event is StateUpdate ? event.state : state;
