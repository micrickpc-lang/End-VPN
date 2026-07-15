package support

import callbacks.AppOpenAdCallbacks
import callbacks.BannerCallbacks
import callbacks.InterstitialCallbacks
import callbacks.RewardedCallbacks
import com.yandex.plugin_tests_support.BaseTest
import com.yandex.plugin_tests_support.ScreenElement
import com.yandex.plugin_tests_support.allureStep
import com.yandex.plugin_tests_support.enterText
import keys.AppOpenAdKeys
import keys.BannerKeys
import keys.InterstitialKeys
import keys.RewardedKeys

enum class ScreenName {
    AppOpenAd {
        override fun adUnitIdField() = AppOpenAdKeys.adUnitId
        override fun adLoadedCallback() = AppOpenAdCallbacks.loaded
    }, Banner {
        override fun adUnitIdField() = BannerKeys.adUnitId
        override fun adLoadedCallback() = BannerCallbacks.loaded
    }, Interstitial {
        override fun adUnitIdField() = InterstitialKeys.adUnitId
        override fun adLoadedCallback() = InterstitialCallbacks.loaded
    }, Rewarded {
        override fun adUnitIdField() = RewardedKeys.adUnitId
        override fun adLoadedCallback() = RewardedCallbacks.loaded
    };

    abstract fun adUnitIdField(): ScreenElement
    abstract fun adLoadedCallback(): String
}

fun BaseTest.setAdUnitId(screen: ScreenName, adUnitId: String, isDry: Boolean = false) {
    if (isDry) {
        allureStep("Ввести текст \"$adUnitId\" в поле Ad unit ID")
    } else {
        enterText(screen.adUnitIdField(), adUnitId)
    }
}
