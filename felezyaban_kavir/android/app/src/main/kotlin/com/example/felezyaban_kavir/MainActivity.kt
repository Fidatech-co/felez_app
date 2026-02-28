package mis.felezyaban.com

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import org.opencv.android.OpenCVLoader

class MainActivity : FlutterActivity() {
    private val channelName = "screen_processor"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!OpenCVLoader.initDebug()) {
            Log.e("OpenCV", "Unable to initialize OpenCV library.")
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "processImage" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("INVALID_ARGUMENT", "Image path is required.", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                val output = ScreenImageProcessor.process(path, cacheDir)
                                mainHandler.post { result.success(output) }
                            } catch (error: Exception) {
                                mainHandler.post {
                                    result.error("PROCESSING_ERROR", error.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.shutdown()
    }
}
