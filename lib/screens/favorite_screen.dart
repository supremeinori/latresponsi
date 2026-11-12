import 'package:flutter/material.dart';

import '../models/character_model.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/character_list_tile.dart';
import '../widgets/state_views.dart';
import 'character_detail_screen.dart';

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({
    super.key,
    required this.onExploreCharacters,
  });

  final VoidCallback onExploreCharacters;

  Future<void> _removeFavorite(
    BuildContext context,
    CharacterModel character,
  ) async {
    final favorites = AppScope.of(context).favoritesController;
    await favorites.removeFavorite(character.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${character.name} dihapus dari favorit'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _openDetail(BuildContext context, CharacterModel character) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CharacterDetailScreen(
          characterId: character.id,
          initialCharacter: character,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritesController = AppScope.of(context).favoritesController;

    return ListenableBuilder(
      listenable: favoritesController,
      builder: (context, _) {
        final favorites = favoritesController.favorites;
        if (favorites.isEmpty) {
          return EmptyView(
            icon: Icons.favorite_border_rounded,
            title: 'Daftar Favorit Kosong',
            subtitle:
                'Belum ada karakter yang ditandai favorit. Ketuk ikon hati pada karakter untuk menyimpannya.',
            actionLabel: 'Lihat Daftar Karakter',
            onAction: onExploreCharacters,
          );
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Text(
                'Geser item ke kiri untuk menghapus karakter dari favorit.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.mutedInk,
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: favorites.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final character = favorites[index];
                  return Dismissible(
                    key: ValueKey('favorite_${character.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.statusDead,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Hapus',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) => _removeFavorite(context, character),
                    child: CharacterListTile(
                      character: character,
                      isFavorite: true,
                      subtitleExtra: character.species,
                      onTap: () => _openDetail(context, character),
                      onToggleFavorite: () => _removeFavorite(context, character),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
