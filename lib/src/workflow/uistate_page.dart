import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:uistate/src/state_management/uistate.dart';

/// The [Page] implemenation for the UI state workflow.
abstract class UIStatePage extends Page<PageConfiguration> {
  /// Creates an instance of [UIStatePage].
  UIStatePage({
    required this.config,
    this.showAnimation = false,
  }) : super(key: ValueKey(config));

  /// The associated configuration.
  final PageConfiguration config;

  /// Specified whether a transition animation should be shown.
  final bool showAnimation;

  @override
  Route<PageConfiguration> createRoute(BuildContext context) {
    if (showAnimation) {
      if (Platform.isIOS) {
        return CupertinoPageRoute(
          settings: this,
          builder: (context) {
            return buildView(context, config);
          },
        );
      } else {
        return MaterialPageRoute(
          settings: this,
          builder: (context) {
            return buildView(context, config);
          },
        );
      }
    } else {
      return PageRouteBuilder(
        settings: this,
        transitionDuration: Duration(seconds: 0),
        pageBuilder: (context, __, ___) {
          return buildView(context, config);
        },
      );
    }
  }

  Widget buildView(BuildContext context, PageConfiguration config);
}

/// Represents the route configuration for [UIStatePage].
///
/// The configuration consists of the [UIState] for the page and the associated
/// location.
class PageConfiguration with EquatableMixin {
  /// Creates an instance of [PageConfiguration].
  const PageConfiguration({
    required this.state,
    this.location,
    this.data = const {},
  });

  /// Creates an empty instance of [PageConfiguration].
  PageConfiguration.empty({String? location})
      : this(
          state: UIState(id: ''),
          location: location,
        );

  /// The corresponding state.
  final UIState state;

  /// The corresponding location.
  final String? location;

  /// Included transfer data.
  final Map<String, dynamic> data;

  String get stateId => state.id;

  @override
  List<Object?> get props => [state, location, data];
}
