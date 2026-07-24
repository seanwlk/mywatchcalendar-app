import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_service.dart';
import '../models.dart';

const String _taskName = 'widget_refresh_task';

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri?.host == 'refresh') {
    await _initBackground();
    await _performRefresh();
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _taskName) {
      await _initBackground();
      return _performRefresh();
    }
    return true;
  });
}

Future<void> _initBackground() async {
  // A reused background engine keeps stale SharedPreferences caches;
  // reload so this isolate sees tokens the app wrote after engine start.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  await AuthService.instance.init();
}

Future<void> _write(List<MapEntry<Series, Episode>> items) async {
  final payload = jsonEncode(
    items
        .map(
          (e) => {
            'series_id': e.key.id,
            'series_title': e.key.title,
            'episode_id': e.value.id,
            'episode_title': e.value.title,
            'air_date': e.value.airDate.toIso8601String(),
            'poster_url': e.key.posterUrl,
            'season_number': e.value.season,
            'episode_number': e.value.number,
            'episodes_left': e.value.episodesLeft,
          },
        )
        .toList(),
  );

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('widget_towatch', payload);
  await HomeWidget.saveWidgetData<String>('widget_towatch_data', payload);
  await HomeWidget.updateWidget(name: 'MyWatchWidgetProvider');
}

Future<bool> _performRefresh() async {
  final installedWidgets = await HomeWidget.getInstalledWidgets();
  if (installedWidgets.isEmpty) {
    // skip if widget is not installed
    return true;
  }
  try {
    final items = await ApiClient.instance.fetchUnwatchedEpisodes(
      page: 1,
      pageSize: 30,
    );
    if (items == null) {
      throw Exception('Could not reach the server');
    }
    await _write(items);
    return true;
  } catch (e) {
    final errorJson = jsonEncode([
      {
        'series_id': 'error_id',
        'series_title': '⚠️ SYNC ERROR',
        'episode_id': 'error_ep',
        'episode_title': e.toString(),
        'air_date': DateTime.now().toIso8601String(),
        'poster_url': '',
        'season_number': 0,
        'episode_number': 0,
        'episodes_left': 0,
      },
    ]);

    await HomeWidget.saveWidgetData<String>('widget_towatch_data', errorJson);
    await HomeWidget.updateWidget(name: 'MyWatchWidgetProvider');
    // false → WorkManager retries this run with backoff
    return false;
  }
}

class WidgetUpdater {
  static Future<void> initialize({required int intervalMinutes}) async {
    if (kIsWeb || !Platform.isAndroid) return;

    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);

    Workmanager().initialize(callbackDispatcher);

    var mins = intervalMinutes;
    if (mins < 15) mins = 15;
    if (mins > 60 * 24) mins = 60 * 24;
    Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: Duration(minutes: mins),
      constraints: Constraints(networkType: NetworkType.connected),
      // `update` applies new frequency/constraints to the already-scheduled
      // task (`keep` would ignore them) while preserving its timing.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// Publish already-fetched data — avoids a duplicate network round trip.
  static Future<void> publish(List<MapEntry<Series, Episode>> items) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final installedWidgets = await HomeWidget.getInstalledWidgets();
      if (installedWidgets.isEmpty) return;
      await _write(items);
    } catch (_) {}
  }
}
