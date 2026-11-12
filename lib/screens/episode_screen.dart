import 'package:flutter/material.dart';

import '../models/episode_model.dart';
import '../services/rick_morty_api_service.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class EpisodeScreen extends StatefulWidget {
  const EpisodeScreen({super.key});

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  final _scrollController = ScrollController();
  final List<EpisodeModel> _episodes = [];

  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _initialized = false;

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
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasNextPage = false;
    });

    try {
      final api = AppScope.of(context).apiService;
      final result = await api.fetchEpisodes(page: 1);
      if (!mounted) return;
      setState(() {
        _episodes
          ..clear()
          ..addAll(result.episodes);
        _hasNextPage = result.hasNextPage;
        _isInitialLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isInitialLoading || _isLoadingMore || !_hasNextPage) return;

    final nextPage = _currentPage + 1;
    setState(() => _isLoadingMore = true);

    try {
      final api = AppScope.of(context).apiService;
      final result = await api.fetchEpisodes(page: nextPage);
      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _episodes.addAll(result.episodes);
        _hasNextPage = result.hasNextPage;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const LoadingView(message: 'Memuat daftar episode...');
    }

    if (_errorMessage != null && _episodes.isEmpty) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _fetchFirstPage,
      );
    }

    if (_episodes.isEmpty) {
      return EmptyView(
        icon: Icons.tv_off_outlined,
        title: 'Tidak ada episode',
        subtitle: 'Daftar episode belum tersedia saat ini.',
        actionLabel: 'Muat Ulang',
        onAction: _fetchFirstPage,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFirstPage,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _episodes.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _episodes.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final episode = _episodes[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      episode.episodeCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: AppTheme.mutedInk,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                episode.airDate,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.mutedInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
