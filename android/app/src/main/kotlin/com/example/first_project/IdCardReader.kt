package com.example.first_project

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.Rect
import android.media.ExifInterface
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.File

/** Reads the printed lines of an ID card image on the device (Tesseract). */
object IdCardReader {
    fun readCard(context: Context, bytes: ByteArray): Map<String, Any> {
        require(bytes.size in 1..5 * 1024 * 1024)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0)
        val options = BitmapFactory.Options()
        while (maxOf(bounds.outWidth, bounds.outHeight) / options.inSampleSize.coerceAtLeast(1) > 2000) {
            options.inSampleSize = options.inSampleSize.coerceAtLeast(1) * 2
        }
        val decoded = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options))
        val rotation = runCatching {
            ExifInterface(bytes.inputStream()).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
        }.getOrDefault(1)
        val degrees = when (rotation) { 3 -> 180f; 6 -> 90f; 8 -> 270f; else -> 0f }
        val image = if (degrees == 0f) decoded else Bitmap.createBitmap(decoded, 0, 0,
            decoded.width, decoded.height, Matrix().apply { postRotate(degrees) }, true)
        if (image !== decoded) decoded.recycle()
        val api = TessBaseAPI()
        try {
            // Cache language models only. The document bitmap stays in memory.
            val root = File(context.noBackupFilesDir, "id-ocr-v2")
            val data = File(root, "tessdata").apply { mkdirs() }
            for (language in listOf("ara", "heb", "eng")) {
                val file = File(data, "$language.traineddata")
                if (!file.exists()) {
                    val temp = File(data, "$language.tmp")
                    context.assets.open("ocr/${file.name}").use { input ->
                        temp.outputStream().use { output -> input.copyTo(output) }
                    }
                    check(temp.renameTo(file))
                }
            }
            check(api.init(root.absolutePath + "/", "ara+heb+eng"))
            api.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SPARSE_TEXT)
            api.setImage(image)
            api.getUTF8Text()
            val lines = mutableListOf<Map<String, Any>>()
            val level = TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
            val iterator = api.resultIterator
            if (iterator != null) {
                try {
                    iterator.begin()
                    do {
                        val text = iterator.getUTF8Text(level)?.trim().orEmpty()
                        if (text.isNotEmpty() && iterator.confidence(level) >= 45f) {
                            val rect = iterator.getBoundingRect(level)
                            lines.add(mapOf("text" to text, "y" to rect.exactCenterY() / image.height.toDouble()))
                        }
                    } while (iterator.next(level))
                } finally { iterator.delete() }
            }
            // Sparse segmentation can drop short Arabic headings. Read tightly
            // bounded printed rows independently, excluding the portrait margin.
            api.setPageSegMode(TessBaseAPI.PageSegMode.PSM_RAW_LINE)
            for (rect in printedRows(image)) {
                api.setRectangle(rect.left, rect.top, rect.width(), rect.height())
                val text = api.getUTF8Text()?.trim().orEmpty()
                if (text.isNotEmpty() && api.meanConfidence() >= 45) {
                    lines.add(mapOf("text" to text, "y" to rect.exactCenterY() / image.height.toDouble()))
                }
            }
            // Digits-only pass for the nine-digit ID number: the Latin model
            // restricted to 0-9 reads printed numerals more reliably than the
            // mixed Arabic/Hebrew pass.
            val digits = TessBaseAPI()
            try {
                if (digits.init(root.absolutePath + "/", "eng")) {
                    digits.setVariable(TessBaseAPI.VAR_CHAR_WHITELIST, "0123456789 ")
                    digits.setPageSegMode(TessBaseAPI.PageSegMode.PSM_RAW_LINE)
                    digits.setImage(image)
                    for (rect in printedRows(image)) {
                        digits.setRectangle(rect.left, rect.top, rect.width(), rect.height())
                        val text = digits.getUTF8Text()?.trim().orEmpty()
                        if (text.count { it.isDigit() } >= 9 && digits.meanConfidence() >= 60) {
                            lines.add(mapOf("text" to text, "y" to rect.exactCenterY() / image.height.toDouble()))
                        }
                    }
                }
            } finally { digits.recycle() }
            return mapOf("aspect" to image.width.toDouble() / image.height, "lines" to lines)
        } finally {
            api.recycle()
            image.recycle()
        }
    }

    private fun printedRows(image: Bitmap): List<Rect> {
        val width = image.width
        val height = image.height
        val start = width / 4
        val pixels = IntArray(width)
        val rows = mutableListOf<Rect>()
        var current: Rect? = null
        val margin = maxOf(3, height / 100)
        fun finish() {
            val r = current ?: return
            current = null
            if (r.height() !in maxOf(6, height / 100)..height / 8 || r.width() < width / 16) return
            r.inset(-margin, -margin)
            r.intersect(0, 0, width, height)
            rows.add(r)
        }
        for (y in 0 until height) {
            image.getPixels(pixels, 0, width, 0, y, width, 1)
            var left = width
            var right = 0
            var count = 0
            for (x in start until width step 2) {
                val pixel = pixels[x]
                val luma = ((pixel ushr 16 and 255) + 2 * (pixel ushr 8 and 255) + (pixel and 255)) / 4
                if (luma < 110) {
                    left = minOf(left, x)
                    right = x + 1
                    count++
                }
            }
            if (count >= maxOf(3, width / 250) && count < (width - start) / 3) {
                val bounds = current
                if (bounds == null) current = Rect(left, y, right, y + 1)
                else bounds.union(left, y, right, y + 1)
            } else if (current?.let { y - it.bottom > maxOf(2, height / 150) } == true) {
                finish()
            }
            if (rows.size >= 24) break
        }
        finish()
        return rows
    }
}
