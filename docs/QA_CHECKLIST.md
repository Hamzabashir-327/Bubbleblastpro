# QA checklist

Legend: **[x] verified here** (actually run in the build sandbox) - **[ ]** needs Godot / a device (not verifiable in the sandbox).

## Automated, verified in the sandbox
- [x] `python3 tools/test_rules.py` - 1,473 checks on the Python mirror of the rules (geometry, match, drop, ice, stone, lock, critter, bomb, lightning, rainbow, fireball, wall bounce, 200-case fuzz "nothing floats after a shot")
- [x] `python3 tools/validate_levels.py` - all 30 level files pass schema + connectivity, and a greedy bot (fresh seeds, no power-ups) wins every level in at least 8 of 10 trials (see the table in `docs/LEVEL_REPORT.md`; validated again after the descent rules)
- [x] `python3 tools/check_gdscript_refs.py` - every `Autoload.member` / `ClassName.member` reference resolves, scene -> script paths and `res://` resources exist, brackets balance, tab indentation
- [x] JSON configs and levels parse; generated PNG/WAV assets exist (art contact sheet inspected by eye)

## Automated, needs Godot (written, NOT yet run)
- [ ] `godot --headless --path . --import` finishes without errors
- [ ] `godot --headless --path . -s tests/run_tests.gd` prints `... 0 failed` (includes GDScript-vs-Python agreement on hundreds of shot scenarios and validation of all 30 levels with the real `LevelData`)

## Gameplay (manual, device or desktop)
- [ ] Aim guide follows the finger and shows wall bounces; releasing fires; a tap fires toward the tap
- [ ] Shot bounces off both walls and sticks to bubbles and the ceiling
- [ ] 3+ same colour pop with sound; unsupported bubbles fall; score and shots update
- [ ] The ceiling bar sinks smoothly after each shot (more after a miss); touching the red line = game over; "Danger!" hint near the line
- [ ] Level map: sandy road, marker above the current level, marker hops to the next level after a win, locked levels can't be opened
- [ ] "Handcrafted with love by Hamza" badge appears on the loading screen ONLY (not on the menu)
- [ ] Tap launcher swaps current/next
- [ ] Ice cracks then pops; stone stays; lock opens next to a pop; critter is rescued (Levels 5, 6, 8, 9)
- [ ] Each power: Rainbow, Bomb, Lightning, Fireball, Colour Switch, Time Freeze (timed level 12) - cooldown badge, per-level limit, inventory decreases only when used, tapping an armed power cancels it
- [ ] Out-of-stock power opens the buy popup; buying with too few coins is disabled
- [ ] Win: stars animate, coins added, Next/Replay/Map work; Lose: Retry/Map work; "Continue" works for shots, time and overflow
- [ ] Pause button, Android back (opens pause; closes pause), app to background -> pause popup, resume continues
- [ ] Rotate / resize window (desktop) - board re-centres, nothing breaks
- [ ] Popups block taps to the board (no accidental shot)
- [ ] Debug only: F1 wins, F2 fails, Settings -> Validate levels says "All 30 levels valid"

## Save and UI
- [ ] Coins, level progress/stars/best score, powers, settings persist after killing the app
- [ ] Corrupt save: edit `user://save.json` by hand -> game starts, restores `save.bak.json` or defaults
- [ ] Daily reward: claim once; second claim blocked until the next local day; set clock back -> "clock looks wrong"; skip a day -> streak resets
- [ ] UI fits 16:9, 20:9 and a tablet aspect; notch/gesture-bar safe areas respected; tap targets comfortable
- [ ] Menus never overlap the banner area

## AdMob (device with the plugin installed)
- [ ] Consent form appears on first launch in a test region; Settings shows *Ad privacy options* when required
- [ ] Test banner appears on main menu / level map / shop / daily reward, never in a level
- [ ] Test interstitial only after pressing Next/Replay/Retry/Map from a result popup, at the configured cadence (from level 4, every 3 breaks, >= 120 s)
- [ ] Rewarded: reward granted only after the video is completed; closing early gives a message and no reward; reward cannot be claimed twice
- [ ] Airplane mode: game fully playable, ad buttons disabled/absent, no crash
- [ ] No live ads clicked at any time

## Android
- [ ] Debug APK exports and installs; launches; icon is correct
- [ ] Audio, vibration, touch, back button and pause/resume behave
- [ ] Release AAB signed (`docs/ANDROID_BUILD.md`), internal-test upload accepted
- [ ] Privacy policy URL, Data-safety form and content rating completed
