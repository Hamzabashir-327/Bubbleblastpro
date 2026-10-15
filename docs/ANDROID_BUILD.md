# Building the Android APK / AAB

Nothing here was run in the original build sandbox (no Godot, no Android SDK, no internet), so treat this as the
tested-by-documentation procedure for Godot 4.5. If a menu is named slightly differently in your Godot patch
release, follow Godot's own guide: <https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html>

## 1. One-time setup

| Need | Version | Notes |
|---|---|---|
| Godot | **4.5-stable** (standard build) | the AdMob plugin docs require Godot 4.5.0+ |
| Export templates | same as the editor | Editor -> *Manage Export Templates* -> Download and Install |
| JDK | **17** | `java -version` must say 17 |
| Android SDK | command-line tools, platform-tools, build-tools 35, platform android-35, CMake 3.10.2, NDK 28.1 (per Godot's Android export docs) | `sdkmanager "platform-tools" "build-tools;35.0.1" "platforms;android-35" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"` |

In Godot: *Editor -> Editor Settings -> Export -> Android*: set **Android SDK Path**, **Java SDK Path**, and the
**Debug Keystore** (create one with):

```
keytool -genkeypair -v -keystore debug.keystore -storepass android -alias androiddebugkey \
  -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

## 2. First open (creates the import cache)

```
godot --headless --path . --import
```

## 3. Debug APK without AdMob (simplest, good for a first on-device test)

The shipped `export_presets.cfg` defines **"Android Debug"** (test ads) and **"Android Release"** (your real ads), both with Gradle build **off** until you install the AdMob plugin (then switch it ON).

```
mkdir -p build
godot --headless --path . --export-debug "Android Debug" build/BubbleBlastPro-debug.apk
adb install -r build/BubbleBlastPro-debug.apk
```

Or in the editor: *Project -> Export -> Android Debug -> Export Project* (untick "Export With Debug" only for release).
The game runs fully offline; ads report "unavailable" because the plugin is not installed (this is intentional,
see `docs/ADMOB_SETUP.md`).

If the preset is rejected, open *Project -> Export*, add an Android preset by hand, and set:
package name, *Architectures: arm64-v8a*, permissions *Internet*, *Access Network State*, *Vibrate*,
and under *Resources -> Filters to export non-resource files* add `data/*` (the level/config JSON files live there;
if you forget this the APK launches but every level reports an error).

## 4. Debug APK WITH AdMob (needs Gradle build)

1. *Project -> Install Android Build Template...* (creates `android/build`).
2. Install the AdMob plugin (see `docs/ADMOB_SETUP.md`) and enable it in *Project Settings -> Plugins*.
3. In the export preset switch **Use Gradle Build** to ON. Add the plugin's Android plugin in the preset's *Plugins* list.
4. Export as in step 3.

## 5. Release AAB for Google Play

1. Create a release keystore **once** and back it up somewhere safe (losing it means you can never update the app
   under the same key unless you use Play App Signing recovery):
   ```
   keytool -genkeypair -v -keystore release.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Duplicate the preset as **"Android Release"**: *Use Gradle Build* ON, *Export Format* **Android App Bundle**,
   *Architectures* arm64-v8a (+ armeabi-v7a if you want older phones), your own **package name**, **version code/name**.
3. Release signing, either in the preset (*Keystore -> Release*) or with environment variables:
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
   (Never commit keystores or passwords - `.gitignore` already excludes `*.keystore`/`*.jks`.)
4. Export: `godot --headless --path . --export-release "Android Release" build/BubbleBlastPro.aab`
5. Before uploading, switch AdMob to production IDs - see the release checklist in `docs/ADMOB_SETUP.md`.
6. Play Console: create the app, upload the AAB to an internal test track first, fill the content rating,
   target-audience (do **not** select children unless you implement the Families policies), Data-safety form,
   privacy-policy URL, and check Google's current target-API-level requirement for new apps/updates (it changes yearly).

## 6. Let GitHub build it for you
See `.github/workflows/build-android.yml` and `docs/URDU_SETUP_GUIDE.md` (Actions -> Build Android -> Run workflow -> download the APK artifact).

## 7. Verifying on a device

```
adb logcat -s godot            # script errors and the AdManager diagnostics
```
Use `docs/QA_CHECKLIST.md` for the manual pass.
