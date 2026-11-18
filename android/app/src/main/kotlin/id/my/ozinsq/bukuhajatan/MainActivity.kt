package id.my.ozinsq.bukuhajatan

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Batch 24: jembatan "pasangApk" untuk pemeriksa
        // pembaruan — membagikan APK unduhan lewat FileProvider
        // lalu membuka pemasang paket Android.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bukuhajatan/pembaruan"
        ).setMethodCallHandler { call, result ->
            if (call.method == "pasangApk") {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("ARG", "path kosong", null)
                } else {
                    try {
                        // Batch 27: canonicalFile — samakan jalur
                        // symlink (/data/user/0 vs /data/data) agar
                        // cocok dengan akar FileProvider.
                        val uri = FileProvider.getUriForFile(
                            this,
                            packageName + ".fileprovider",
                            File(path).canonicalFile
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                uri,
                                "application/vnd.android.package-archive"
                            )
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("GAGAL", e.message, null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
