package com.example.voice_memory_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class KatchWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.katch_widget_layout).apply {
                // Record Button Intent
                val recordIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, android.net.Uri.parse("katch://action/record"))
                setOnClickPendingIntent(R.id.btn_record, recordIntent)

                val reminderIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, android.net.Uri.parse("katch://action/reminders"))
                setOnClickPendingIntent(R.id.tv_reminder, reminderIntent)

                val txIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, android.net.Uri.parse("katch://action/finance"))
                setOnClickPendingIntent(R.id.tv_transaction, txIntent)

                // Reminder text
                val reminderText = widgetData.getString("latest_reminder", "No upcoming reminders")
                setTextViewText(R.id.tv_reminder, reminderText)

                // Transaction text
                val transactionText = widgetData.getString("latest_transaction", "No recent transactions")
                setTextViewText(R.id.tv_transaction, transactionText)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
