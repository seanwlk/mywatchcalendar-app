import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeChoice { amoledBlue, amoledRed, whiteBlue, whiteRed, materialYou }

class SettingsService {
  static const _keyThemeChoice = 'theme_choice';
  static const _keySiteUrlOverride = 'site_url_override';
  static const _keyWidgetEnabled = 'widget_enabled';
  static const _keyWidgetInterval = 'widget_interval_minutes';
  static const _keyFollowedGridView = 'followed_is_grid_view';
  static const _keyGraphPeriod = 'graph_period';
  static const _keyGraphMetric = 'graph_metric';
  static const _keyGraphReverse = 'graph_reverse';

  static final SettingsService instance = SettingsService._internal();

  SharedPreferences? _prefs;
  final ValueNotifier<AppThemeChoice> themeChoice =
      ValueNotifier<AppThemeChoice>(AppThemeChoice.amoledBlue);
  String? siteUrlOverride;
  bool widgetEnabled = false;
  int widgetIntervalMinutes = 60; // default 1 hour
  bool followedIsGridView = true;
  String graphPeriod = 'day';
  String graphMetric = 'episodes';
  bool graphReverse = true;

  SettingsService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_keyThemeChoice);
    themeChoice.value = AppThemeChoice.values.firstWhere(
      (choice) => choice.name == raw,
      orElse: () => AppThemeChoice.amoledBlue,
    );
    siteUrlOverride = _prefs?.getString(_keySiteUrlOverride);
    widgetEnabled = _prefs?.getBool(_keyWidgetEnabled) ?? false;
    widgetIntervalMinutes = _prefs?.getInt(_keyWidgetInterval) ?? 60;
    followedIsGridView = _prefs?.getBool(_keyFollowedGridView) ?? true;
    graphPeriod = _prefs?.getString(_keyGraphPeriod) ?? 'day';
    graphMetric = _prefs?.getString(_keyGraphMetric) ?? 'episodes';
    graphReverse = _prefs?.getBool(_keyGraphReverse) ?? true;
  }

  Future<bool> updateTheme(AppThemeChoice choice) async {
    themeChoice.value = choice;
    return _prefs?.setString(_keyThemeChoice, choice.name) ??
        Future.value(false);
  }

  Future<bool> updateWidgetEnabled(bool enabled) async {
    widgetEnabled = enabled;
    return _prefs?.setBool(_keyWidgetEnabled, enabled) ?? Future.value(false);
  }

  Future<bool> updateWidgetInterval(int minutes) async {
    widgetIntervalMinutes = minutes;
    return _prefs?.setInt(_keyWidgetInterval, minutes) ?? Future.value(false);
  }

  Future<bool> updateSiteUrl(String siteUrl) async {
    siteUrlOverride = siteUrl.isEmpty ? null : siteUrl;
    if (siteUrlOverride == null) {
      return _prefs?.remove(_keySiteUrlOverride) ?? Future.value(false);
    }
    return _prefs?.setString(_keySiteUrlOverride, siteUrlOverride!) ??
        Future.value(false);
  }

  Future<bool> updateFollowedGridView(bool isGrid) async {
    followedIsGridView = isGrid;
    return _prefs?.setBool(_keyFollowedGridView, isGrid) ?? Future.value(false);
  }

  Future<bool> updateGraphPeriod(String period) async {
    graphPeriod = period;
    return _prefs?.setString(_keyGraphPeriod, period) ?? Future.value(false);
  }

  Future<bool> updateGraphMetric(String metric) async {
    graphMetric = metric;
    return _prefs?.setString(_keyGraphMetric, metric) ?? Future.value(false);
  }

  Future<bool> updateGraphReverse(bool reverse) async {
    graphReverse = reverse;
    return _prefs?.setBool(_keyGraphReverse, reverse) ?? Future.value(false);
  }
}