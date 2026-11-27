package com.example.first_project

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import java.io.File

/**
 * Runs the card reader in its own process (":ocr"). Tesseract is native code
 * and needs a lot of memory; if it crashes or the system stops it, only this
 * process ends and the app shows a "try again" message instead of closing.
 */
class OcrService : Service() {
    private lateinit var thread: HandlerThread
    private lateinit var messenger: Messenger

    override fun onCreate() {
        super.onCreate()
        thread = HandlerThread("id-reader").apply { start() }
        messenger = Messenger(Handler(thread.looper) { msg -> handle(msg); true })
    }

    private fun handle(msg: Message) {
        val reply = msg.replyTo ?: return
        val out = Bundle()
        try {
            val path = msg.data.getString(KEY_PATH) ?: throw IllegalArgumentException("no image")
            val result = IdCardReader.readCard(this, File(path).readBytes())
            @Suppress("UNCHECKED_CAST")
            val lines = result["lines"] as List<Map<String, Any>>
            out.putDouble(KEY_ASPECT, result["aspect"] as Double)
            out.putStringArrayList(KEY_TEXTS, ArrayList(lines.map { it["text"] as String }))
            out.putDoubleArray(KEY_YS, lines.map { it["y"] as Double }.toDoubleArray())
        } catch (t: Throwable) {
            out.putString(KEY_ERROR, t.javaClass.simpleName)
        }
        runCatching { reply.send(Message.obtain().apply { data = out }) }
    }

    override fun onBind(intent: Intent): IBinder = messenger.binder

    override fun onDestroy() {
        thread.quitSafely()
        super.onDestroy()
    }

    companion object {
        const val KEY_PATH = "path"
        const val KEY_ASPECT = "aspect"
        const val KEY_TEXTS = "texts"
        const val KEY_YS = "ys"
        const val KEY_ERROR = "error"
    }
}
