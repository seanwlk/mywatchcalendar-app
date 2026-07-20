class Series {
  final String id;
  final String title;
  final String posterUrl;
  final String description;
  final DateTime startDate;
  final List<Season> seasons;
  bool isFollowed;
  bool isDropped;

  Series({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.startDate,
    required this.seasons,
    this.isFollowed = false,
    this.isDropped = false,
  });
}

class Season {
  final int number;
  final List<Episode> episodes;

  Season({required this.number, required this.episodes});
}

class Episode {
  final String id;
  final int season;
  final int number;
  final String title;
  final String imageUrl;
  final DateTime airDate;
  bool watched;
  final int episodesLeft;
  final String description;

  Episode({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    required this.imageUrl,
    required this.airDate,
    this.watched = false,
    this.episodesLeft = 0,
    this.description = '',
  });
}

class UserStats {
  final int totalSeries;
  final int totalEpisodesWatched;
  final int totalTimeMinutes;

  UserStats({
    required this.totalSeries,
    required this.totalEpisodesWatched,
    required this.totalTimeMinutes,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalSeries: json['totalSeries'] ?? 0,
      totalEpisodesWatched: json['totalEpisodesWatched'] ?? 0,
      totalTimeMinutes: json['totalTimeMinutes'] ?? 0,
    );
  }
}
