package com.itsash.store

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bridge for the parts of a store that need the Android package manager:
 * installed versions, the "install unknown apps" permission, PackageInstaller
 * installs, launching and uninstalling apps.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val ACTION_INSTALL_RESULT = "com.itsash.store.INSTALL_RESULT"
        const val EXTRA_PACKAGE = "com.itsash.store.PACKAGE"

        /** Set while the Flutter engine is alive; install results are forwarded to Dart. */
        @Volatile
        var channel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.itsash.store/packages")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "installedVersion" -> result.success(installedVersion(call.argument<String>("package")!!))
                    "canInstall" -> result.success(canInstall())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "install" -> result.success(
                        install(call.argument<String>("path")!!, call.argument<String>("package")!!),
                    )
                    "launch" -> result.success(launch(call.argument<String>("package")!!))
                    "uninstall" -> result.success(uninstall(call.argument<String>("package")!!))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("package_error", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
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

    /**
     * Streams the APK into a PackageInstaller session and commits it. The outcome
     * arrives in [InstallResultReceiver] and is forwarded to Dart as `installResult`.
     * Returns false when the file is missing.
     */
    private fun install(path: String, pkg: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(pkg)
            setSize(file.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Updates of apps this store installed need no dialog (Android 12+).
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Become the update owner so later updates stay silent (Android 14+).
                setRequestUpdateOwnership(true)
            }
        }
        val id = installer.createSession(params)
        val session = installer.openSession(id)
        try {
            file.inputStream().use { input ->
                session.openWrite("base.apk", 0, file.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val intent = Intent(this, InstallResultReceiver::class.java)
                .setAction(ACTION_INSTALL_RESULT)
                .putExtra(EXTRA_PACKAGE, pkg)
            // Mutable: the system adds the status extras.
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
            val pending = PendingIntent.getBroadcast(this, id, intent, flags)
            session.commit(pending.intentSender)
        } catch (e: Exception) {
            session.abandon()
            throw e
        } finally {
            session.close()
        }
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

/** Receives PackageInstaller session results. */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        val pkg = intent.getStringExtra(MainActivity.EXTRA_PACKAGE) ?: ""
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            // First install (or an update Android wants confirmed): one system dialog.
            @Suppress("DEPRECATION")
            val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            }
            if (confirm != null) {
                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(confirm)
            }
            return
        }
        val args = mapOf(
            "package" to pkg,
            "success" to (status == PackageInstaller.STATUS_SUCCESS),
            "status" to status,
            "message" to (intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""),
        )
        Handler(Looper.getMainLooper()).post { MainActivity.channel?.invokeMethod("installResult", args) }
    }
}
