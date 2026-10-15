# Hamza ke liye Setup Guide (Roman Urdu)

Is guide se aap: (1) game ko Godot mein kholein, (2) ads lagayein, (3) GitHub par upload karein, (4) GitHub se APK banwayein.

> Zaroori sach: yeh code mere paas Godot nahi hone ki wajah se compile nahi hua. Pehli baar chalane par agar koi error aaye to **exact error text mujhe bhej dein**, main theek kar doonga.

## Step 1 - Godot 4.5 install karein
1. https://godotengine.org/download se **Godot 4.5** (Standard, .NET nahi) download karein.
2. Godot kholein -> **Import** -> project folder ka `project.godot` select karein.
3. F5 dabayein. Pehle "Loading" screen aayegi (5 second), phir menu.

## Step 2 - Pehla test (terminal, optional magar achha)
```
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```
Aakhir mein `0 failed` aana chahiye.

## Step 3 - AdMob plugin lagayein (ads ke liye zaroori)
1. https://github.com/poingstudios/godot-admob-plugin -> **Releases** se latest release download karein (ya Godot **AssetLib** mein "AdMob" search karein).
2. Uska `addons/admob` folder apne project ke `addons/` mein copy karein.
3. Godot: **Project -> Project Settings -> Plugins** -> **AdMob** ko Enable karein.
4. **Project -> Project Settings -> General -> Admob -> General -> Android**: **Enabled** tick karein aur **App ID** daalein:
   `ca-app-pub-3697668089255708~3506182429`
5. **Project -> Install Android Build Template** dabayein.
6. **Project -> Export** mein dono presets (*Android Debug*, *Android Release*) kholein aur **Use Gradle Build** ON karein.

Ad units pehle se project mein daale ja chuke hain (banner / interstitial / rewarded). Details: `docs/ADMOB_SETUP.md`.

## Step 4 - Ads kahan aayenge
* **Interstitial:** har **2 levels** ke baad (jab aap Next/Replay/Map dabayein).
* **Banner:** menu, level map, shop, daily reward aur **level khatam hone wali screen** par. Gameplay ke upar kabhi nahi.
* **Rewarded:** sirf optional buttons (double coins, continue, free coins) - pehle hi likha hota hai ke kya milega.

## Step 5 - GitHub par upload
1. GitHub par naya **private** repository banayein (e.g. `bubble-blast-pro`).
2. Project folder mein terminal kholein:
```
git init
git add .
git commit -m "Bubble Blast Pro"
git branch -M main
git remote add origin https://github.com/AAPKA-NAAM/bubble-blast-pro.git
git push -u origin main
```
3. Yaad rakhein: `addons/` aur `android/` folders bhi commit hon (plugin ke liye).

## Step 6 - GitHub se APK banwayein
1. GitHub repo -> **Actions** -> **Build Android** -> **Run workflow**.
2. 10-20 minute baad run ke neeche **Artifacts** mein `BubbleBlastPro-apk` download karein (zip mein 2 APK):
   * `BubbleBlastPro-debug.apk` - **test ads** (isse khoob test karein, ads par tap bhi kar sakte hain)
   * `BubbleBlastPro-release.apk` - **aap ke real ads**
3. Phone mein install karein (Settings mein "Unknown sources" allow karna parta hai).

### Release signing key (Play Store ke liye zaroori)
Bina key ke workflow aarzi (temporary) key bana leta hai: APK install ho jata hai magar Play Store par update nahi de sakte. Asli key banane ke liye:
```
keytool -genkeypair -v -keystore release.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 release.keystore
```
GitHub repo -> **Settings -> Secrets and variables -> Actions** mein 3 secrets: `ANDROID_KEYSTORE_BASE64` (upar wala base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`). **release.keystore file kabhi GitHub par na daalein aur kho na dein.**

## Step 7 - Publish se pehle
- [ ] `data/config/game_config.json` mein `privacy_policy_url` aur `support_email` asli daalein (privacy policy zaroori hai)
- [ ] Package name `com.hamza.bubbleblastpro` aap ka apna chahiye to `export_presets.cfg` mein badlein
- [ ] AdMob console -> **Privacy & messaging** -> GDPR message publish karein
- [ ] Play Console: app banayein, Data safety form mein "ads / Advertising ID" declare karein
- [ ] Apne **real ads par kabhi tap na karein** (account band ho sakta hai)

## Income ke baare mein
Ads se income ki koi guarantee nahi: yeh installs, mulk, ad fill aur policies par depend karti hai. Naye ad units ko chalne mein kuch ghante lag sakte hain, aur app ke Play Store par aane tak fill kam ho sakta hai.

## Kuch na chale to
| Masla | Hal |
|---|---|
| Godot mein script error | exact error text mujhe bhejein |
| Ads nahi aa rahe | Settings (debug build) mein `Ads:` line dekhein; plugin enable aur App ID check karein |
| App launch par crash | App ID Project Settings -> Admob mein galat/khali hai |
| GitHub Actions fail | failed step ka log copy karke bhejein |
