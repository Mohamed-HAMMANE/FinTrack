package com.med.fin_track

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.util.Log
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.DecimalFormat

class MyAppWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {

        val decimalFormat = DecimalFormat("0.00")
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.app_widget_layout).apply {
                // Retrieve values from SharedPreferences
                val allTimeExpenses = widgetData.getString("value1", "0")?.toDoubleOrNull() ?: 0.0
                val currentMonthExpenses = widgetData.getString("value2", "0")?.toDoubleOrNull() ?: 0.0

                // Format values as N2
                val formattedAllTime = decimalFormat.format(allTimeExpenses)
                val formattedCurrentMonth = decimalFormat.format(currentMonthExpenses)

                // Set text
                setTextViewText(R.id.value1_text, formattedAllTime)
                setTextViewText(R.id.value2_text, formattedCurrentMonth)

                // Apply conditional colors
                val allTimeColor = when {
                    allTimeExpenses < 0 -> android.graphics.Color.RED // Negative: Red
                    allTimeExpenses > 0 -> android.graphics.Color.GREEN // Positive: Green
                    else -> android.graphics.Color.WHITE // Neutral: Default color
                }
                val currentMonthColor = when {
                    currentMonthExpenses < 0 -> android.graphics.Color.RED
                    currentMonthExpenses > 0 -> android.graphics.Color.GREEN
                    else -> android.graphics.Color.WHITE
                }

                setTextColor(R.id.value1_text, allTimeColor)
                setTextColor(R.id.value2_text, currentMonthColor)

                val intent = Intent(context, MainActivity::class.java) // Replace with your main activity
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
