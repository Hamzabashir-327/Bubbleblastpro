# Bubble Blast Pro - Mystic Worlds

An original, offline, portrait bubble-shooter for Android, built with **Godot 4.5 (GDScript)**.
30 hand-tuned levels on a jungle rope-bridge (mosaic-pattern boards + a slowly sinking ceiling), 6 power-ups, daily rewards, achievements, and Google AdMob (test IDs).

> ## Honest build status
> | Item | State |
> |---|---|
> | Source project (scenes, scripts, data, assets) | **Written** |
> | Game rules (`board_logic.gd`) | **Verified** through a line-by-line Python mirror: 1,473 rule checks pass (`tools/test_rules.py`) |
> | 30 levels | **Generated and bot-validated** (see `docs/LEVEL_REPORT.md`) |
> | GDScript compiles / scenes open in Godot | **NOT verified** - the build sandbox had no Godot binary |
> | Python-vs-GDScript agreement | Test harness written (`tests/run_tests.gd`), **not yet run** |
> | AdMob plugin integration | **Matched to the plugin's published docs, NOT compiled against the plugin** - see `docs/ADMOB_SETUP.md`. Your real AdMob IDs are configured (release builds only; debug builds always use test IDs) |
> | GitHub Actions workflow (`.github/workflows/build-android.yml`) | **Written, NOT run** |
> | Web preview (`tools/build_web_preview.py`) | JS rules verified against 280 vectors; page script simulated in Node over all 30 levels (0 errors); **not opened in a real browser by me** |
> | Debug APK | **NOT built.** No Godot, Android SDK or internet in the build sandbox. No APK exists. |
>
> Everything marked NOT verified needs about 30-60 minutes on a machine with Godot + Android SDK. Exact steps below.

## Quick start (desktop, to play and test)

1. Install **Godot 4.5 stable** (standard, not .NET): <https://godotengine.org/download>
2. Open Godot -> *Import* -> select `project.godot`. Let it import assets once (first open creates `.godot/`).
3. Press **F5**. The game starts at the splash screen. Mouse = touch.
4. In *Settings* (debug builds only) you get: *Unlock all*, *+1000 coins*, *Validate levels*.
   Press **F1** in a level to win it instantly, **F2** to fail it (debug builds only).
5. Run the automated tests (optional but recommended - this is the first real GDScript compile check):
   ```
   godot --headless --path . --import
   godot --headless --path . -s tests/run_tests.gd
   ```
   Expected last line: `N checks, 0 failed` and exit code 0.

If Godot reports a script error, send me the exact message - the code was written without a compiler,
so a small typo is possible. Everything else in the project is data-driven and will keep working.

## Build an Android APK

See **`docs/URDU_SETUP_GUIDE.md`** (Roman Urdu, start here), **`docs/ANDROID_BUILD.md`** (debug APK, release AAB, signing) and the GitHub workflow. AdMob needs the extra plugin step in
**`docs/ADMOB_SETUP.md`**. Without the plugin the game builds and runs normally, simply with ads unavailable.

## Python tools (no Godot needed)

```
pip install pillow numpy                      # only for asset generation
python3 tools/test_rules.py                   # 1,473 rule checks on the Python mirror
python3 tools/validate_levels.py              # schema + bot playthroughs of all 30 levels
python3 tools/check_gdscript_refs.py          # cross-file reference sanity check
python3 tools/generate_levels.py              # (re)generate levels + docs/LEVEL_REPORT.md (slow on one CPU)
python3 tools/make_test_vectors.py            # cases for tests/run_tests.gd
python3 tools/build_web_preview.py out.html   # playable single-file web preview (JS port of the rules)
python3 tools/generate_assets.py              # base art, procedurally
python3 tools/generate_assets_v2.py           # candy balls, specials, badge, base nodes (run after the line above)
python3 tools/generate_assets_v3.py           # JUNGLE BRIDGE theme: foliage worlds, chunky candy logo + titles, nodes, icons (run last)
python3 tools/generate_icon.py                # app icon (run after generate_assets.py)
python3 tools/generate_audio.py               # all sound + music, synthesised
```

## Project layout

```
project.godot            autoloads: SaveManager, GameManager, LevelManager, AudioManager,
                         CoinManager, RewardManager, AdManager
scenes/                  main/ (splash, main_menu)  world/level_map  game/game  ui/ (shop, daily_reward, settings, achievements)
scripts/core/            game_manager, save_manager, level_manager, level_data, audio_manager
scripts/gameplay/        board_logic.gd (pure rules)  game.gd (input, flight, effects, HUD, flow)
scripts/powers/          power_manager.gd (defs, use limits, cooldowns)
scripts/economy/         coin_manager, reward_manager (daily reward, achievements)
scripts/ads/             ad_manager (frequency caps, consent, rewards) + backends (poing plugin / no-ads stub)
scripts/ui/              ui_kit, screen base, modal_panel, one script per menu screen
data/levels/             level_001..030.json          data/config/  game_config.json, ads_config.json
tools/                   generators, Python mirror + bot, validators
tests/                   run_tests.gd + vectors
docs/                    ADMOB_SETUP, ANDROID_BUILD, QA_CHECKLIST, GAME_DESIGN, LEVEL_REPORT, ATTRIBUTIONS
```

Why it differs from the spec's sample tree: bubbles are drawn directly in one `_draw()` pass instead of one scene
per bubble (much cheaper on low-end phones), and all rules sit in a single node-free class so they can be
unit-tested. `bubble.tscn`, `shooter.tscn`, `aiming.gd`, `collision_system.gd`, `match_finder.gd` and the
individual power scripts therefore do not exist; their jobs are `board_logic.gd` (tracing, collision, matching,
power effects) and `game.gd` (aiming, shooter). No empty placeholder files were created.

## Things you must do before publishing

1. Replace `privacy_policy_url` and `support_email` in `data/config/game_config.json` (placeholders on purpose).
2. Change the package name `com.hamza.bubbleblastpro` in the export presets if you want a different one.
3. Install the AdMob plugin and set the App ID in Project Settings (`docs/ADMOB_SETUP.md`). Your ad unit IDs are already in `ads_config.json`.
4. Create and keep safe your release keystore (`docs/ANDROID_BUILD.md`).
5. Complete the Play Console Data-safety form (`docs/ADMOB_SETUP.md`, section "Privacy").

Revenue is not guaranteed; it depends on real usage, geography, ad fill and policy compliance.
