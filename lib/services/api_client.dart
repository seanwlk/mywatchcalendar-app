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

  Future<List<FollowedSeriesItem>?> fetchFollowedSeries({
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/series/followed?page=$page&pageSize=$pageSize',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body)['items'];
        if (body is List) {
          return body.map((item) => FollowedSeriesItem.fromJson(item)).toList();
        }
      }
    } catch (_) {}
    return null;
  }

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
              status: data['status']?.toString(),
              releaseDate:
                  DateTime.tryParse(data['releaseDate']?.toString() ?? ''),
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
          title: data['latestEpisode']['title']?.toString() ?? 'TBD',
          imageUrl: data['latestEpisode']['posterUrl']?.toString() ?? '',
          airDate:
              DateTime.tryParse(
                data['latestEpisode']['airDate']?.toString() ?? ''
              ),
          watched: data['watched'] == true,
          episodesLeft: data['latestEpisode']['episodesLeft'] is int
              ? data['latestEpisode']['episodesLeft']
              : int.tryParse(
                      data['latestEpisode']['episodesLeft']?.toString() ?? '0',
                    ) ??
                    0,
          description:
              data['latestEpisode']['overview']?.toString() ?? 'No data',
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
          title: data['episode']['title']?.toString() ?? 'TBD',
          imageUrl: data['episode']['posterUrl']?.toString() ?? '',
          airDate:
              DateTime.tryParse(data['episode']['airDate']?.toString() ?? ''),
          watched: data['watched'] == true,
          description: data['episode']['overview']?.toString() ?? 'No Data',
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
      status: data['status']?.toString(),
      releaseDate:
          DateTime.tryParse(data['releaseDate']?.toString() ?? ''),
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
      title: data['latestEpisode']['title']?.toString() ?? 'TBD',
      imageUrl: data['latestEpisode']['posterUrl']?.toString() ?? '',
      airDate:
          DateTime.tryParse(
            data['latestEpisode']['airDate']?.toString() ?? ''
          ),
      watched: data['watched'] == true,
      episodesLeft: data['latestEpisode']['episodesLeft'] is int
          ? data['latestEpisode']['episodesLeft']
          : int.tryParse(
                  data['latestEpisode']['episodesLeft']?.toString() ?? '0',
                ) ??
                0,
      description: data['latestEpisode']['overview']?.toString() ?? 'No data',
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
              title: epJson['title']?.toString() ?? 'TBD',
              number: epJson['episodeNumber'] ?? 0,
              season: epJson['seasonNumber'] ?? 0,
              airDate:
                  DateTime.tryParse(epJson['airDate']?.toString() ?? ''),
              imageUrl: epJson['posterUrl']?.toString() ?? '',
              watched: epJson['watched'] ?? false,
              description: epJson['overview'] ?? 'No data',
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
      externalIds: ExternalIds(
        tmdb: data['externalIds']['tmdb']?.toString() ?? '',
        imdb: data['externalIds']['imdb']?.toString() ?? '',
        tvdb: data['externalIds']['tvdb']?.toString() ?? '',
      ),
      title: data['title']?.toString() ?? 'TBD',
      posterUrl: data['posterUrl']?.toString() ?? '',
      description: data['overview']?.toString() ?? 'No data',
      status: data['status']?.toString(),
      releaseDate:
          DateTime.tryParse(data['releaseDate']?.toString() ?? ''),
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

  Future<List<AdminUser>?> fetchAllUsers() async {
    try {
      await _ensureAuth();
      final uri = Uri.parse('${AuthService.instance.apiBaseUrl}/admin/users');
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is List) {
          return body.map((item) => AdminUser.fromJson(item)).toList();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> createAdminUser(
    String username,
    String password,
    String name,
    bool isAdmin,
  ) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse('${AuthService.instance.apiBaseUrl}/admin/users');
      final response = await _client
          .post(
            uri,
            headers: _authHeaders(),
            body: jsonEncode({
              'username': username,
              'password': password,
              'name': name,
              'isAdmin': isAdmin,
            }),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }

  Future<bool> updateAdminUser(
    String id, {
    String? username,
    String? name,
    bool? isAdmin,
  }) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/admin/users/$id',
      );
      final Map<String, dynamic> payload = {};
      if (username != null) payload['username'] = username;
      if (name != null) payload['name'] = name;
      if (isAdmin != null) payload['isAdmin'] = isAdmin;

      final response = await _client
          .put(uri, headers: _authHeaders(), body: jsonEncode(payload))
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }

  Future<bool> deleteAdminUser(String id) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/admin/users/$id',
      );
      final response = await _client
          .delete(uri, headers: _authHeaders())
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }

  Future<bool> resetUserPassword(String id, String newPassword) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/admin/users/$id/reset-password',
      );
      final response = await _client
          .post(
            uri,
            headers: _authHeaders(),
            body: jsonEncode({'newPassword': newPassword}),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }

  Future<bool> selfChangePassword(String newPassword) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/auth/change-password',
      );
      final response = await _client
          .post(
            uri,
            headers: _authHeaders(),
            body: jsonEncode({'newPassword': newPassword}),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }

  Future<bool> syncAllSeries() async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/admin/sync/all',
      );
      final response = await _client
          .post(uri, headers: _authHeaders())
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }

  Future<bool> syncUpcomingSeries() async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/admin/sync/upcoming',
      );
      final response = await _client
          .post(uri, headers: _authHeaders())
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }

  Future<bool> syncSingleSeries(int tmdbId) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/admin/sync/$tmdbId',
      );
      final response = await _client
          .post(uri, headers: _authHeaders())
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {}
    return false;
  }
  
  Future<WatchHistoryResponse?> fetchWatchHistory({
    required DateTime start, 
    required DateTime end
  }) async {
    try {
      await _ensureAuth();
      final uri = Uri.parse(
        '${AuthService.instance.apiBaseUrl}/user/history?start=${start.toUtc().toIso8601String()}&end=${end.toUtc().toIso8601String()}',
      );
      final response = await _client
          .get(uri, headers: _authHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return WatchHistoryResponse.fromJson(json.decode(response.body));
      }
    } catch (_) {}
    return null;
  }
}
