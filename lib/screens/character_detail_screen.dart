import 'package:flutter/material.dart';

import '../models/character_model.dart';
import '../services/rick_morty_api_service.dart';
import '../state/app_scope.dart';
import '../state/favorites_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class CharacterDetailScreen extends StatefulWidget {
  const CharacterDetailScreen({
    super.key,
    required this.characterId,
    this.initialCharacter,
  });

  final int characterId;
  final CharacterModel? initialCharacter;

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  CharacterModel? _character;
  bool _isLoading = true;
  String? _errorMessage;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _character = widget.initialCharacter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = AppScope.of(context).apiService;
      final detail = await api.fetchCharacterDetail(widget.characterId);
      if (!mounted) return;
      setState(() {
        _character = detail;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(CharacterModel character) async {
    final favorites = AppScope.of(context).favoritesController;
    final added = await favorites.toggleFavorite(character);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added
                ? '${character.name} ditambahkan ke favorit'
                : '${character.name} dihapus dari favorit',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = AppScope.of(context).favoritesController;
    final character = _character;

    return Scaffold(
      appBar: AppBar(
        title: Text(character?.name ?? 'Detail Karakter'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
        actions: [
          if (character != null)
            ListenableBuilder(
              listenable: favorites,
              builder: (context, _) {
                final isFav = favorites.isFavorite(character.id);
                return IconButton(
                  onPressed: () => _toggleFavorite(character),
                  tooltip:
                      isFav ? 'Hapus dari favorit' : 'Tambah ke favorit',
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? AppTheme.favorite : AppTheme.ink,
                  ),
                );
              },
            ),
        ],
      ),
      body: _buildBody(character, favorites),
    );
  }

  Widget _buildBody(CharacterModel? character, FavoritesController favorites) {
    if (character == null && _isLoading) {
      return const LoadingView(message: 'Memuat detail karakter...');
    }

    if (character == null && _errorMessage != null) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _loadDetail,
      );
    }

    if (character == null) {
      return ErrorView(
        message: 'Data karakter tidak tersedia.',
        onRetry: _loadDetail,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_errorMessage != null) ...[
                Card(
                  color: AppTheme.statusDead.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.statusDead,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.statusDead,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadDetail,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.15,
                      child: character.image.isNotEmpty
                          ? Image.network(
                              character.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppTheme.border,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.person_outline,
                                  size: 64,
                                  color: AppTheme.mutedInk,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.border,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.person_outline,
                                size: 64,
                                color: AppTheme.mutedInk,
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      character.name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.ink,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    StatusBadge(
                                      status: character.status,
                                      compact: false,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ListenableBuilder(
                            listenable: favorites,
                            builder: (context, _) {
                              final isFav = favorites.isFavorite(character.id);
                              return SizedBox(
                                width: double.infinity,
                                child: isFav
                                    ? OutlinedButton.icon(
                                        onPressed: () =>
                                            _toggleFavorite(character),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(46),
                                          foregroundColor: AppTheme.favorite,
                                          side: const BorderSide(
                                            color: AppTheme.favorite,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(Icons.favorite),
                                        label: const Text('Hapus dari Favorit'),
                                      )
                                    : FilledButton.icon(
                                        onPressed: () =>
                                            _toggleFavorite(character),
                                        icon: const Icon(Icons.favorite_border),
                                        label: const Text('Tambah ke Favorit'),
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Karakter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: Icons.science_outlined,
                        label: 'Spesies',
                        value: character.species,
                      ),
                      const Divider(height: 22, color: AppTheme.border),
                      _InfoRow(
                        icon: Icons.wc_outlined,
                        label: 'Gender',
                        value: character.gender,
                      ),
                      const Divider(height: 22, color: AppTheme.border),
                      _InfoRow(
                        icon: Icons.public_outlined,
                        label: 'Origin',
                        value: character.originName,
                      ),
                      const Divider(height: 22, color: AppTheme.border),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: character.locationName,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Unknown' : value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
