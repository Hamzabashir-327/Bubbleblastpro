# Game design reference

## Board and shooting
* Hex grid, 10 columns (even rows) / 9 columns (odd rows, shifted half a bubble). Bubble radius 34 px on a 720-wide design canvas
  (`stretch: canvas_items`, aspect `expand`, so taller/wider phones get extra space, never distortion).
* Drag to aim, release to shoot (a tap shoots toward the tap point). Minimum angle 12 degrees above horizontal.
  The aim guide shows the exact path including wall bounces and a ring on the cell the bubble will land in.
  The guide uses the **same** `trace_shot()` the real shot uses, so what you see is what happens.
* Tap the launcher to swap current/next bubble. Touches on the HUD, or while a popup is open, never fire.
* Shot tracing marches in 17 px steps; collision when centres are closer than 61.2 px; landing = nearest empty attachable cell.
* The queue only ever hands out colours that still exist (and can be matched) on the board, so a level is never
  lost because the game dealt an unusable colour.

## Look and layout (Jungle Bridge theme)
* Bubbles sit on a wooden rope-bridge deck over a jungle canopy (3 worlds: green jungle, autumn canopy, glowing forest). Vivid solid candy balls, chunky white/purple-outlined lettering for the logo and titles.
* HUD like the reference shooter: menu button, star progress bar (fills with score, stars light up at the 3 thresholds), score; below the board: rows-left badge, the ball in the launcher, swap arrows and the next ball; power-ups in a dock at the bottom. The aim line is dotted in the colour of the ball you are about to shoot.
* Level boards from level 4 mostly use mosaic patterns (diamond, stripes, zigzag, chevron) like the reference art.
* Level select is a winding wooden bridge over the jungle; the marker hops to the next level after a win.

## Rules v2: a slowly sinking ceiling
* Levels start with only 29-57 bubbles (3-7 rows). After **every shot** the whole ceiling sinks a little (`descent.shot` px, 4-20 px depending on the level) and sinks **more after a shot that popped nothing** (`descent.miss` px). The bubbles slide down smoothly; when the lowest bubble touches the red line it is game over. Clear every coloured bubble to win.
* The sink speed is tuned per level with a bot (`tools/generate_levels.py`): later levels sink faster. Pops that clear lots of bubbles buy you time because there is less to push down.
* `shots` in a level file is the **par** for the end bonus, not a limit.
* Danger feedback: the field glows red and the player gets a "Danger!" hint when less than ~150 px remain.
* Continue (free in the web preview; coins or a rewarded video in the Android game): lifts the ceiling back up by 3 rows and removes the 3 lowest rows.

## Rules
| Thing | Behaviour |
|---|---|
| Match | 3+ connected same-colour bubbles pop |
| Unsupported | anything not connected to the ceiling falls (+20 each) |
| Ice (frost shell) | a match including it cracks the shell instead of popping it; the bubble stays and pops on the next match |
| Stone | never matches, never pops from matches; falls only if cut loose, or destroyed by Bomb/Fireball |
| Locked | cannot match until any neighbour pops (the lock opens) |
| Critter (rescue) | freed (+100) when a neighbour pops or it falls |
| Score | pop 10, dropped bubble 20, rescue 100, combo multiplier +0.5 per consecutive scoring shot (cap x4), +50 per shot under the level's **par** on a win |
| Stars | 1 = win, 2 = score >= `star_scores[0]`, 3 = score >= `star_scores[1]` (bot-calibrated per level) |
| Lose | a bubble reaches the red danger line, the timer hits 0 (timed levels), or nothing is left that can finish the goal. There is **no shot limit** any more |
| Objectives | `clear` (all coloured bubbles), `score` (reach a target), `rescue` (free N critters) |

## Power-ups (never required to finish a level)
| Power | Effect | Limit per level | Cooldown | Price |
|---|---|---|---|---|
| Rainbow Orb | next bubble becomes the neighbouring colour that makes the biggest match | 3 | 2 shots | 120 |
| Nova Bomb | removes all bubbles within 2 cells of the landing cell (stones too) | 2 | 3 shots | 150 |
| Lightning Chain | removes the 8 nearest bubbles chained from the impact (not stone) | 2 | 3 shots | 150 |
| Fireball | passes through up to 6 bubbles along its path, bouncing off walls (stones too) | 2 | 3 shots | 180 |
| Colour Switch | changes the current bubble to the next colour present (free action) | 4 | - | 60 |
| Time Freeze | pauses the level timer for 10 s (timed levels only; not consumed elsewhere) | 2 | - | 100 |

Numbers live in `data/config/game_config.json`. Players start with 1 of each (2 Colour Switch), earn coins from
levels (15 + 10 per star, +20 first clear), achievements and the daily reward, and can optionally watch a video for +50 coins (5/day).
A shot-power is spent only when fired; tapping it again before shooting cancels it with no cost.

## Levels
`data/levels/level_NNN.json` (schema validated by `LevelData`, see `scripts/core/level_data.gd`):
```json
{ "version": 2, "id": 1, "name": "First Pop", "world": 1, "boss": false, "colors": 3,
  "shots": 6, "time_limit": 0, "descent": {"shot": 4.1, "miss": 9.3},
  "objective": {"type": "clear"}, "star_scores": [650, 950],
  "tip": "...", "rows": ["0120120120", "012012012"] }
```
Row symbols: `.` empty, `0-5` colour, `a-f` ice, `A-F` locked, `#` stone, `*` critter.
Adding level 31+: drop `level_031.json` in the folder and raise `level_count` in `game_config.json`.
`tools/generate_levels.py` creates layouts, then tunes shots/targets/time with a greedy bot (no power-ups);
on fresh seeds (tools/validate_levels.py, 10 trials each) the greedy bot won every level at least 7 times out of 10 with the shipped shot cap (level 13 was raised to 38 shots after a 7/10 run). A human who aims and uses power-ups is far stronger than this bot, so levels are comfortably winnable; `docs/LEVEL_REPORT.md` has the per-level tuning data.
A bad file never crashes the game: the player gets a "Level could not be loaded" popup with a button back to the map.

## Intentional design decisions / limits
* Time Freeze only pauses the level timer (the ceiling sinks per shot, not per second, so it never punishes thinking time).
* "Boss" levels (10, 20, 30) are larger mixed-obstacle puzzles, not a separate mechanic.
* Cosmetic skins / bubble themes: not implemented (spec: "if time allows").
* UI text is in code strings (English). To localise later, wrap them in `tr()` and add a translation CSV.
