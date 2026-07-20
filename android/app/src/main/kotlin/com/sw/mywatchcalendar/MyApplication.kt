package com.sw.mywatchcalendar

import io.flutter.app.FlutterApplication

class MyApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // Keep minimal to avoid referencing native plugin classes here.
        // Dart side initializes Workmanager and HomeWidget as needed.
    }
}
