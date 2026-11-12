class EpisodeModel {
  const EpisodeModel({
    required this.id,
    required this.name,
    required this.airDate,
    required this.episodeCode,
  });

  final int id;
  final String name;
  final String airDate;
  final String episodeCode;

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'Untitled Episode',
      airDate: (json['air_date'] as String?) ?? '-',
      episodeCode: (json['episode'] as String?) ?? '-',
    );
  }
}

class PaginatedEpisodes {
  const PaginatedEpisodes({
    required this.episodes,
    required this.hasNextPage,
    required this.totalCount,
  });

  final List<EpisodeModel> episodes;
  final bool hasNextPage;
  final int totalCount;
}
