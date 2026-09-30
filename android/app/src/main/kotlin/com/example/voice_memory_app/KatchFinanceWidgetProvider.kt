package com.example.voice_memory_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class KatchFinanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_finance).apply {
                val latestTx = widgetData.getString("personal_finance_summary", "No recent transactions")
                setTextViewText(R.id.tv_transaction, latestTx)

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
