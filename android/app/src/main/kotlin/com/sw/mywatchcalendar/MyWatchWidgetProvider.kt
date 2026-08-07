package com.sw.mywatchcalendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.net.URL

class MyWatchWidgetProvider : HomeWidgetProvider() {
    
    override fun onUpdate(
        context: Context, 
        appWidgetManager: AppWidgetManager, 
        appWidgetIds: IntArray, 
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            val intent = Intent(context, MyWatchWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            
            views.setRemoteAdapter(R.id.widget_list_view, intent)

            val clickIntent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
            }
            
            val clickPendingIntent = PendingIntent.getActivity(
                context,
                0,
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list_view, clickPendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
        }
    }
}

class MyWatchWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MyWatchWidgetFactory(this.applicationContext)
    }
}

class MyWatchWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var episodes = JSONArray()

    override fun onDataSetChanged() {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val jsonString = widgetData.getString("widget_towatch_data", "[]")
            
            if (jsonString != null && jsonString.isNotEmpty() && jsonString != "[]") {
                episodes = JSONArray(jsonString)
            }
        } catch (e: Exception) {
            episodes = JSONArray()
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_list_item)
        
        try {
            val episode = episodes.getJSONObject(position)
            
            val seriesId = episode.getString("series_id")
            val episodeId = episode.getString("episode_id")
            
            views.setTextViewText(R.id.item_series_title, episode.getString("series_title"))
            
            val season = episode.getInt("season_number").toString().padStart(2, '0')
            val epNum = episode.getInt("episode_number").toString().padStart(2, '0')
            val epLeft = episode.getInt("episodes_left")

            val seasonEpText = if (epLeft > 0) {
                "S$season ~ E$epNum  +$epLeft"
            } else {
                "S$season ~ E$epNum"
            }

            views.setTextViewText(R.id.item_season_episode, seasonEpText)

            val urlString = episode.getString("poster_url")
            if (urlString.isNotEmpty()) {
                val url = URL(urlString)
                val bmp = BitmapFactory.decodeStream(url.openConnection().getInputStream())
                views.setImageViewBitmap(R.id.item_poster, bmp)
            }
            
            val fillInIntent = Intent().apply {
                data = Uri.parse("mywatch://episode?seriesId=$seriesId&episodeId=$episodeId")
            }
            views.setOnClickFillInIntent(R.id.item_root, fillInIntent)
            
        } catch (e: Exception) {
        }

        return views
    }

    override fun onCreate() {}
    override fun onDestroy() {}
    override fun getCount(): Int = episodes.length()
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}