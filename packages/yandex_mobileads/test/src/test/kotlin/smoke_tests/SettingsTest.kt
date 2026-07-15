package smoke_tests

import callbacks.BannerCallbacks
import com.yandex.plugin_tests_support.Functionalities.Settings
import com.yandex.plugin_tests_support.TestName
import com.yandex.plugin_tests_support.allureStep
import com.yandex.plugin_tests_support.assertScreenshot
import com.yandex.plugin_tests_support.assertSwitch
import com.yandex.plugin_tests_support.checkDebugPanelSetting
import com.yandex.plugin_tests_support.getDebugPanelSetting
import com.yandex.plugin_tests_support.goBack
import com.yandex.plugin_tests_support.platformDependant
import com.yandex.plugin_tests_support.pressKey
import com.yandex.plugin_tests_support.rotateScreen
import com.yandex.plugin_tests_support.scrollTo
import com.yandex.plugin_tests_support.waitAndClick
import com.yandex.plugin_tests_support.waitForElement
import io.qameta.allure.Epic
import io.qameta.allure.Feature
import keys.BannerKeys
import keys.DebugPanelKeys
import keys.HomeKeys
import keys.SettingsKeys
import org.openqa.selenium.By
import org.openqa.selenium.ScreenOrientation
import org.testng.annotations.Test
import support.ScreenName
import support.setAdUnitId
import support.waitLogsCallback

@Epic("E2E тесты")
@Feature(Settings)
class SettingsTest: BaseFlutterTest() {

    @Test
    @TestName("Flutter Debug Error Indicator")
    fun testDebugErrorIndicator() {
        waitAndClick(HomeKeys.settingsPage)
        waitAndClick(SettingsKeys.debugErrorIndicator)
        goBack()
        waitAndClick(HomeKeys.bannerPage)
        waitAndClick(BannerKeys.log)
        setAdUnitId(ScreenName.Banner, "demo-banner-yandex", true)
        waitAndClick(BannerKeys.loadAd)
        waitLogsCallback(BannerCallbacks.loaded)
        waitForElement(BannerKeys.banner)
    }

    @Test
    @TestName("Flutter Настройки в дебаг панели")
    fun testDebugPanelSettings() {
        rotateScreen(ScreenOrientation.PORTRAIT)

        waitAndClick(HomeKeys.settingsPage)
        waitAndClick(SettingsKeys.userConsent)
        waitAndClick(SettingsKeys.locationConsent)
        waitAndClick(SettingsKeys.ageRestrictedUser)
        assertSwitch(SettingsKeys.userConsent, true)
        assertSwitch(SettingsKeys.locationConsent, true)
        assertSwitch(SettingsKeys.ageRestrictedUser, true)
        goBack()
        waitAndClick(HomeKeys.debugPanel)
        scrollTo(getDebugPanelSetting(DebugPanelKeys.hasUserConsentKey))
        checkDebugPanelSetting(DebugPanelKeys.ageRestrictedUser, "Yes")
        platformDependant(android = { ->
            checkDebugPanelSetting(DebugPanelKeys.hasLocationConsent, "Yes")
        })
        checkDebugPanelSetting(DebugPanelKeys.hasUserConsentKey, "Yes")
        goBack()
        waitAndClick(HomeKeys.settingsPage)
        waitAndClick(SettingsKeys.userConsent)
        waitAndClick(SettingsKeys.locationConsent)
        waitAndClick(SettingsKeys.ageRestrictedUser)
        assertSwitch(SettingsKeys.userConsent, false)
        assertSwitch(SettingsKeys.locationConsent, false)
        assertSwitch(SettingsKeys.ageRestrictedUser, false)
        goBack()
        waitAndClick(HomeKeys.debugPanel)
        scrollTo(getDebugPanelSetting(DebugPanelKeys.hasUserConsentKey))
        checkDebugPanelSetting(DebugPanelKeys.ageRestrictedUser, "No")
        checkDebugPanelSetting(DebugPanelKeys.hasLocationConsent, "No")
        checkDebugPanelSetting(DebugPanelKeys.hasUserConsentKey, "No")
    }

    @Test
    @TestName("Flutter: Проверка DebugPanel")
    fun testDebugPanel() {
        rotateScreen(ScreenOrientation.PORTRAIT)

        waitAndClick(HomeKeys.debugPanel)
        platformDependant(android = { ->
            waitForElement(DebugPanelKeys.root)
            assertScreenshot(DebugPanelKeys.integrationStatus, "integration_status")
        })
        checkDebugPanelSetting("Application ID")
        checkDebugPanelSetting("App Version")
        platformDependant(ios = { ->
            checkDebugPanelSetting("iOS Version")
        }, android = {
            checkDebugPanelSetting("System")
            checkDebugPanelSetting("API Level")
        })
        checkDebugPanelSetting("SDK Version")
        checkDebugPanelSetting("SDK Integration Status")
        try {
            checkDebugPanelSetting("Completed Integration")
        } catch (_: Exception) {
            checkDebugPanelSetting("Invalid Integration")
        }
        scrollTo(getDebugPanelSetting(DebugPanelKeys.hasUserConsentKey))
        checkDebugPanelSetting(DebugPanelKeys.ageRestrictedUser)
        checkDebugPanelSetting(DebugPanelKeys.hasLocationConsent)
        checkDebugPanelSetting(DebugPanelKeys.hasUserConsentKey)
        checkDebugPanelSetting("TCF Consent")
    }
}
