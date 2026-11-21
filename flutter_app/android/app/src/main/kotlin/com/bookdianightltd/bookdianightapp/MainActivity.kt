package com.bookdianightltd.bookdianightapp

import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bookdianight/network",
        ).setMethodCallHandler { call, result ->
            if (call.method == "openWirelessSettings") {
                startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bookdianight/files",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val name = call.argument<String>("name") ?: "ticket.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid", "Missing file bytes", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(saveToDownloads(name, bytes))
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }
                "enqueueDownload" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val name = call.argument<String>("name") ?: "ticket.pdf"
                    val authorization = call.argument<String>("authorization")?.trim().orEmpty()
                    if (url.isEmpty()) {
                        result.error("invalid", "Missing download url", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(enqueueDownload(url, name, authorization))
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }
                "buildTicketPdf" -> {
                    val pages = (call.arguments as? Map<*, *>)?.get("pages") as? List<*>
                    val encoded = pages
                        ?.mapNotNull { item -> item as? ByteArray }
                        ?.filter { it.isNotEmpty() }
                        .orEmpty()
                    if (encoded.isEmpty()) {
                        result.error("invalid", "Missing ticket pages", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(buildTicketPdf(encoded))
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }
                "downloadStatus" -> {
                    val id = call.argument<Number>("id")?.toLong()
                    if (id == null) {
                        result.error("invalid", "Missing download id", null)
                        return@setMethodCallHandler
                    }
                    result.success(downloadStatus(id))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildTicketPdf(pages: List<ByteArray>): ByteArray {
        val document = PdfDocument()
        try {
            pages.forEachIndexed { index, encoded ->
                val bitmap = BitmapFactory.decodeByteArray(encoded, 0, encoded.size)
                    ?: throw IllegalStateException("Could not read the ticket page")
                try {
                    val pageInfo = PdfDocument.PageInfo.Builder(
                        bitmap.width,
                        bitmap.height,
                        index + 1,
                    ).create()
                    val page = document.startPage(pageInfo)
                    page.canvas.drawColor(Color.BLACK)
                    page.canvas.drawBitmap(bitmap, 0f, 0f, null)
                    document.finishPage(page)
                } finally {
                    bitmap.recycle()
                }
            }
            val output = ByteArrayOutputStream()
            document.writeTo(output)
            return output.toByteArray()
        } finally {
            document.close()
        }
    }

    private fun enqueueDownload(url: String, name: String, authorization: String): Long {
        val fileName = if (name.endsWith(".pdf")) name else "$name.pdf"
        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setTitle(fileName)
            setDescription("BookDiaNight ticket")
            setMimeType("application/pdf")
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
            if (authorization.isNotEmpty()) {
                addRequestHeader("Authorization", authorization)
            }
        }
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return manager.enqueue(request)
    }

    private fun downloadStatus(id: Long): String {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(id)
        manager.query(query)?.use { cursor ->
            if (!cursor.moveToFirst()) return "missing"
            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            return when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> "success"
                DownloadManager.STATUS_FAILED -> {
                    val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                    "failed:$reason"
                }
                else -> "running"
            }
        }
        return "missing"
    }

    private fun saveToDownloads(name: String, bytes: ByteArray): String {
        val fileName = if (name.endsWith(".pdf")) name else "$name.pdf"
        val resolver = applicationContext.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Could not create the download")
            try {
                resolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                } ?: throw IllegalStateException("Could not write the download")
                val published = ContentValues().apply {
                    put(MediaStore.Downloads.IS_PENDING, 0)
                    put(MediaStore.Downloads.SIZE, bytes.size.toLong())
                }
                if (resolver.update(uri, published, null, null) <= 0) {
                    throw IllegalStateException("Could not publish the download")
                }
                val stored = resolver.openInputStream(uri)?.use { input ->
                    input.readBytes().size
                } ?: 0
                if (stored != bytes.size) {
                    throw IllegalStateException("Downloaded file is empty")
                }
                confirmPublished(uri)
                registerVisibleDownload(uri, fileName, bytes.size.toLong())
                showDownloadNotification(uri, fileName)
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
            return uri.toString()
        }

        val directory = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        if (!directory.exists()) {
            directory.mkdirs()
        }
        val file = File(directory, fileName)
        file.writeBytes(bytes)
        if (!file.exists() || file.length() != bytes.size.toLong()) {
            throw IllegalStateException("Downloaded file is empty")
        }
        registerVisibleDownload(Uri.fromFile(file), fileName, file.length())
        return file.absolutePath
    }

    private fun confirmPublished(uri: Uri) {
        val resolver = applicationContext.contentResolver
        val stillPending = resolver.query(
            uri,
            arrayOf(MediaStore.Downloads.IS_PENDING),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use true
            val pendingIndex = cursor.getColumnIndex(MediaStore.Downloads.IS_PENDING)
            pendingIndex >= 0 && cursor.getInt(pendingIndex) == 1
        } ?: false
        if (stillPending) {
            throw IllegalStateException("Download was not published")
        }
    }

    private fun registerVisibleDownload(uri: Uri, fileName: String, size: Long) {
        val path = downloadPath(uri, fileName) ?: return
        val file = File(path)
        if (!file.exists() || file.length() <= 0L) return
        try {
            val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            @Suppress("DEPRECATION")
            manager.addCompletedDownload(
                fileName,
                "BookDiaNight ticket",
                true,
                "application/pdf",
                file.absolutePath,
                size,
                true,
            )
        } catch (_: Exception) {
        }
    }

    private fun downloadPath(uri: Uri, fileName: String): String? {
        applicationContext.contentResolver.query(
            uri,
            arrayOf(MediaStore.MediaColumns.DATA),
            null,
            null,
            null,
        )?.use { cursor ->
            val index = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            if (cursor.moveToFirst() && index >= 0) {
                val path = cursor.getString(index)
                if (!path.isNullOrBlank()) return path
            }
        }
        val fallback = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            fileName,
        )
        return if (fallback.exists()) fallback.absolutePath else null
    }

    private fun showDownloadNotification(uri: Uri, fileName: String) {
        val channelId = "high_importance_channel"
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "High Importance Notifications",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val open = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pending = PendingIntent.getActivity(
            this,
            fileName.hashCode(),
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Ticket downloaded")
            .setContentText(fileName)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$fileName\nSaved in Downloads"))
            .setAutoCancel(true)
            .setContentIntent(pending)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        manager.notify(fileName.hashCode(), notification)
    }
}
