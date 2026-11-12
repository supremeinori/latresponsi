import 'package:flutter/widgets.dart';

import '../services/rick_morty_api_service.dart';
import 'auth_controller.dart';
import 'favorites_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.authController,
    required this.favoritesController,
    required this.apiService,
    required super.child,
  });

  final AuthController authController;
  final FavoritesController favoritesController;
  final RickMortyApiService apiService;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return authController != oldWidget.authController ||
        favoritesController != oldWidget.favoritesController ||
        apiService != oldWidget.apiService;
  }
}
