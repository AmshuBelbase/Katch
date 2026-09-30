package com.example.voice_memory_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class KatchReminderWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_reminder).apply {
                val nextReminder = widgetData.getString("upcoming_reminders", "No upcoming reminders")
                setTextViewText(R.id.tv_reminder, nextReminder)
                
                val reminderIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("katch://action/reminders")
                )
                setOnClickPendingIntent(R.id.widget_root, reminderIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
