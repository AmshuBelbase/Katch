package com.example.voice_memory_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class KatchSplitwiseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_splitwise).apply {
                val summary = widgetData.getString("splitwise_summary", "No pending splitwise balances")
                setTextViewText(R.id.tv_splitwise, summary)

                val txIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("katch://action/finance")
                )
                setOnClickPendingIntent(R.id.widget_root, txIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
