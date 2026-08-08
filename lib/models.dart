class Series {
  final String id;
  final ExternalIds? externalIds;
  final String title;
  final String posterUrl;
  final String description;
  final DateTime? releaseDate;
  final String? status;
  final List<Season> seasons;
  bool isFollowed;
  bool isDropped;

  Series({
    required this.id,
    this.externalIds,
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.releaseDate,
    required this.seasons,
    this.status,
    this.isFollowed = false,
    this.isDropped = false,
  });
}

class Season {
  final int number;
  final List<Episode> episodes;

  Season({required this.number, required this.episodes});
}

class ExternalIds {
  final String? tmdb;
  final String? imdb;
  final String? tvdb;

  ExternalIds({
    this.imdb = '',
    this.tmdb = '',
    this.tvdb = ''
  });
}

class Episode {
  final String id;
  final int season;
  final int number;
  final String title;
  final String imageUrl;
  final DateTime? airDate;
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

class AdminUser {
  final String id;
  final String username;
  final String name;
  final bool isAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminUser({
    required this.id,
    required this.username,
    required this.name,
    required this.isAdmin,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isAdmin: json['isAdmin'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }
}

class FollowedSeriesProgress {
  final int total;
  final int watched;

  FollowedSeriesProgress({required this.total, required this.watched});
}

class FollowedSeriesItem {
  final String id;
  final String title;
  final String posterUrl;
  final bool isDropped;
  final FollowedSeriesProgress progress;

  FollowedSeriesItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.isDropped,
    required this.progress,
  });

  factory FollowedSeriesItem.fromJson(Map<String, dynamic> json) {
    return FollowedSeriesItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      posterUrl: json['posterUrl']?.toString() ?? '',
      isDropped: json['isDropped'],
      progress: FollowedSeriesProgress(
        total: json['progress']?['total'] ?? 0,
        watched: json['progress']?['watched'] ?? 0,
      ),
    );
  }
}

class WatchHistoryRecord {
  final DateTime date;
  final int runtime;

  WatchHistoryRecord({
    required this.date,
    required this.runtime,
  });

  factory WatchHistoryRecord.fromJson(Map<String, dynamic> json) {
    return WatchHistoryRecord(
      date: DateTime.parse(json['date']).toLocal(),
      runtime: json['runtime'] ?? 0,
    );
  }
}

class WatchHistoryResponse {
  final bool hasMore;
  final List<WatchHistoryRecord> records;

  WatchHistoryResponse({
    required this.hasMore,
    required this.records,
  });

  factory WatchHistoryResponse.fromJson(Map<String, dynamic> json) {
    return WatchHistoryResponse(
      hasMore: json['hasMore'] ?? false,
      records: (json['records'] as List?)
              ?.map((e) => WatchHistoryRecord.fromJson(e))
              .toList() ??
          [],
    );
  }
}