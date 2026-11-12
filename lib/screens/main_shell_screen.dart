import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'episode_screen.dart';
import 'favorite_screen.dart';
import 'home_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'Rick & Morty',
    'Favorites',
    'Episodes',
  ];

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dan kembali ke halaman login?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AppScope.of(context).authController.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final username = scope.authController.currentUser?.username;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
        actions: [
          if (username != null && username.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '@$username',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedInk,
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: _confirmLogout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomeScreen(),
          FavoriteScreen(
            onExploreCharacters: () => setState(() => _selectedIndex = 0),
          ),
          const EpisodeScreen(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: scope.favoritesController,
        builder: (context, _) {
          final favCount = scope.favoritesController.count;
          return Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Characters',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: favCount > 0,
                    label: Text('$favCount'),
                    child: const Icon(Icons.favorite_outline),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: favCount > 0,
                    label: Text('$favCount'),
                    child: const Icon(Icons.favorite),
                  ),
                  label: 'Favorites',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.tv_outlined),
                  selectedIcon: Icon(Icons.tv),
                  label: 'Episodes',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
