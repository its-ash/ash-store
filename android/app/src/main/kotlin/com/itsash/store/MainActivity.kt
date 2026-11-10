package com.itsash.store

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bridge for the parts of a store that need the Android package manager:
 * installed versions, the "install unknown apps" permission, APK installs,
 * launching and uninstalling apps.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.itsash.store/packages")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installedVersion" -> result.success(installedVersion(call.argument<String>("package")!!))
                        "canInstall" -> result.success(canInstall())
                        "openInstallSettings" -> {
                            openInstallSettings()
                            result.success(null)
                        }
                        "install" -> result.success(install(call.argument<String>("path")!!))
                        "launch" -> result.success(launch(call.argument<String>("package")!!))
                        "uninstall" -> result.success(uninstall(call.argument<String>("package")!!))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("package_error", e.message, null)
                }
            }
    }

    private fun installedVersion(pkg: String): Map<String, Any>? = try {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(pkg, 0)
        }
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        mapOf("versionName" to (info.versionName ?: ""), "versionCode" to code)
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun openInstallSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        startActivity(intent)
    }

    private fun install(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return true
    }

    private fun launch(pkg: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        startActivity(intent)
        return true
    }

    private fun uninstall(pkg: String): Boolean {
        val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg"))
        startActivity(intent)
        return true
    }
}
