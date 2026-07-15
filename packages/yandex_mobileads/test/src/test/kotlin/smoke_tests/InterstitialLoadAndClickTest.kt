package smoke_tests

import callbacks.InterstitialCallbacks
import com.yandex.plugin_tests_support.TestName
import io.qameta.allure.Epic
import io.qameta.allure.Story
import keys.HomeKeys
import keys.InterstitialKeys
import org.testng.annotations.Test
import com.yandex.plugin_tests_support.returnToApp
import com.yandex.plugin_tests_support.waitAndClick
import com.yandex.plugin_tests_support.backgroundApp
import com.yandex.plugin_tests_support.temporarilyLockScreen
import com.yandex.plugin_tests_support.waitForElement
import org.testng.annotations.DataProvider
import support.*
import java.time.Duration

@Epic("E2E тесты")
@Story("Flutter Загрузка, клик и закрытие Interstitial рекламы")
class InterstitialLoadAndClickTest: BaseFlutterTest() {

    @DataProvider(name = "demoBlocksProvider")
    fun demoBlocks(): Array<String> {
        return arrayOf(
            // РСЯ
            "demo-interstitial-yandex",
            "test-interstitial-video-tga-rmp",
            "test-interstitial-adpod-rmp",
            // Mediation
            "demo-interstitial-admanager",
            "demo-interstitial-admob",
            "demo-interstitial-appnext",
            "demo-interstitial-chartboost",
            "demo-interstitial-applovin",
            "demo-interstitial-inmobi",
            "demo-interstitial-ironsource",
            "demo-interstitial-mintegral",
            "demo-interstitial-mytarget",
            "test-interstitial-startapp",
            "demo-interstitial-unityads",
            "demo-interstitial-vungle",
            "demo-interstitial-pangle-land",
            "demo-interstitial-tapjoy",
            "demo-interstitial-applovin-max",
            "demo-interstitial-bigoads"
        )
    }

    @Test
    @TestName("Загрузка, клик и закрытие Interstitial рекламы")
    fun loadInterstitialAdAndClick() {
        waitAndClick(HomeKeys.interstitialPage)
        waitAndClick(InterstitialKeys.log)
        setAdUnitId(ScreenName.Interstitial, "demo-interstitial-yandex", true)
        waitAndClick(InterstitialKeys.loadAd)
        waitLogsCallback(InterstitialCallbacks.loaded)
        waitAndClick(InterstitialKeys.showAd)
        waitForElement(InterstitialKeys.ad)
        waitAndClick(InterstitialKeys.callToAction)
//        assertBrowserOpened()
        returnToApp()
        waitAndClick(InterstitialKeys.skipButton)
        waitAndClick(InterstitialKeys.closeAd)
        listOf(
            InterstitialCallbacks.shown,
            InterstitialCallbacks.clicked,
            InterstitialCallbacks.impression,
            InterstitialCallbacks.dismissed
        ).forEach { callback -> waitLogsCallback(callback) }
    }

    @Test
    @TestName("Interstitial: Сворачивание приложения")
    fun loadInterstitialAdAndHide() {
        waitAndClick(HomeKeys.interstitialPage)
        waitAndClick(InterstitialKeys.log)
        setAdUnitId(ScreenName.Interstitial, "demo-interstitial-yandex", true)
        waitAndClick(InterstitialKeys.loadAd)
        waitLogsCallback(InterstitialCallbacks.loaded)
        waitAndClick(InterstitialKeys.showAd)
        backgroundApp(Duration.ofSeconds(10), true)
        waitForElement(InterstitialKeys.ad)
    }

    @Test
    @TestName("Interstitial: Загрузка рекламы с некорректным блоком")
    fun loadInterstitialInvalidAd() {
        waitAndClick(HomeKeys.interstitialPage)
        waitAndClick(InterstitialKeys.log)
        setAdUnitId(ScreenName.Interstitial, "demo-interstitial-yandex1")
        waitAndClick(InterstitialKeys.loadAd)
        waitLogsCallback(InterstitialCallbacks.notExist)
    }

    @Test(dataProvider = "demoBlocksProvider")
    @TestName("Flutter Mediation и РСЯ. Отображение в landscape")
    fun loadDemoBanner(adUnitId: String) {
        waitAndClick(HomeKeys.interstitialPage)
        waitAndClick(InterstitialKeys.log)
        waitAndClick(InterstitialKeys.loadAd)
        safelyAssertAdLoaded(ScreenName.Interstitial)
        waitAndClick(InterstitialKeys.showAd)
        waitForElement(InterstitialKeys.ad)
    }

    @Test
    @TestName("Flutter Блокировка приложения")
    fun loadInterstitialAdAndBlock() {
        waitAndClick(HomeKeys.interstitialPage)
        waitAndClick(InterstitialKeys.log)
        setAdUnitId(ScreenName.Interstitial, "demo-interstitial-yandex", true)
        waitAndClick(InterstitialKeys.loadAd)
        waitLogsCallback(InterstitialCallbacks.loaded)
        waitAndClick(InterstitialKeys.showAd)
        waitForElement(InterstitialKeys.ad)
        temporarilyLockScreen(Duration.ofSeconds(10))
        waitForElement(InterstitialKeys.ad)
        waitAndClick(InterstitialKeys.skipButton)
        waitAndClick(InterstitialKeys.closeAd)
        waitLogsCallback(InterstitialCallbacks.impression)
    }
}
