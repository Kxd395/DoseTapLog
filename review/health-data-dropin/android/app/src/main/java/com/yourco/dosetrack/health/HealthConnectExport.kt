package com.yourco.dosetrack.health

import android.content.Context
import android.os.Environment
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.temporal.ChronoUnit

class HealthConnectExport(private val context: Context) {
    suspend fun exportLastNDays(days: Int = 14): File {
        val client = HealthConnectClient.getOrCreate(context)
        val end = Instant.now()
        val start = end.minus(days.toLong(), ChronoUnit.DAYS)

        val lines = mutableListOf<String>()
        fun append(obj: JSONObject) { lines.add(obj.toString()) }

        val sleep = client.readRecords(
            ReadRecordsRequest(
                SleepSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )
        ).records

        sleep.forEach {
            append(JSONObject(mapOf(
                "source" to "healthconnect",
                "record_type" to "sleep",
                "start_utc" to it.startTime.toString(),
                "end_utc" to it.endTime.toString(),
                "value" to JSONObject.NULL,
                "metadata" to JSONObject()
            )))
        }

        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "DoseTrack/exports")
        dir.mkdirs()
        val file = File(dir, "healthconnect_export_${Instant.now().epochSecond}.json")
        file.writeText(lines.joinToString("\n"))
        return file
    }
}
