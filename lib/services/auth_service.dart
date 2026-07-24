import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Required for TextInput autofill signals
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keySiteUrl = 'site_url';
  static const _keyUsername = 'username';
  static const _keyAccessToken = 'accessToken';
  static const _keyRefreshToken = 'refreshToken';

  static final AuthService instance = AuthService._internal();

  SharedPreferences? _prefs;
  final http.Client _client;
  String? siteUrl;
  String? username;
  String? accessToken;
  String? refreshToken;

  final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(true);

  static const Duration _timeout = Duration(seconds: 8);
  Future<bool>? _refreshInFlight;

  AuthService._internal() : _client = http.Client();

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    siteUrl = _prefs?.getString(_keySiteUrl);
    username = _prefs?.getString(_keyUsername);
    accessToken = _prefs?.getString(_keyAccessToken);
    refreshToken = _prefs?.getString(_keyRefreshToken);

    authStateNotifier.value = isSignedIn;
  }

  bool get hasSavedSite => siteUrl != null && siteUrl!.isNotEmpty;
  bool get hasValidAccessToken =>
      accessToken != null && !_isTokenExpired(accessToken);
  bool get hasValidRefreshToken =>
      refreshToken != null && !_isTokenExpired(refreshToken);
  bool get isSignedIn =>
      hasSavedSite && accessToken != null && refreshToken != null;

  String get apiBaseUrl {
    final normalized = siteUrl?.trim().replaceAll(RegExp(r'/+ *$'), '');
    if (normalized == null || normalized.isEmpty) return '';
    return '$normalized/api';
  }

  String get bearerToken => 'Bearer $accessToken';

  Future<bool> login(String siteUrl, String username, String password) async {
    final normalizedUrl = _normalizeSiteUrl(siteUrl);
    this.siteUrl = normalizedUrl;
    this.username = username;

    final success = await _remoteLogin(username, password);
    if (!success) return false;

    await _saveCredentials();

    SystemChannels.textInput.invokeMethod('TextInput.finishAutofillContext');

    authStateNotifier.value = true;
    return true;
  }

  Future<bool> refreshTokens() async {
    if (refreshToken == null || !hasValidRefreshToken) {
      return false;
    }
    return await _remoteRefresh();
  }

  Future<bool> ensureAccessToken() async {
    if (accessToken != null && !_isTokenExpired(accessToken)) {
      return true;
    }

    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final future = _refreshAndPersist();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  Future<bool> _refreshAndPersist() async {
    final refreshed = await refreshTokens();
    if (!refreshed) {
      await logout(clearSiteUrl: false);
      return false;
    }
    await _saveCredentials();
    return true;
  }

  Future<void> logout({bool clearSiteUrl = false}) async {
    accessToken = null;
    refreshToken = null;
    if (clearSiteUrl) {
      username = null;
      siteUrl = null;
    }
    await _saveCredentials();
    authStateNotifier.value = false;
  }

  Future<bool> updateSiteUrl(String siteUrl) async {
    final normalized = _normalizeSiteUrl(siteUrl);
    if (normalized.isEmpty || normalized == this.siteUrl) {
      return false;
    }
    this.siteUrl = normalized;
    accessToken = null;
    refreshToken = null;
    await _saveCredentials();
    authStateNotifier.value = false;
    return true;
  }

  Future<void> _saveCredentials() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keySiteUrl, siteUrl ?? '');
    await _prefs?.setString(_keyUsername, username ?? '');
    await _prefs?.setString(_keyAccessToken, accessToken ?? '');
    await _prefs?.setString(_keyRefreshToken, refreshToken ?? '');
  }

  String _normalizeSiteUrl(String url) {
    var result = url.trim();
    if (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  bool _isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    final payload = _decodeJwtPayload(token);
    if (payload == null || !payload.containsKey('exp')) return true;
    final exp = payload['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
      ).isBefore(DateTime.now());
    }
    if (exp is String) {
      final value = int.tryParse(exp);
      return value == null ||
          DateTime.fromMillisecondsSinceEpoch(
            value * 1000,
          ).isBefore(DateTime.now());
    }
    return true;
  }

  Map<String, dynamic>? _decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    final payload = parts[1];
    try {
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonPayload = json.decode(decoded);
      if (jsonPayload is Map<String, dynamic>) {
        return jsonPayload;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> _remoteLogin(String username, String password) async {
    if (siteUrl == null) return false;
    try {
      final uri = Uri.parse('$siteUrl/api/auth/login');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(_timeout);
      if (response.statusCode != 201) return false;
      final body = json.decode(response.body);
      if (body is Map<String, dynamic> &&
          body['accessToken'] != null &&
          body['refreshToken'] != null) {
        accessToken = body['accessToken'];
        refreshToken = body['refreshToken'];
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _remoteRefresh() async {
    if (siteUrl == null || refreshToken == null) return false;
    try {
      final uri = Uri.parse('$siteUrl/api/auth/refresh');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);
      if (response.statusCode != 201) return false;
      final body = json.decode(response.body);
      if (body is Map<String, dynamic> &&
          body['accessToken'] != null &&
          body['refreshToken'] != null) {
        accessToken = body['accessToken'];
        refreshToken = body['refreshToken'];
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
