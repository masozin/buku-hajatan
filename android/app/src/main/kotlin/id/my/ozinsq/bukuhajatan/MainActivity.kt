package id.my.ozinsq.bukuhajatan

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Batch 38: FlutterFragmentActivity (bukan FlutterActivity)
// adalah syarat plugin local_auth untuk dialog sidik jari.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Batch 24: jembatan "pasangApk" untuk pemeriksa
        // pembaruan — membagikan APK unduhan lewat FileProvider
        // lalu membuka pemasang paket Android.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bukuhajatan/pembaruan"
        ).setMethodCallHandler { call, result ->
            if (call.method == "pathApkPembaruan") {
                // Batch 29: lokasi unduh APK = cacheDir aplikasi,
                // yang dicakup akar cache-path FileProvider.
                // Directory.systemTemp di Dart menunjuk folder
                // code_cache — TIDAK ada akar FileProvider untuk
                // folder itu, jadi Pasang selalu gagal "Failed to
                // find configured root" (terbukti di HP Mark,
                // 2026-11-18).
                result.success(
                    File(cacheDir, "pembaruan-buku-hajatan.apk").absolutePath
                )
            } else if (call.method == "pasangApk") {
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
