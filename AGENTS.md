# AGENTS.md — Asteroid

Asteroid is an **iOS jailbreak tweak** built with **Theos**, originally created by **MidnightChips & the casle**, modernized for **iOS 15–16+ rootless jailbreaks (Dopamine, Palera1n)**. It brings comprehensive, system-wide live weather to iOS, featuring animated weather backgrounds on the Home Screen and Lock Screen, interactive custom Lock Screen weather components with editing mode, live status bar weather glyphs/temperature (and carrier replacement), a live updating Weather app icon, and default city selection inside the native Weather app.

- Package ID: `com.midnightchips.asteroid` (see `control`, version `4.0.0`).
- Scheme: **rootless only** (`THEOS_PACKAGE_SCHEME = rootless`, `iphoneos-arm64`, installs under `/var/jb`).
- Architecture: `iphoneos-arm64` (builds `arm64 arm64e`), target `iphone:clang:latest:15.0`.
- Depends on: `firmware (>= 15.0)`, `mobilesubstrate`, `preferenceloader`.
- Primary test environment: Dopamine / Palera1n, iOS 16.x.
- Creators: MidnightChips & the casle.
- License: GPL-3.0 (`LICENSE.md`).

## Layout

| Path | Purpose |
|---|---|
| `Makefile` | Root aggregate Theos makefile targeting iOS 15.0+ rootless for tweak and 4 subprojects (`preferences`, `asteroidlockscreen`, `asteroidstatusbar`, `defaultweather`). |
| `control` | Debian package control metadata (`iphoneos-arm64`, version 4.0.0). |
| `Asteroid.plist` | Substrate filter for the primary tweak (injects into `com.apple.springboard`). |
| `source/Asteroid.h` | Core definitions, headers for `WUIWeatherConditionBackgroundView`, `WUIDynamicWeatherBackground`, `WUIWeatherCondition`. |
| `source/WeatherHeaders.h` | Private weather framework headers: `City`, `WFTemperature`, `WFLocation`, `WeatherLocationManager`, `WeatherPreferences`. |
| `source/AWeatherModel.h/.xm` | Singleton weather model (`WATodayModel` / `WAForecastModel`), location fetching, refresh timer, condition code fallback/verification, and glyph loader with SF Symbols fallback. |
| `source/ASTWeatherBackgroundView.h/.m` | Native iOS 15–16+ animated weather background (`ASTWeatherConditionBackgroundView`, `ASTDynamicWeatherBackground`, `ASTWeatherCondition`) loading Apple's official `.caml` CoreAnimation Mica weather animations and `.heic` particle/cloud/sun assets from `WeatherUI.framework/Mica/` via `CAMLParser` / `CAMLLoader` and sky gradients from `WAGradientProvider` (`Weather.framework`). |
| `source/AsteroidServer.xm` | SpringBoard IPC server caching weather to user preferences and providing optional CPDistributedMessagingCenter support. |
| `source/HomeScreenAnimation.xm` | Live animated wallpaper on `SBHomeScreenView` using `WUIWeatherConditionBackgroundView` / `ASTWeatherConditionBackgroundView`, dock/folder appearance options, and safe backlight-aware pause/resume hooks. |
| `source/lockScreenAnimation.xm` | Animated live weather background view on Lock Screen supporting both modern `CSCoverSheetView` (iOS 13–16) and legacy `SBDashBoardView`. |
| `source/LiveWeatherView.h/.x` | Reusable live weather view displaying condition glyph, temperature label, and animated/gradient weather background. |
| `source/AsteroidIcon.xm` | Hooks `SBIconImageView` to render `LiveWeatherView` inside the native Weather app icon (`com.apple.weather`) with continuous corner masking. |
| `source/ASTCoverSheetStatusBarX.xm` | Hooks `_UIStatusBarCellularItem` to replace the carrier string with the current weather glyph and temperature. |
| `source/LWPProvider.h/.m` | Standalone rootless preferences provider using `CFPreferences` and Darwin notifications (`com.midnightchips.asteroid.prefschanged`). |
| `source/DGLogging.h/.m` | Debug logging helpers (`FLOG`). |
| `asteroidlockscreen/` | Lock screen overlay tweak (`AsteroidLockScreen.xm`, `ASTViewController.mm`, `ASTComponentView.m`, `ASTGestureHandler.m`). Modular interactive weather widgets with drag & drop and wiggle edit mode, supporting modern CoverSheet (`CSMainPageView` / `CSCoverSheetViewController`). |
| `asteroidstatusbar/` | Status bar tweak (`AsteroidStatusBar.xm`) injecting into `com.apple.UIKit`, providing tap-to-swap time and weather on `_UIStatusBarStringView`. |
| `defaultweather/` | Weather app tweak (`defaultweather.xm`, `DefaultWeatherView.m`) injecting into `com.apple.weather`, adding switch into `WAWeatherCardView` to select Asteroid's default city. |
| `preferences/` | Standard PreferenceLoader bundle `Asteroid.bundle` using native `PSListController`, custom `CSListItemsController` with native Dark Mode support, `CSPLinkCell` subtitle cells, multi-table string localization, and iOS 14+ `UIColorPickerViewController`, staged to rootless paths. |

## How it works

1. **Weather Data & Location Pipeline (`AWeatherModel.xm`):**
   - Implements a central singleton `[AWeatherModel sharedInstance]` interacting with Apple's private `Weather.framework` and `WeatherUI.framework`.
   - Uses `[objc_getClass("WATodayModel") autoupdatingLocationModelWithPreferences:effectiveBundleIdentifier:@"com.apple.weather"]` to execute asynchronous model updates.
   - Upon completion, retrieves `WAForecastModel` and `City`, validates condition codes via `-verifyAndCorrectCondition` (handling edge conditions like code 7 -> 6 and day/night validation), and posts `weatherTimerUpdate` over `NSNotificationCenter`.
   - Provides condition glyphs using native Weather image loader, with automatic fallback to modern **SF Symbols** (`sun.max.fill`, `cloud.rain.fill`, `snowflake`, etc.) on iOS 13+.
   - Falls back to configured saved cities from `WeatherPreferences` if location services are unavailable or denied (`astDefaultIndex`).
   - Manages periodic updates using an `NSTimer` (`refreshRate`, defaults to 300 seconds; minimum enforced 30s).

2. **Cross-Process Data Sharing & Preferences (`AsteroidServer.xm` & `LWPProvider`):**
   - Eliminates legacy hard dependencies on RocketBootstrap and CreatureSurvive libraries.
   - SpringBoard publishes the latest weather string and icon data to shared preferences (`com.midnightchips.asteroid`) whenever the weather updates.
   - External processes (e.g. `asteroidstatusbar` in `com.apple.UIKit`, or `defaultweather` in `com.apple.weather`) read directly via `cfprefsd` / `LWPProvider` without inter-process crashes.
   - Dynamic `dlsym` fallback to `CPDistributedMessagingCenter` is retained for environments where RocketBootstrap / LightMessaging is active.

3. **Wallpaper & Live Weather Animations (`HomeScreenAnimation.xm`, `lockScreenAnimation.xm`):**
   - Hooks `SBHomeScreenView` to embed `WUIWeatherConditionBackgroundView` directly behind icons, dynamically setting the condition on `WUIDynamicWeatherBackground`.
   - Supports both modern iOS 13–16 `CSCoverSheetView` and legacy `SBDashBoardView` dynamically using Logos `%group` and `%init(LockScreenCoverSheet, CSCoverSheetView = coverSheetClass)`.
   - **Battery Conservation:** Uses safe class-introspection to query `_isScreenOn` or `SBBacklightController` (avoiding unsafe `MSHookIvar` crashes on modern iOS), pausing `WUIWeatherCondition` animations when the screen is dimmed/sleeping or a foreground app is active.

4. **Modular Lock Screen Widgets & Interactive Edit Mode (`asteroidlockscreen`):**
   - Hooks `CSMainPageView` (iOS 13–16) and `SBDashBoardMainPageView` (iOS 11–12) to instantiate `ASTViewController`.
   - Hosts modular weather subviews wrapped in `ASTComponentView`:
     - Weather condition logo (`UIImageView`)
     - Current temperature label (`currentTemp`)
     - Greeting message (`greetingLabel`)
     - Weather description label (`wDescription`)
     - Native Weather platter hourly/daily forecast (`WAWeatherPlatterViewController`)
     - Dismiss button (`dismissButton`)
     - Notification badge counter (`notificationLabel`)
   - **Interactive Editing:** Long-pressing widgets activates an edit state via `ASTGestureHandler`, adding SpringBoard-style jitter/wiggle animations (`[self _jitterXTranslationAnimation]`). Positions are persisted using `<rootless.h>` `ROOT_PATH_NS(@"/var/mobile/Library/Asteroid/centerData.plist")`.

5. **Status Bar Integration (`asteroidstatusbar` & `ASTCoverSheetStatusBarX.xm`):**
   - `ASTCoverSheetStatusBarX.xm` hooks `_UIStatusBarCellularItem` to replace the carrier label with an inline `NSTextAttachment` weather glyph and temperature string.
   - `AsteroidStatusBar.xm` hooks modern status bar time labels (`_UIStatusBarStringView`): adds a `UITapGestureRecognizer` to allow tapping the status bar time to toggle dynamically between the current time and live weather conditions.

6. **Native Weather App Default City Selector (`defaultweather`):**
   - Hooks `WAWeatherCardView` in `com.apple.weather`.
   - Embeds a custom `DefaultWeatherView` switch on saved non-local weather cities, allowing users to select which city Asteroid uses as its default fallback.

7. **Live Weather App Icon (`AsteroidIcon.xm`):**
   - Subclasses `SBIconImageView` as `%subclass SBLiveWeatherIconImageView : SBIconImageView`.
   - Instantiates and constraints a `LiveWeatherView` over the Weather app icon (`com.apple.weather`), rendering the current condition glyph, temperature, and live gradient background in real time.

## Preference keys (`com.midnightchips.asteroid`)

Preferences are managed via `LWPProvider` using `CFPreferences` and Darwin notifications:

| Key | Type | Default | Description |
|---|---|---|---|
| `kLWPEnabled` | bool | `true` | Master switch to enable or disable Asteroid. |
| `homeScreenWeather` | bool | `false` | Enables animated weather wallpaper on the Home Screen. |
| `hideHomeWeatherBackground` | integer | `0` | `0` = show both, `1` = hide gradient, `2` = hide conditions. |
| `freezeCondition` | bool | `false` | Pauses all weather animations to freeze current frame. |
| `customCondition` | bool | `false` | Overrides live weather condition with a fixed chosen condition. |
| `weatherConditions` | double | `0` | Condition code index used when `customCondition` is active. |
| `refreshRate` | integer | `300` | Weather data update interval in seconds (minimum 30s). |
| `astDefaultIndex` | integer | `0` | City index from saved weather cities used for fallback. |
| `greetView` | bool | `false` | Enables Lock Screen weather greeting view. |
| `addgreetLabel` | bool | `false` | Displays greeting label on Lock Screen. |
| `addDescription` | bool | `false` | Displays natural language weather description on Lock Screen. |
| `addTemp` | bool | `false` | Displays temperature label on Lock Screen. |
| `addLogo` | bool | `false` | Displays weather glyph logo on Lock Screen. |
| `addDismiss` | bool | `false` | Displays Lock Screen dismiss button. |
| `addBlur` | bool | `false` | Applies blur behind Lock Screen components. |
| `enableEditingMode` | bool | `true` | Enables gesture-based repositioning and wiggle mode on Lock Screen. |
| `foreHeight` | real | `220` | Height constraint for native forecast platter view. |
| `textColor` | string | `FFFFFF` | Hex color code for weather text elements. |
| `glyphColor` | string | `FFFFFF` | Hex color code for weather glyphs. |
| `noFolders` | bool | `false` | Removes folder icon backgrounds on Home Screen. |
| `noDock` | bool | `false` | Hides the SpringBoard dock background. |

## Build / install

Requires [Theos](https://theos.dev/) with `$THEOS` set and an iOS 15+ SDK.

```sh
make package                                      # build rootless .deb (iphoneos-arm64)
make package install THEOS_DEVICE_IP=<device-ip>  # install over SSH, resprings SpringBoard
```

Makefile targets: `TARGET = iphone:clang:latest:15.0`, `ARCHS = arm64 arm64e`, `THEOS_PACKAGE_SCHEME = rootless`.

## Conventions and gotchas

- **ARC enabled (`-fobjc-arc`)**: Used across `Asteroid`, `preferences`, and all subprojects.
- **Rootless paths:** Uses `<rootless.h>` `ROOT_PATH` and `ROOT_PATH_NS` for all filesystem operations outside `/var/mobile/Library/Preferences/`.
- **CoverSheet & Lock Screen Compatibility:** Hooks dynamically resolve between modern iOS 13–16 `CoverSheet` classes (`CSCoverSheetView`, `CSMainPageView`, `CSCoverSheetViewController`) and legacy iOS 11–12 `SBDashBoard*` classes.
- **Safe Introspection:** Replaced raw `MSHookIvar` calls with safe runtime checks (`class_getInstanceVariable`, `respondsToSelector:`) to ensure stability across major iOS version updates.
