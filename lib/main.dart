import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';
import 'services/local_db_service.dart';
import 'services/rick_morty_api_service.dart';
import 'services/session_service.dart';
import 'state/app_scope.dart';
import 'state/auth_controller.dart';
import 'state/favorites_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/state_views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionService = SessionService();
  final authDatabase = LocalDbService();
  final apiService = RickMortyApiService();
  final authController = AuthController(
    database: authDatabase,
    sessionService: sessionService,
  );
  final favoritesController = FavoritesController(
    sessionService: sessionService,
  );

  await authController.restoreSession();
  await favoritesController.syncForUser(authController.currentUser?.username);

  runApp(
    RickMortyApp(
      authController: authController,
      favoritesController: favoritesController,
      apiService: apiService,
    ),
  );
}

class RickMortyApp extends StatefulWidget {
  const RickMortyApp({
    super.key,
    required this.authController,
    required this.favoritesController,
    required this.apiService,
  });

  final AuthController authController;
  final FavoritesController favoritesController;
  final RickMortyApiService apiService;

  @override
  State<RickMortyApp> createState() => _RickMortyAppState();
}

class _RickMortyAppState extends State<RickMortyApp> {
  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    widget.favoritesController.syncForUser(
      widget.authController.currentUser?.username,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      authController: widget.authController,
      favoritesController: widget.favoritesController,
      apiService: widget.apiService,
      child: MaterialApp(
        title: 'Rick & Morty Explorer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: ListenableBuilder(
          listenable: widget.authController,
          builder: (context, _) {
            if (!widget.authController.isInitialized) {
              return const Scaffold(
                body: LoadingView(message: 'Memeriksa sesi...'),
              );
            }
            if (!widget.authController.isLoggedIn) {
              return const LoginScreen();
            }
            return const MainShellScreen();
          },
        ),
      ),
    );
  }
}
