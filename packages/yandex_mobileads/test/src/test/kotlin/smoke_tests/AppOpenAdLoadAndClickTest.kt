package smoke_tests

import callbacks.AppOpenAdCallbacks
import com.yandex.plugin_tests_support.Functionalities.AppOpenAd
import com.yandex.plugin_tests_support.TestName
import com.yandex.plugin_tests_support.allureStep
import com.yandex.plugin_tests_support.assertBrowserOpened
import com.yandex.plugin_tests_support.backgroundApp
import com.yandex.plugin_tests_support.rotateScreen
import com.yandex.plugin_tests_support.returnToApp
import com.yandex.plugin_tests_support.temporarilyLockScreen
import com.yandex.plugin_tests_support.waitAndClick
import com.yandex.plugin_tests_support.waitForElement
import io.qameta.allure.Epic
import io.qameta.allure.Feature
import io.qameta.allure.Story
import keys.AppOpenAdKeys
import keys.HomeKeys
import org.testng.annotations.DataProvider
import org.testng.annotations.Test
import org.openqa.selenium.ScreenOrientation
import support.ScreenName
import support.setAdUnitId
import support.waitLogsCallback
import java.time.Duration

@Epic("E2E тесты")
@Story("AppOpenAd Загрузка и клик по рекламе")
@Feature(AppOpenAd)
class AppOpenAdLoadAndClickTest: BaseFlutterTest() {

    @DataProvider(name = "demoBlocksProvider")
    fun demoBlocks(): Array<String> {
        return arrayOf(
            "test-appopenad-direct-rmp",
            "demo-appopenad-yandex",
            "demo-appopenad-admob"
        )
    }

    @Test
    @TestName("AppOpenAd: Загрузка и клик по рекламе")
    fun loadAppOpenAdAndClick() {
        waitAndClick(HomeKeys.appOpenAd)
        waitAndClick(AppOpenAdKeys.log)
        setAdUnitId(ScreenName.AppOpenAd, "demo-appopenad-yandex", true)
        waitAndClick(AppOpenAdKeys.loadAd)
        waitLogsCallback(AppOpenAdCallbacks.loaded)
        waitAndClick(AppOpenAdKeys.showAd)
        waitForElement(AppOpenAdKeys.ad)
        waitAndClick(AppOpenAdKeys.callToAction)
        assertBrowserOpened()
        returnToApp()
        waitAndClick(AppOpenAdKeys.closeAd)
        listOf(
            AppOpenAdCallbacks.shown,
            AppOpenAdCallbacks.clicked,
            AppOpenAdCallbacks.impression,
            AppOpenAdCallbacks.dismissed
        ).forEach { callback -> waitLogsCallback(callback) }
    }

    @Test
    @TestName("Flutter Блокировка приложения")
    fun loadAppOpenAdAndBlock() {
        waitAndClick(HomeKeys.appOpenAd)
        waitAndClick(AppOpenAdKeys.log)
        setAdUnitId(ScreenName.AppOpenAd, "demo-appopenad-yandex", true)
        waitAndClick(AppOpenAdKeys.loadAd)
        waitLogsCallback(AppOpenAdCallbacks.loaded)
        waitAndClick(AppOpenAdKeys.showAd)
        waitForElement(AppOpenAdKeys.ad)
        temporarilyLockScreen(Duration.ofSeconds(10))
        waitForElement(AppOpenAdKeys.ad)
        waitAndClick(AppOpenAdKeys.closeAd)
        waitLogsCallback(AppOpenAdCallbacks.impression)
    }

    @Test
    @TestName("AppOpenAd: Сворачивание приложения")
    fun loadAppOpenAdHideApp() {
        waitAndClick(HomeKeys.appOpenAd)
        waitAndClick(AppOpenAdKeys.log)
        setAdUnitId(ScreenName.AppOpenAd, "demo-appopenad-yandex", true)
        waitAndClick(AppOpenAdKeys.loadAd)
        waitLogsCallback(AppOpenAdCallbacks.loaded)
        waitAndClick(AppOpenAdKeys.showAd)
        backgroundApp(Duration.ofSeconds(10), true)
        waitForElement(AppOpenAdKeys.ad)
    }

    @Test
    @TestName("AppOpenAd: Загрузка рекламы с некорректным блоком")
    fun loadAppOpenInvalidAd() {
        waitAndClick(HomeKeys.appOpenAd)
        waitAndClick(AppOpenAdKeys.log)
        setAdUnitId(ScreenName.AppOpenAd, "demo-appopenad-yandex1")
        waitAndClick(AppOpenAdKeys.loadAd)
        waitLogsCallback(AppOpenAdCallbacks.notExist)
    }
}
