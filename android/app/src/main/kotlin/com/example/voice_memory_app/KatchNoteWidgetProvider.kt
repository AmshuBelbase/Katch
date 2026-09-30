package com.example.voice_memory_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class KatchNoteWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_note).apply {
                val recordIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("katch://action/record")
                )
                setOnClickPendingIntent(R.id.widget_root, recordIntent)
                setOnClickPendingIntent(R.id.btn_record, recordIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
