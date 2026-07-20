import 'dart:convert';
import 'dart:io' show Platform;
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_service.dart';

const String _taskName = 'widget_refresh_task';

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri?.host == 'refresh') {
    await AuthService.instance.init();
    await _performRefresh();
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _taskName) {
      await AuthService.instance.init();
      await _performRefresh();
    }
    return Future.value(true);
  });
}

Future<void> _performRefresh() async {
  final installedWidgets = await HomeWidget.getInstalledWidgets();
  if (installedWidgets.isEmpty) {
    // skip if widget is not installed
    return;
  }
  try {
    final prefs = await SharedPreferences.getInstance();

    final toWatch = await ApiClient.instance.fetchUnwatchedEpisodes(
      page: 1,
      pageSize: 30,
    );

    final toWatchJson = jsonEncode(
      toWatch
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

    await prefs.setString('widget_towatch', toWatchJson);
    await HomeWidget.saveWidgetData<String>('widget_towatch_data', toWatchJson);
    await HomeWidget.updateWidget(name: 'MyWatchWidgetProvider');
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
      },
    ]);

    await HomeWidget.saveWidgetData<String>('widget_towatch_data', errorJson);
    await HomeWidget.updateWidget(name: 'MyWatchWidgetProvider');
  }
}

class WidgetUpdater {
  static Future<void> initialize({required int intervalMinutes}) async {
    if (!Platform.isAndroid) return;

    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);

    Workmanager().initialize(callbackDispatcher);

    var mins = intervalMinutes;
    if (mins < 15) mins = 15;
    if (mins > 60 * 24) mins = 60 * 24;
    Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: Duration(minutes: mins),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> triggerNow() async {
    if (!Platform.isAndroid) return;
    await _performRefresh();
  }
}
