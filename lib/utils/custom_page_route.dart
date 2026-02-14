import 'package:flutter/material.dart';

/// A custom page route that creates a seamless cross-fade transition between screens.
class FadeTransitionRoute extends PageRouteBuilder {
  final Widget page;

  FadeTransitionRoute({required this.page})
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
            // This creates a true cross-fade effect.
            // The new page fades in using the primary `animation`.
            // The old page fades out using the `secondaryAnimation`.
            return FadeTransition(
              // This handles the new page fading IN (on push) and OUT (on pop).
              opacity: animation,
              child: FadeTransition(
                // This handles the old page fading OUT (when covered) and IN (when revealed).
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(secondaryAnimation),
                child: child,
              ),
            );
          },
          // The duration of the transition.
          transitionDuration: const Duration(milliseconds: 400),
        );
}
