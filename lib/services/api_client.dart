import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client = http.Client();

  Future<UserStats?> fetchUserStats() async {
    try {
      await _ensureAuth();
      final uri = Uri.parse('${AuthService.instance.apiBaseUrl}/user/stats');
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return UserStats.fromJson(body);
      }
    } catch (_) {}
    return null;
  }

  /// Returns null on failure, [] when the list is genuinely empty.
  Future<List<MapEntry<Series, Episode>>?> fetchUnwatchedEpisodes({
    required int page,
    required int pageSize,
  }) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/unwatched?page=$page&pageSize=$pageSize',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body)['items'];
        if (body is List) {
          return body.map<MapEntry<Series, Episode>>((item) {
            final data = item as Map<String, dynamic>;
            return _parseEpisodeEntry(data);
          }).toList();
        }
        return [];
      }
    } catch (_) {}
    return null;
  }

  /// Returns null on failure, [] when the list is genuinely empty.
  Future<List<MapEntry<Series, Episode>>?> fetchCalendarEpisodes({
    required int page,
    required int pageSize,
    String direction = 'future',
  }) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/calendar?page=$page&pageSize=$pageSize&direction=$direction',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body)['items'];
        if (body is List) {
          return body.map<MapEntry<Series, Episode>>((item) {
            final data = item as Map<String, dynamic>;
            return _parseEpisodeEntry(data);
          }).toList();
        }
        return [];
      }
    } catch (_) {}
    return null;
  }

  /// Returns null on failure, [] when there are genuinely no matches.
  Future<List<Series>?> searchSeries({
    required String query,
    required int page,
    required int pageSize,
  }) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/search?q=${Uri.encodeQueryComponent(query)}&page=$page&pageSize=$pageSize',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body)['items'];
        if (body is List) {
          return body.map<Series>((item) {
            final data = item as Map<String, dynamic>;
            return Series(
              id: data['id']?.toString() ?? 'unknown',
              title: data['title']?.toString() ?? 'Series',
              posterUrl: data['posterUrl']?.toString() ?? '',
              description: data['overview']?.toString() ?? '',
              startDate:
                  DateTime.tryParse(data['releaseDate']?.toString() ?? '') ??
                  DateTime.now(),
              seasons: [],
              isFollowed: data['isFollowed'] ?? false,
            );
          }).toList();
        }
        return [];
      }
    } catch (_) {}
    return null;
  }

  Future<Series?> fetchSeriesbyId(String seriesId) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/$seriesId',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map<String, dynamic>) {
          return _parseSeries(body);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Series?> fetchEpisodebyId(String episodeId) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/episodes/$episodeId',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map<String, dynamic>) {
          return _parseSeries(body);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Episode?> getNextUnwatchedEpisode(String seriesId) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/$seriesId/next-unwatched-episode',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Episode(
          id:
              data['latestEpisode']['id']?.toString() ??
              data['id']?.toString() ??
              'unknown',
          season: data['latestEpisode']['seasonNumber'] is int
              ? data['latestEpisode']['seasonNumber']
              : int.tryParse(
                      data['latestEpisode']['seasonNumber']?.toString() ?? '1',
                    ) ??
                    1,
          number: data['latestEpisode']['episodeNumber'] is int
              ? data['latestEpisode']['episodeNumber']
              : int.tryParse(
                      data['latestEpisode']['episodeNumber']?.toString() ?? '1',
                    ) ??
                    1,
          title: data['latestEpisode']['title']?.toString() ?? 'Episode',
          imageUrl: data['latestEpisode']['posterUrl']?.toString() ?? '',
          airDate:
              DateTime.tryParse(
                data['latestEpisode']['airDate']?.toString() ?? '',
              ) ??
              DateTime.now(),
          watched: data['watched'] == true,
          episodesLeft: data['latestEpisode']['episodesLeft'] is int
              ? data['latestEpisode']['episodesLeft']
              : int.tryParse(
                      data['latestEpisode']['episodesLeft']?.toString() ?? '0',
                    ) ??
                    0,
          description: data['latestEpisode']['overview']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return null;
  }

  Future<Episode?> getEpisode(String episodeId) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/episodes/$episodeId',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Episode(
          id:
              data['episode']['id']?.toString() ??
              data['id']?.toString() ??
              'unknown',
          season: data['episode']['seasonNumber'] is int
              ? data['episode']['seasonNumber']
              : int.tryParse(
                      data['episode']['seasonNumber']?.toString() ?? '1',
                    ) ??
                    1,
          number: data['episode']['episodeNumber'] is int
              ? data['episode']['episodeNumber']
              : int.tryParse(
                      data['episode']['episodeNumber']?.toString() ?? '1',
                    ) ??
                    1,
          title: data['episode']['title']?.toString() ?? 'Episode',
          imageUrl: data['episode']['posterUrl']?.toString() ?? '',
          airDate:
              DateTime.tryParse(data['episode']['airDate']?.toString() ?? '') ??
              DateTime.now(),
          watched: data['watched'] == true,
          description: data['episode']['overview']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return null;
  }

  Future<bool> markEpisodeWatched(String episodeId, bool watched) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/episodes/$episodeId/mark-watched',
      );
      final response = watched
          ? await _client.post(uri, headers: _authHeaders()).timeout(_timeout)
          : await _client
                .delete(uri, headers: _authHeaders())
                .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> followSeries(String seriesId, bool followed) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/$seriesId/follow',
      );
      final response = followed
          ? await _client.post(uri, headers: _authHeaders()).timeout(_timeout)
          : await _client
                .delete(uri, headers: _authHeaders())
                .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> changeSeriesStatus(String seriesId, bool dropped) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/$seriesId/status',
      );
      final response = await _client
          .patch(
            uri,
            headers: _authHeaders(),
            body: jsonEncode({'status': dropped ? 'DROPPED' : 'WATCHING'}),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _ensureAuth() async {
    final auth = AuthService.instance;
    if (!await auth.ensureAccessToken()) {
      throw StateError('Authentication required. Token refresh failed.');
    }
  }

  MapEntry<Series, Episode> _parseEpisodeEntry(Map<String, dynamic> data) {
    final series = Series(
      id: data['seriesId']?.toString() ?? 'unknown',
      title: data['seriesTitle']?.toString() ?? 'Unknown Series',
      posterUrl: data['posterUrl']?.toString() ?? '',
      description: data['overview']?.toString() ?? '',
      startDate:
          DateTime.tryParse(data['releaseYear']?.toString() ?? '') ??
          DateTime.now(),
      seasons: [],
      isDropped: false,
      isFollowed: true,
    );
    final episode = Episode(
      id:
          data['latestEpisode']['id']?.toString() ??
          data['id']?.toString() ??
          'unknown',
      season: data['latestEpisode']['seasonNumber'] is int
          ? data['latestEpisode']['seasonNumber']
          : int.tryParse(
                  data['latestEpisode']['seasonNumber']?.toString() ?? '1',
                ) ??
                1,
      number: data['latestEpisode']['episodeNumber'] is int
          ? data['latestEpisode']['episodeNumber']
          : int.tryParse(
                  data['latestEpisode']['episodeNumber']?.toString() ?? '1',
                ) ??
                1,
      title: data['latestEpisode']['title']?.toString() ?? 'Episode',
      imageUrl: data['latestEpisode']['posterUrl']?.toString() ?? '',
      airDate:
          DateTime.tryParse(
            data['latestEpisode']['airDate']?.toString() ?? '',
          ) ??
          DateTime.now(),
      watched: data['watched'] == true,
      episodesLeft: data['latestEpisode']['episodesLeft'] is int
          ? data['latestEpisode']['episodesLeft']
          : int.tryParse(
                  data['latestEpisode']['episodesLeft']?.toString() ?? '0',
                ) ??
                0,
      description: data['latestEpisode']['overview']?.toString() ?? '',
    );
    return MapEntry(series, episode);
  }

  Series _parseSeries(Map<String, dynamic> data) {
    List<Season> parsedSeasons = [];
    if (data['seasons'] != null && data['seasons'] is List) {
      parsedSeasons = (data['seasons'] as List).map((seasonJson) {
        List<Episode> parsedEpisodes = [];
        if (seasonJson['episodes'] != null && seasonJson['episodes'] is List) {
          parsedEpisodes = (seasonJson['episodes'] as List).map((epJson) {
            return Episode(
              id: epJson['id']?.toString() ?? 'unknown',
              title: epJson['title']?.toString() ?? 'Unknown',
              number: epJson['episodeNumber'] ?? 0,
              season: epJson['seasonNumber'] ?? 0,
              airDate:
                  DateTime.tryParse(epJson['airDate']?.toString() ?? '') ??
                  DateTime.now(),
              imageUrl: epJson['posterUrl']?.toString() ?? '',
              watched: epJson['watched'] ?? false,
              description: epJson['overview'] ?? '',
            );
          }).toList();
        }
        return Season(
          number: seasonJson['number'] ?? 0,
          episodes: parsedEpisodes,
        );
      }).toList();
    }
    return Series(
      id: data['id']?.toString() ?? 'unknown',
      title: data['title']?.toString() ?? 'Series',
      posterUrl: data['posterUrl']?.toString() ?? '',
      description: data['overview']?.toString() ?? '',
      startDate:
          DateTime.tryParse(data['releaseDate']?.toString() ?? '') ??
          DateTime.now(),
      seasons: parsedSeasons,
      isFollowed: data['isFollowed'] ?? false,
      isDropped: data['isDropped'] ?? false,
    );
  }

  Map<String, String> _authHeaders() {
    final auth = AuthService.instance;
    return {
      'Content-Type': 'application/json',
      'Authorization': auth.bearerToken,
    };
  }
}
