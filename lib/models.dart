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

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id']?.toString() ?? 'unknown',
      externalIds: json['externalIds'] != null 
          ? ExternalIds.fromJson(json['externalIds']) 
          : null,
      title: json['title']?.toString() ?? 'TBD',
      posterUrl: json['posterUrl']?.toString() ?? '',
      description: json['overview']?.toString() ?? 'No data',
      status: json['status']?.toString(),
      releaseDate: DateTime.tryParse(json['releaseDate']?.toString() ?? ''),
      seasons: (json['seasons'] as List?)
              ?.map((s) => Season.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      isFollowed: json['isFollowed'] ?? false,
      isDropped: json['isDropped'] ?? false,
    );
  }
}

class Season {
  final int number;
  final List<Episode> episodes;

  Season({required this.number, required this.episodes});

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      number: json['number'] ?? 0,
      episodes: (json['episodes'] as List?)
              ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
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

  factory ExternalIds.fromJson(Map<String, dynamic> json) {
    return ExternalIds(
      tmdb: json['tmdb']?.toString() ?? '',
      imdb: json['imdb']?.toString() ?? '',
      tvdb: json['tvdb']?.toString() ?? '',
    );
  }
}

class EpisodeHistoryRecord {
  final String id;
  final DateTime watchedAt;

  EpisodeHistoryRecord({required this.id, required this.watchedAt});

  factory EpisodeHistoryRecord.fromJson(Map<String, dynamic> json) {
    return EpisodeHistoryRecord(
      id: json['id']?.toString() ?? '',
      watchedAt: DateTime.parse(json['watchedAt']).toLocal(),
    );
  }
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
  int rewatchCount;
  final List<EpisodeHistoryRecord> history;

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
    this.rewatchCount = 0,
    this.history = const [],
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id']?.toString() ?? 'unknown',
      season: json['seasonNumber'] is int
          ? json['seasonNumber']
          : int.tryParse(json['seasonNumber']?.toString() ?? '1') ?? 1,
      number: json['episodeNumber'] is int
          ? json['episodeNumber']
          : int.tryParse(json['episodeNumber']?.toString() ?? '1') ?? 1,
      title: json['title']?.toString() ?? 'TBD',
      imageUrl: json['posterUrl']?.toString() ?? '',
      airDate: DateTime.tryParse(json['airDate']?.toString() ?? ''),
      watched: json['watched'] == true,
      episodesLeft: json['episodesLeft'] is int
          ? json['episodesLeft']
          : int.tryParse(json['episodesLeft']?.toString() ?? '0') ?? 0,
      description: json['overview']?.toString() ?? 'No data',
      rewatchCount: json['rewatchCount'] ?? 0,
      history: (json['history'] as List?)
              ?.map((e) => EpisodeHistoryRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
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

class DateConstants {
  static const List<String> monthsShort = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  
  static const List<String> monthsFull = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> weekdaysShort = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  
  static const List<String> weekdaysFull = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
}