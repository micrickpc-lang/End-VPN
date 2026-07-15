package x

import android.app.Application
import android.os.Build

object CoreLoader____ {
    @JvmStatic
    fun loadLibrary(ignored: String) {
        val processName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Application.getProcessName()
        } else {
            ""
        }
        System.loadLibrary(if (processName.endsWith(":xray")) "xrayjni" else "box")
    }
}
