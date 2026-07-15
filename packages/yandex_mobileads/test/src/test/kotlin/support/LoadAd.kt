package support

import callbacks.InterstitialCallbacks
import com.yandex.plugin_tests_support.BaseTest
import com.yandex.plugin_tests_support.getElementContentDescription
import keys.CommonKeys
import org.testng.SkipException
import kotlin.time.TimeSource
import kotlin.time.toKotlinDuration

private val noAdsErrorText = "there are no ads available"

fun BaseTest.safelyAssertAdLoaded(screen: ScreenName) {
    try {
        waitLogsCallback(screen.adLoadedCallback())
    } catch (err: AssertionError) {
        val logs = getElementContentDescription(CommonKeys.logText)
        if (logs.contains(noAdsErrorText)) {
            throw SkipException("No ads available, skipping")
        } else {
            throw err
        }
    }
}
