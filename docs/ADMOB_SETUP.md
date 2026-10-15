# AdMob setup (real IDs configured)

## Your AdMob app (already entered in the project)

| What | ID | Where it is used |
|---|---|---|
| App ID (`~`) | `ca-app-pub-3697668089255708~3506182429` | **Godot -> Project Settings -> Admob -> Android** (see step 4). The SDK reads it from there, **not** from `ads_config.json` |
| Banner `home_banner` | `ca-app-pub-3697668089255708/5944643503` | `data/config/ads_config.json` -> production.banner |
| Interstitial `game_end_interstitial` | `ca-app-pub-3697668089255708/7253855747` | production.interstitial |
| Rewarded `free_coins_rewarded` | `ca-app-pub-3697668089255708/2001529065` | production.rewarded |

The App ID has a `~`, ad units have a `/`. Never swap them (a wrong App ID crashes the app at launch).

## Which build uses which IDs (safety)
* **Debug builds always use Google's public TEST IDs**, even if you edit the JSON. Safe to tap.
* **Release builds use your REAL IDs** (`test_mode` is `false`). **Never tap your own live ads** (AdMob can suspend the account for invalid activity). Test with the debug build.
* If a production ID is missing/placeholder, the game turns ads off instead of using a wrong ID.

## Where ads appear (all configurable in `ads_config.json`)
| Ad | When |
|---|---|
| **Interstitial** | After every **2** finished levels (win or lose), at the moment you press Next / Replay / Try again / Level map. Min 45 s apart. Never during play. |
| **Banner** | Main menu, level map, shop, daily reward, and on the **level-complete / game-over screens** (the "after the game" banner). Never over the board. |
| **Rewarded** | Always optional buttons that state the reward first: *Watch a video: double coins (+N)*, *Watch a video: continue (+5 shots)*, Shop: *+50 coins (5 per day)*. Reward is paid only after the video completes, once. |

## The plugin (checked against its published docs)
* Plugin: **Poing Studios "Godot AdMob Plugin"** - <https://github.com/poingstudios/godot-admob-plugin>, docs: <https://poingstudios.github.io/godot-admob-plugin/latest/>
* The current docs require **Godot 4.5.0+**, Android min SDK 24. This project is set to Godot **4.5**.
* Pin and write down the exact plugin release you install (GitHub *Releases* page). I could read the docs but could not download or compile the plugin, so `ad_backend_poing.gd` is **docs-matched, not compile-tested**. The docs also mark the "latest" pages as experimental; if your release differs, Godot underlines the exact name to change. If the script fails to compile, the game falls back to "no ads" and still runs.
* Class names used (all appear in the plugin docs): `MobileAds`, `AdView`, `AdSize.BANNER`, `AdPosition.BOTTOM`, `AdListener`, `AdRequest`, `InterstitialAdLoader`/`InterstitialAdLoadCallback`/`InterstitialAd`, `RewardedAdLoader`/`RewardedAdLoadCallback`/`RewardedAd`, `FullScreenContentCallback`, `OnUserEarnedRewardListener`, `UserMessagingPlatform.consent_information.update()`, `load_consent_form()`, `ConsentForm.show()`.

## Install steps (do once, on your PC)
1. Install **Godot 4.5** (standard build) and open this project.
2. Get the plugin from its GitHub Releases page (or the Godot Asset Library, search "AdMob") and copy the `addons/admob` folder into the project.
3. *Project -> Project Settings -> Plugins* -> enable **AdMob** (it downloads its Android libraries).
4. *Project -> Project Settings -> General -> Admob -> General -> Android*: tick **Enabled** and paste the **App ID** `ca-app-pub-3697668089255708~3506182429`. (Leave iOS off.) Save.
5. *Project -> Install Android Build Template...* then in *Project -> Export* open each Android preset and set **Use Gradle Build = ON**.
6. Commit `project.godot`, `addons/` and `android/` to GitHub (see `docs/URDU_SETUP_GUIDE.md`).

## Consent (GDPR / UMP)
The game asks for consent before requesting ads and only requests ads when consent is obtained or not required.
In AdMob console -> **Privacy & messaging**, create the **GDPR message** (EEA/UK) and publish it, otherwise EEA users get no ads.

## What to expect from AdMob (important, honest)
* New ad units can take **up to a few hours** to start filling.
* Until the app is **published on Google Play and linked** in AdMob, fill is limited and revenue can be zero.
* Revenue is **not guaranteed**; it depends on installs, countries, ad fill and policy compliance.
* Policies: no accidental clicks (the game keeps ads away from buttons), no ads over gameplay, a privacy policy URL is required (set `privacy_policy_url` in `data/config/game_config.json`), declare ads / Advertising ID in Play Console -> Data safety.

## Troubleshooting
| Symptom | Fix |
|---|---|
| Settings -> `Ads: ads unavailable ...` | Plugin not installed / not enabled / not on Android / API name differs (open `ad_backend_poing.gd`) |
| App crashes on launch | App ID missing or wrong in *Project Settings -> Admob -> Android* |
| No consent form, no ads | UMP message not published in AdMob, or consent not obtained |
| Ads blank in release | New units still warming up; check AdMob "Ad serving" status; wait and retry |
| Interstitial never shows | Needs 2 finished levels and 45 s since the last one |
