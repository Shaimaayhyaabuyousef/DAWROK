package com.example.first_project

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "dawrok/id_reader", StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()).setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(readInReaderProcess(call.arguments as ByteArray))
            } catch (t: Throwable) {
                result.error("read_failed", "Could not read the card image.", t.javaClass.simpleName)
            }
        }
    }

    /**
     * Sends the image to [OcrService], which runs in a separate process, and
     * waits for its answer. A crash there ends only that process.
     */
    private fun readInReaderProcess(bytes: ByteArray): Map<String, Any> {
        require(bytes.size in 1..5 * 1024 * 1024)
        val image = File(cacheDir, "id-card-${System.nanoTime()}.jpg")
        image.writeBytes(bytes)
        val done = CountDownLatch(1)
        var answer: Bundle? = null
        val replies = HandlerThread("id-reader-reply").apply { start() }
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                try {
                    binder.linkToDeath({ done.countDown() }, 0)
                    Messenger(binder).send(Message.obtain().apply {
                        data = Bundle().apply { putString(OcrService.KEY_PATH, image.absolutePath) }
                        replyTo = Messenger(Handler(replies.looper) { msg ->
                            answer = msg.data
                            done.countDown()
                            true
                        })
                    })
                } catch (_: Exception) {
                    done.countDown()
                }
            }
            override fun onServiceDisconnected(name: ComponentName) = done.countDown()
            override fun onBindingDied(name: ComponentName) = done.countDown()
            override fun onNullBinding(name: ComponentName) = done.countDown()
        }
        try {
            check(bindService(Intent(this, OcrService::class.java), connection, Context.BIND_AUTO_CREATE))
            done.await(90, TimeUnit.SECONDS)
        } finally {
            runCatching { unbindService(connection) }
            replies.quitSafely()
            image.delete()
        }
        val data = answer ?: throw IllegalStateException("reader stopped")
        data.getString(OcrService.KEY_ERROR)?.let { throw IllegalStateException(it) }
        val texts = data.getStringArrayList(OcrService.KEY_TEXTS) ?: arrayListOf()
        val ys = data.getDoubleArray(OcrService.KEY_YS) ?: DoubleArray(0)
        return mapOf(
            "aspect" to data.getDouble(OcrService.KEY_ASPECT),
            "lines" to texts.indices.map { mapOf("text" to texts[it], "y" to ys[it]) },
        )
    }
}
