package smoke_tests

import callbacks.RewardedCallbacks
import com.yandex.plugin_tests_support.TestName
import io.qameta.allure.Epic
import io.qameta.allure.Story
import keys.HomeKeys
import keys.RewardedKeys
import org.testng.annotations.Test
import com.yandex.plugin_tests_support.waitAndClick
import com.yandex.plugin_tests_support.backgroundApp
import com.yandex.plugin_tests_support.temporarilyLockScreen
import com.yandex.plugin_tests_support.waitForElement
import org.testng.annotations.DataProvider
import support.*
import java.time.Duration

@Epic("E2E тесты")
@Story("Flutter Загрузка, клик и закрытие Rewarded рекламы")
class RewardedLoadAndClickTest: BaseFlutterTest() {

    @DataProvider(name = "demoBlocksProvider")
    fun demoBlocks(): Array<String> {
        return arrayOf(
            // РСЯ
            "demo-rewarded-yandex",
            "test-rewarded-rmp",
            // Mediation
            "demo-rewarded-admanager",
            "demo-rewarded-admob",
            "demo-rewarded-appnext",
            "demo-rewarded-chartboost",
            "demo-rewarded-applovin",
            "demo-rewarded-inmobi",
            "demo-rewarded-ironsource",
            "demo-rewarded-mintegral",
            "demo-rewarded-mytarget",
            "test-rewarded-startapp",
            "demo-rewarded-unityads",
            "demo-rewarded-vungle",
            "demo-rewarded-pangle",
            "demo-rewarded-tapjoy",
            "demo-rewarded-applovin-max",
            "demo-rewarded-bigoads"
        )
    }

    @Test
    @TestName("Flutter Загрузка, клик и закрытие Rewarded рекламы")
    fun loadRewardedAdAndClick() {
        waitAndClick(HomeKeys.rewardedPage)
        waitAndClick(RewardedKeys.log)
        setAdUnitId(ScreenName.Rewarded, "demo-rewarded-yandex", true)
        waitAndClick(RewardedKeys.loadAd)
        waitLogsCallback(RewardedCallbacks.loaded)
        waitAndClick(RewardedKeys.showAd)
//        waitForElement(RewardedKeys.ad, checkForDisplay = false)
//        waitAndClick(RewardedKeys.callToAction)
//        assertBrowserOpened()
//        returnToApp()
//        waitAndClick(RewardedKeys.closeAd)
//        listOf(
//            RewardedCallbacks.shown,
//            RewardedCallbacks.clicked,
//            RewardedCallbacks.impression,
//            RewardedCallbacks.dismissed
//        ).forEach { callback -> waitLogsCallback(callback) }
    }

    @Test
    @TestName("Rewarded: Сворачивание приложения")
    fun loadRewardedAdAndHide() {
        waitAndClick(HomeKeys.rewardedPage)
        waitAndClick(RewardedKeys.log)
        setAdUnitId(ScreenName.Rewarded, "demo-rewarded-yandex", true)
        waitAndClick(RewardedKeys.loadAd)
        waitLogsCallback(RewardedCallbacks.loaded)
        waitAndClick(RewardedKeys.showAd)
        backgroundApp(Duration.ofSeconds(10), true)
        //waitForElement(RewardedKeys.ad)
    }

    @Test
    @TestName("Rewarded: Загрузка рекламы с некорректным блоком")
    fun loadAppOpenInvalidAd() {
        waitAndClick(HomeKeys.rewardedPage)
        waitAndClick(RewardedKeys.log)
        setAdUnitId(ScreenName.Rewarded, "demo-rewarded-yandex1")
        waitAndClick(RewardedKeys.loadAd)
        waitLogsCallback(RewardedCallbacks.notExist)
    }

    @Test(dataProvider = "demoBlocksProvider")
    @TestName("Flutter Mediation и РСЯ. Отображение Rewarded рекламы в AdRequest в landscape")
    fun loadDemoBanner(adUnitId: String) {
        waitAndClick(HomeKeys.rewardedPage)
        waitAndClick(RewardedKeys.log)
        waitAndClick(RewardedKeys.loadAd)
        safelyAssertAdLoaded(ScreenName.Rewarded)
        waitAndClick(RewardedKeys.showAd)
        //waitForElement(RewardedKeys.ad)
    }

    @Test
    @TestName("Flutter Блокировка приложения")
    fun loadRewardedAdAndBlock() {
        waitAndClick(HomeKeys.rewardedPage)
        waitAndClick(RewardedKeys.log)
        setAdUnitId(ScreenName.Rewarded, "demo-rewarded-yandex", true)
        waitAndClick(RewardedKeys.loadAd)
        waitLogsCallback(RewardedCallbacks.loaded)
        waitAndClick(RewardedKeys.showAd)
        //waitForElement(RewardedKeys.ad)
        temporarilyLockScreen(Duration.ofSeconds(10))
        //waitForElement(RewardedKeys.ad)
        //waitAndClick(RewardedKeys.closeAd)
        //waitLogsCallback(RewardedCallbacks.impression)
    }

    @Test
    @TestName("Flutter РСЯ. Закрытие рекламы до получения награды")
    fun loadRewardedAdAndClose() {
        waitAndClick(HomeKeys.rewardedPage)
        waitAndClick(RewardedKeys.log)
        setAdUnitId(ScreenName.Rewarded, "demo-rewarded-yandex", true)
        waitAndClick(RewardedKeys.loadAd)
        waitLogsCallback(RewardedCallbacks.loaded)
        waitAndClick(RewardedKeys.showAd)
        //waitForElement(RewardedKeys.ad)
        //waitAndClick(RewardedKeys.closeAd)
        //checkCallbackNotAppeared(RewardedCallbacks.impression)
    }
}
