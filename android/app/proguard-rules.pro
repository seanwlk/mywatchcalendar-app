# The home-screen widget classes are resolved by class name
# (home_widget's updateWidget(name: 'MyWatchWidgetProvider')) and instantiated
# reflectively by the Android framework, so R8 must not rename or strip them.
-keep class com.sw.mywatchcalendar.MyWatchWidgetProvider { *; }
-keep class com.sw.mywatchcalendar.MyWatchWidgetService { *; }
-keep class com.sw.mywatchcalendar.MyWatchWidgetFactory { *; }

# home_widget relies on reflection for provider lookup and shared data.
-keep class es.antonborri.home_widget.** { *; }
