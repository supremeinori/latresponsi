import 'dart:async';

import 'package:flutter/material.dart';

import '../models/character_model.dart';
import '../services/rick_morty_api_service.dart';
import '../state/app_scope.dart';
import '../state/favorites_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/character_list_tile.dart';
import '../widgets/state_views.dart';
import 'character_detail_screen.dart';

enum CharacterStatusFilter {
  all('All', null),
  alive('Alive', 'alive'),
  dead('Dead', 'dead'),
  unknown('Unknown', 'unknown');

  const CharacterStatusFilter(this.label, this.apiValue);
  final String label;
  final String? apiValue;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final List<CharacterModel> _characters = [];
  CharacterStatusFilter _selectedFilter = CharacterStatusFilter.all;
  String _searchQuery = '';
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _initialized = false;
  Timer? _debounce;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _fetchFirstPage();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _fetchFirstPage() async {
    final token = ++_requestToken;
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasNextPage = false;
    });

    try {
      final api = AppScope.of(context).apiService;
      final result = await api.fetchCharacters(
        status: _selectedFilter.apiValue,
        name: _searchQuery,
        page: 1,
      );
      if (!mounted || token != _requestToken) return;

      setState(() {
        _characters
          ..clear()
          ..addAll(result.characters);
        _hasNextPage = result.hasNextPage;
        _isInitialLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _errorMessage = e.message;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isInitialLoading || _isLoadingMore || !_hasNextPage) return;

    final token = _requestToken;
    final nextPage = _currentPage + 1;
    setState(() => _isLoadingMore = true);

    try {
      final api = AppScope.of(context).apiService;
      final result = await api.fetchCharacters(
        status: _selectedFilter.apiValue,
        name: _searchQuery,
        page: nextPage,
      );
      if (!mounted || token != _requestToken) return;

      setState(() {
        _currentPage = nextPage;
        _characters.addAll(result.characters);
        _hasNextPage = result.hasNextPage;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onFilterSelected(CharacterStatusFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _fetchFirstPage();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      if (trimmed == _searchQuery) return;
      setState(() => _searchQuery = trimmed);
      _fetchFirstPage();
    });
    setState(() {});
  }

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed == _searchQuery && !_isInitialLoading) return;
    setState(() => _searchQuery = trimmed);
    _fetchFirstPage();
  }

  void _resetFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _selectedFilter = CharacterStatusFilter.all;
      _searchQuery = '';
    });
    _fetchFirstPage();
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

  void _openDetail(CharacterModel character) {
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
    final favorites = AppScope.of(context).favoritesController;

    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: _onSearchSubmitted,
                decoration: InputDecoration(
                  hintText: 'Cari nama karakter...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchSubmitted('');
                          },
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CharacterStatusFilter.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = CharacterStatusFilter.values[index];
                    final selected = _selectedFilter == filter;
                    return ChoiceChip(
                      label: Text(filter.label),
                      selected: selected,
                      onSelected: (_) => _onFilterSelected(filter),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.14),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? AppTheme.primary : AppTheme.ink,
                      ),
                      side: BorderSide(
                        color: selected ? AppTheme.primary : AppTheme.border,
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(
          child: _buildBody(favorites),
        ),
      ],
    );
  }

  Widget _buildBody(FavoritesController favorites) {
    if (_isInitialLoading) {
      return const LoadingView(message: 'Memuat daftar karakter...');
    }

    if (_errorMessage != null && _characters.isEmpty) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _fetchFirstPage,
      );
    }

    if (_characters.isEmpty) {
      final hasFilter =
          _selectedFilter != CharacterStatusFilter.all || _searchQuery.isNotEmpty;
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Karakter tidak ditemukan',
        subtitle: hasFilter
            ? 'Tidak ada karakter yang cocok dengan pencarian atau filter status.'
            : 'Daftar karakter saat ini kosong.',
        actionLabel: hasFilter ? 'Reset Filter' : 'Muat Ulang',
        onAction: hasFilter ? _resetFilters : _fetchFirstPage,
      );
    }

    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: _fetchFirstPage,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _characters.length + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _characters.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final character = _characters[index];
              final isFav = favorites.isFavorite(character.id);
              return CharacterListTile(
                character: character,
                isFavorite: isFav,
                onTap: () => _openDetail(character),
                onToggleFavorite: () => _toggleFavorite(character),
              );
            },
          ),
        );
      },
    );
  }
}
