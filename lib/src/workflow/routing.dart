import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uistate/src/state_management/uistate.dart';
import 'package:uistate/src/state_management/uistate_manager.dart';
import 'package:uistate/src/utils/uistate_utils.dart';
import 'package:uistate/src/workflow/uistate_page.dart';
import 'package:uistate/src/workflow/uistate_workflow.dart';

/// The default [RouteInformationParser] implementation for [UIStateWorkflow].
///
/// This class manages location changes and faciliates them with the state
/// of [UIStateManager]. Location changes coming from the system are validated
/// and aligned to corresponding states in the state manager. Also changes of
/// the state manager are reflected by transfering valid locations back to the
/// system.
///
/// This class is passed into a [Router] or [MaterialApp] instance as route
/// information parser. It should not be instantiated autonomously. Instead
/// [UIStateWorkflow] should be used to get hold on an instance.
/// For further information see [UIStateWorkflow].
class UIStateInformationParser
    extends RouteInformationParser<PageConfiguration> {
  /// Creates an instance of [UIStateInformationParser].
  UIStateInformationParser({
    required this.manager,
    this.enableLocations = false,
    this.useFullLocations = false,
    LocationConverter? locationConverter,
  }) : locationConverter = locationConverter ??
            LocationConverter(
              states: manager.states,
              useFullLocations: enableLocations && useFullLocations,
            );

  /// The manager of parser.
  final UIStateManager manager;

  /// Specifies whether locations should be enabled.
  final bool enableLocations;

  /// Specifies whether full location names should be used.
  final bool useFullLocations;

  /// The used location converter.
  final LocationConverter locationConverter;

  @override
  Future<PageConfiguration> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final location = routeInformation.location != null
        ? Uri.parse(routeInformation.location!).path
        : null;

    final state = locationConverter.stateOfLocation(location);

    return SynchronousFuture(
      enableLocations && state != null
          ? PageConfiguration(
              state: state,
              location: location,
            )
          : PageConfiguration.empty(
              location: locationConverter.locationOfState(
                manager.currentState!,
              ),
            ),
    );
  }

  @override
  RouteInformation? restoreRouteInformation(PageConfiguration configuration) {
    return RouteInformation(location: configuration.location);
  }
}

/// The default [RouterDelegate] implementation for [UIStateWorkflow].
///
/// This class manages the changes on the route locations manages the
/// communication between [UIStateManager] and [Router]. Therefore it subscribes
/// to the change events of the state manager. Location changes coming from the
/// system over [UIStateInformationParser] are also reflected by updating the
/// state manager.
///
/// This class is passed into a [Router] or [MaterialApp] instance as router
/// delegate. It should not be instantiated autonomously. Instead
/// [UIStateWorkflow] should be used to get hold on an instance.
/// For further information see [UIStateWorkflow].
///
class UIStateDelegate extends RouterDelegate<PageConfiguration>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<PageConfiguration> {
  /// Creates an instance of [UIStateDelegate].
  UIStateDelegate({
    required this.manager,
    required this.pageSelector,
    this.enableLocations = false,
    this.useFullLocations = false,
    LocationConverter? locationConverter,
  })  : locationConverter = locationConverter ??
            LocationConverter(
              states: manager.states,
              useFullLocations: enableLocations && useFullLocations,
            ),
        _navigatorKey = GlobalKey<NavigatorState>() {
    manager.addListener(_managerStateChanged);
  }

  /// The used manager of this delegate.
  final UIStateManager manager;

  /// The used page selector.
  final UIStatePage Function(PageConfiguration?) pageSelector;

  /// Specifies whether locations should be enabled.
  final bool enableLocations;

  /// Specifies whether full location names should be used.
  final bool useFullLocations;

  /// The used location converter.
  final LocationConverter locationConverter;

  final GlobalKey<NavigatorState> _navigatorKey;

  PageConfiguration? _currentConfiguration;

  @override
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  @override
  PageConfiguration? get currentConfiguration => enableLocations
      ? _currentConfiguration
      : PageConfiguration.empty(location: '/');

  static UIStateDelegate of(BuildContext context) {
    return Router.of(context).routerDelegate as UIStateDelegate;
  }

  @override
  void dispose() {
    super.dispose();
    manager.removeListener(_managerStateChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [pageSelector(_currentConfiguration)],
      onPopPage: (route, result) => route.didPop(result),
    );
  }

  @override
  Future<void> setNewRoutePath(PageConfiguration configuration) {
    manager.goToState(configuration.state);

    return SynchronousFuture<void>(null);
  }

  /// Triggers the alignment of the route configuration if the manager state
  /// changes.
  void _managerStateChanged() {
    _alignCurrentConfiguration();
    notifyListeners();
  }

  /// Aligns the route configuration to the current manager state.
  void _alignCurrentConfiguration([PageConfiguration? configuration]) {
    final currentState = manager.currentState;
    if (currentState != null) {
      if (configuration == null || configuration.state != currentState) {
        _currentConfiguration = PageConfiguration(
          state: currentState,
          location: locationConverter.locationOfState(currentState),
        );
      } else {
        _currentConfiguration = configuration;
      }
    }
  }
}

/// Handles the conversion of UI states into and from url locations.
///
/// The class provides the methods [locationOfState] and [stateOfLocation] to
/// handle the conversion of states and location strings. Therefore a set of
/// states must be provided, which is then searched for the conversion from url
/// locations. The default conversion behavior matches url locations by the
/// exact state names.
///
/// So if the state `child` would be selected in this example
/// ```dart
/// GroupState(
///   id: 'group',
///   innerStates: [UIState(id: 'child')],
/// )
/// ```
/// the location is mapped to `/child`. By setting the parameter
/// [useFullLocations] to `true`, the parent state names are included in the
/// resulting url. So the result for the previous example would be
/// `/group/child`.
class LocationConverter {
  /// Creates an instance of [LocationConverter].
  const LocationConverter({
    required this.states,
    this.useFullLocations = false,
  });

  /// Is searched for corresponding states to available locations.
  final Set<UIState> states;

  /// Controls whether parent locationsshould be included.
  final bool useFullLocations;

  /// Converts the provided state to a url location.
  ///
  /// The state name prepended by a single '/' is returned as the location by
  /// default. If [useFullLocations] is set to `true`, the location is build by
  /// prepending the state's name with all parent state names.
  String locationOfState(UIState state) {
    final states = [state];
    if (useFullLocations) {
      states.insertAll(0, UIStateUtils.parentsOf(state, fromTopmost: true));
    }

    final path =
        states.map((e) => e.id.trim().replaceAll('\s+', '_')).join('/');

    return '/$path';
  }

  /// Searches the corresponding state object to the provided path.
  ///
  /// The states in [states] is searched for the state which corresponds to the
  /// last part of the provided path. If no state is found, null is returned.
  UIState? stateOfLocation(String? path) {
    if (path != null) {
      return UIStateUtils.tryfindState(path.split('/').last, states);
    }

    return null;
  }
}
