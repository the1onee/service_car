package com.albatariq.app

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.util.Log
import java.io.File
import java.security.KeyStore

/**
 * جلسة Firebase المشفّرة تُنسَخ احتياطياً بينما مفتاح AndroidKeyStore لا يُنسَخ.
 * بعد الاستعادة يفشل فك التشفير ويبقى تسجيل الدخول في الذاكرة فقط.
 * إن غاب المفتاح تُحذف ملفات الجلسة التالفة قبل أن يقرأها Firebase.
 */
class AuthStorageRepair : ContentProvider() {
    override fun onCreate(): Boolean {
        val appContext = context ?: return true
        if (!firebearKeyMissing()) return true
        val prefsDir = File(appContext.applicationInfo.dataDir, "shared_prefs")
        val files = prefsDir.listFiles() ?: return true
        for (file in files) {
            val name = file.name
            if (name.startsWith("com.google.firebase.auth.") && name.endsWith(".xml")) {
                if (file.delete()) {
                    Log.i(TAG, "removed undecryptable auth prefs: $name")
                }
            }
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    private fun firebearKeyMissing(): Boolean {
        return try {
            val keyStore = KeyStore.getInstance("AndroidKeyStore")
            keyStore.load(null)
            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                if (aliases.nextElement().startsWith(KEY_PREFIX)) return false
            }
            true
        } catch (error: Exception) {
            Log.w(TAG, "keystore check skipped", error)
            false
        }
    }

    private companion object {
        const val TAG = "AuthStorageRepair"
        const val KEY_PREFIX = "firebear_main_key_id_for_storage_crypto"
    }
}
