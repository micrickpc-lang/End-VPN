package smoke_tests

import banner.BannerSizeType
import banner.setBannerSizeType
import callbacks.BannerCallbacks
import com.yandex.plugin_tests_support.TestName
import com.yandex.plugin_tests_support.assertBrowserOpened
import com.yandex.plugin_tests_support.assertRequest
import com.yandex.plugin_tests_support.backgroundApp
import com.yandex.plugin_tests_support.goBack
import com.yandex.plugin_tests_support.platformDependant
import com.yandex.plugin_tests_support.returnToApp
import com.yandex.plugin_tests_support.temporarilyLockScreen
import com.yandex.plugin_tests_support.waitAndClick
import com.yandex.plugin_tests_support.waitForElement
import io.qameta.allure.Epic
import io.qameta.allure.Story
import keys.BannerKeys
import keys.CommonKeys
import keys.HomeKeys
import org.testng.annotations.DataProvider
import org.testng.annotations.Test
import support.ScreenName
import support.checkCallbackNotAppeared
import support.safelyAssertAdLoaded
import support.setAdUnitId
import support.waitLogsCallback
import java.time.Duration

@Epic("E2E тесты")
@Story("Flutter: Загрузка и клик по баннеру")
class BannerLoadAndClickTest: BaseFlutterTest() {
    @DataProvider(name = "sizeTypeProvider")
    fun sizeTypes(): Array<BannerSizeType> {
        return arrayOf(
            BannerSizeType.Inline(400, 240),
            BannerSizeType.Sticky(null)
        )
    }

    @DataProvider(name = "demoBlocksProvider")
    fun demoBlocks(): Array<String> {
        return arrayOf(
            "demo-banner-admanager",
            "demo-banner-admob",
            "demo-banner-appnext",
            "demo-banner-chartboost",
            "demo-banner-applovin",
            "demo-banner-ironsource",
            "demo-banner-mintegral",
            "demo-banner-mytarget",
            "test-banner-startapp",
            "demo-banner-vungle",
            "demo-banner-applovin-max",
            "demo-banner-sticky-bigoads",
        )
    }

    @Test(dataProvider = "sizeTypeProvider")
    @TestName("Загрузка и клик по баннеру")
    fun loadStickyBannerAdAndClick(sizeType: BannerSizeType) {
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        setBannerSizeType(sizeType)
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex", true)
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
        waitAndClick(BannerKeys.banner)
        assertBrowserOpened()
        returnToApp()
        listOf(
            BannerCallbacks.clicked,
            BannerCallbacks.impression,
            BannerCallbacks.leftApp
        ).forEach { callback -> waitLogsCallback(callback) }
        platformDependant(android = { ->
            waitLogsCallback(BannerCallbacks.returnedToApp)
        })
    }

    @Test
    @TestName("Загрузка и клик по Inline баннеру")
    fun loadInlineBannerAdAndClick() {
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        setBannerSizeType(BannerSizeType.Inline(400, 240))
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex", true)
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
        assertRequest("/ads/v4/ad")
        waitAndClick(BannerKeys.banner)
        assertBrowserOpened()
        returnToApp()

        listOf(
            BannerCallbacks.clicked,
            BannerCallbacks.impression,
            BannerCallbacks.leftApp
        ).forEach { callback -> waitLogsCallback(callback) }
        platformDependant(android = { ->
            waitLogsCallback(BannerCallbacks.returnedToApp)
        })
    }

    @Test
    @TestName("Загрузка и клик по Sticky баннеру")
    fun loadStickyBannerAdAndClick() {
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        waitAndClick(BannerKeys.stickySwitch)
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex", true)
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
        waitAndClick(BannerKeys.banner)
        assertBrowserOpened()
        returnToApp()
        listOf(
            BannerCallbacks.loaded,
            BannerCallbacks.impression,
            BannerCallbacks.clicked,
            BannerCallbacks.leftApp
        ).forEach { callback -> waitLogsCallback(callback) }
        platformDependant(android = { ->
            waitLogsCallback(BannerCallbacks.returnedToApp)
        })
    }

    @Test()
    @TestName("Banner: Сворачивание приложения")
    fun loadBannerAdAndHide() {
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        waitAndClick(BannerKeys.stickySwitch)
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex", true)
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
        backgroundApp(Duration.ofSeconds(10), true)
        waitForElement(BannerKeys.banner)
    }

    @Test()
    @TestName("Banner: Перезагрузка баннера")
    fun reloadBannerAd() {
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex", true)
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
        waitAndClick(CommonKeys.logClear)
        checkCallbackNotAppeared(BannerCallbacks.loaded, Duration.ofSeconds(3))
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
    }

    @Test
    @TestName("Banner: Загрузка рекламы с некорректным блоком")
    fun loadAppOpenInvalidAd() {
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex1")
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.notExist)
    }

    @Test(dataProvider = "demoBlocksProvider")
    @TestName("Flutter Mediation: Загрузка и клик по Inline баннеру")
    fun loadStickyBannerAdAndClick(adUnitId: String) {
        val sizeTypes = arrayOf(
            BannerSizeType.Inline(320, 50),
            BannerSizeType.Sticky(null)
        )
        for (sizeType in sizeTypes) {
            waitAndClick(HomeKeys.bannerPage)
            waitAndClick(BannerKeys.log)
            setBannerSizeType(sizeType)
            setAdUnitId(ScreenName.Banner, adUnitId)
            waitAndClick(BannerKeys.loadAd)
            safelyAssertAdLoaded(ScreenName.Banner)
//            waitAndClick(BannerKeys.banner)
//            assertBrowserOpened()
//            returnToApp()
            listOf(
//                BannerCallbacks.clicked,
                BannerCallbacks.impression
            ).forEach { callback -> waitLogsCallback(callback) }
            goBack()
        }
    }

    @Test
    @TestName("Flutter Блокировка приложения")
    fun loadBannerAdAndBlock() {
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex", true)
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
        waitForElement(BannerKeys.banner)
        temporarilyLockScreen(Duration.ofSeconds(10))
        waitForElement(BannerKeys.banner)
    }
}

