import 'package:flutter/material.dart';

/// A global key for the navigator state, allowing access to the navigator
/// from anywhere in the app. This is useful for performing navigation actions
/// without needing to pass the context around.
///
/// Add this key to your MaterialApp or WidgetsApp:
/// ```dart
/// MaterialApp(
///   navigatorKey: navigatorKey,
///   .../// )
/// ```
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// A global route observer that can be used to observe route changes in the app.
/// This observer can be used to listen for route changes, such as when a new
/// route is pushed or popped, and can be useful for analytics or logging purposes.
///
/// To use this observer, add it to your MaterialApp or WidgetsApp:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [routeObserver],
///   .../// )
/// ```
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// A utility class for managing navigation routes in a Flutter application.
/// This class provides methods for pushing, replacing, and removing routes,
/// as well as handling animations during navigation.
/// Usage:
/// - Use `KRoute.push(context: context, page: YourPage())`
///   to navigate to a new page.
/// - Use `KRoute.pushReplacement(context: context, page: YourPage())`
///   to replace the current page with a new one.
/// - Use `KRoute.pushRemove(context: context, page: YourPage())`
///   to navigate to a new page and remove all previous pages from the stack.
/// - Use `KRoute.pushFadeAnimation(context: context, page: YourPage())`
///   to navigate to a new page with a fade animation.
/// - Use `KRoute.pushNamed(context: context, routeName: '/yourRoute')
///   to navigate to a named route.
/// - Use `KRoute.pushNamedAndRemove(context: context, newRouteName: '/yourRoute')
///   to navigate to a named route and remove all previous routes from the stack.
/// - Use `KRoute.pushRemove(context: context, page: YourPage())`
///   to navigate to a new page and remove all previous pages from the stack.
/// - Use `KRoute.pushReplacement(context: context, page: YourPage())`
///   to replace the current page with a new one.
/// - Use `KRoute.pushNamedAndRemove(context: context, newRouteName: '/yourRoute')
///   to navigate to a named route and remove all previous routes from the stack.
class KRoute {
  static final KRoute _instance = KRoute._internal();

  factory KRoute() => _instance;

  KRoute._internal();

  static Future<void> pushRemove({
    required BuildContext context,
    required Widget page,
  }) async {
    await Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute(builder: (context) => page),
      (_) => false,
    );
  }

  /// Default Duration is `800` milliseconds.
  static Future<dynamic> pushFadeAnimation({
    required BuildContext context,
    required Widget page,
    int? durationMilliseconds,
  }) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration(
          milliseconds: durationMilliseconds ?? 1500,
        ),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  static Future<void> push({
    required BuildContext context,
    required Widget page,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  static Future<void> pushNamed({
    required BuildContext context,
    required String routeName,
  }) async {
    await Navigator.pushNamed<void>(context, routeName);
  }

  static Future<void> pushNamedAndRemove({
    required BuildContext context,
    required String newRouteName,
  }) async {
    await Navigator.pushNamedAndRemoveUntil<void>(
      context,
      newRouteName,
      (_) => false,
    );
  }

  static Future<void> pushReplacement({
    required BuildContext context,
    required Widget page,
  }) async {
    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
