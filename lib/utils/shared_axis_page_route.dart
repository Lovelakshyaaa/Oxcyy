import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// A custom page route that uses the `SharedAxisTransition` for a modern
/// and smooth navigation effect between screens.
class SharedAxisPageRoute extends PageRouteBuilder {
  final Widget page;

  SharedAxisPageRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            // Use a shared axis transition for a horizontal slide and fade effect.
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
          // A slightly shorter duration feels more responsive for axis transitions.
          transitionDuration: const Duration(milliseconds: 300),
        );
}
