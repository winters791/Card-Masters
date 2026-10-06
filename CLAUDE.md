# CLAUDE.md — Card Masters

Card Masters (working title) is a 2–4 player digital card game where **every card is a weapon**: no self-buffs, last player standing wins, and a drama-loving game host (the Joker) punishes whoever has the most Heat (called "Drama" in-game). This repo is the **Godot prototype**.

The developer is **Uday** (call him Uday). He's a CS student building this as a side project.

## Source of truth

- **`docs/design.md`** — the game rules. Implement what it says. If code and doc disagree, the doc wins unless Uday says otherwise.
- **`docs/roadmap.md`** — phases and checklists. Work top to bottom; tick boxes as work lands.
- When Uday makes a new design decision in conversation, **update `docs/design.md` in the same change** (and the roadmap if scope moved). Never let the doc go stale.
- Parked ideas (heroes, roguelike, personal decks, hidden typing, more types…) live in `design.md` §9. Don't build them unless asked.

## How to work with Uday on design

When a rule is missing, ambiguous or seems broken, **don't silently invent it**. Use the workflow this design was built with:

1. Pose the **problem** (what breaks, with a concrete example).
2. Let Uday propose a fix.
3. Probe it with questions, or **pass** it. If it fails, or if a better idea fits the gameplay more neatly, offer your own suggestion.

For small gaps that block coding, pick the simplest reading, mark it in code with `# RULE-ASSUMPTION:` and list it in your reply so Uday can confirm. Design pillars to check ideas against: no self-buffs, you can't turtle, politics is the real game, escalation via the Joker, simple (a tad more complex than UNO No Mercy), never pay-to-win.

## Tech stack

- **Godot 4.7.x, GDScript only** (no C#). Statically typed GDScript (`var hp: int`, typed function signatures) everywhere; the editor warns on untyped declarations (headless runs don't print GDScript warnings, so check new code yourself).
- **GUT 9.7.1** (Godot Unit Test, the release for Godot 4.7) for tests, vendored in `addons/gut/`. Test files are `tests/**/test_*.gd` extending `GutTest` (see `.gutconfig.json`).
- 2D only. Placeholder art (coloured rects/labels) until Phase 7.

## Architecture

Keep the **rules core completely separate from presentation**. The core must run headless, so it can be unit-tested, simulated by bots thousands of times, and later run on a host for online play.

```
core/      # pure rules: GameState, PlayerState, TypeChart, Heat, Deck, TurnController, Joker, events
cards/     # card Resource class + one .tres per card + effect implementations
ai/        # bots (RandomBot, GreedyBot) and the headless simulation runner
ui/        # scenes and scripts that only READ state and SEND player intents to core
tests/     # GUT tests mirroring core/ and cards/
docs/      # design.md, roadmap.md, playtests/
```

Conventions:

- **Core classes extend `RefCounted`/`Resource`, never `Node`.** No scene tree, no `get_tree()`, no timers, no input in `core/`.
- **Determinism:** all randomness goes through one `RandomNumberGenerator` owned by `GameState`, seeded at match start. Same seed + same moves = same match.
- **Intents in, events out.** UI/bots submit actions (`PlayCardIntent`, `SkipIntent`…); core validates, applies, and emits a typed event log (`DamageDealt`, `HeatChanged`, `TrapFired`, `JokerAttacked`, `PlayerEliminated`…). UI animates from events; it never mutates state.
- **Data-driven cards:** each card is a `.tres` of a `CardData` resource (id, name, family, slot, element type, base_heat, rarity, mode_lock, effect params). Effects live in small scripts keyed by family/effect id; avoid one giant `match` over card names.
- **Traps use the event system:** a trap subscribes to an event pattern and fires when matched. Placement is public, effect is hidden until it fires.
- **Hidden information** (hands, trap effects) is filtered per viewer by a `get_view_for(player_id)` function, so hotseat and later networking share one code path.
- Concrete events are inner classes of `GameEvents` (`GameEvents.DamageDealt`), intents of `Intents` (`Intents.PlayCard`); `TurnController.submit(intent)` returns `""` or the rejection reason.
- Magic numbers (HP 100, Joker +10, hand sizes, timer 30s, multipliers) live in one `core/config.gd`, not scattered through code. Balancing will change them.

## Commands

```bash
# First time on a fresh clone (no .godot/ yet): import so class_names and GUT resolve
godot --headless --import --path .

# Run all tests headless (exit code 0 = all passed)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Run one test file / one test
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_project_setup.gd -gunit_test_name=test_main_scene_instantiates -gexit

# Parse-check a single script (non-zero exit on syntax/type errors)
godot --headless --path . --check-only -s res://core/some_script.gd

# Run the game
godot --path .
```

After a GUT run, Godot may print `ObjectDB instances were leaked at exit` followed by `resources still in use`. That's GUT's own scenes and scripts not being freed at exit under some script load orders (Godot 4.7.2 + GUT 9.7.1), not a game leak: the same matches run outside GUT exit clean. Judge a run by its summary and exit code.

In Claude Code cloud sessions, `.claude/hooks/session-start.sh` installs the pinned Godot binary (`godot` on PATH) and runs the import step automatically. When upgrading Godot, bump `GODOT_VERSION` there, `config/features` in `project.godot`, and GUT to the matching release.

Run the tests before every commit. Add a test for every rule and every card.

## Rule gaps to confirm with Uday before implementing

These aren't settled in `design.md` yet. Raise them when you reach the relevant roadmap item:

1. **Joker modifier duration:** slots imply modifiers persist until replaced, but some cards say "this round" (Stand Down, Wild Card, Overcharge). Which modifiers persist?
2. **Ties inside modifiers:** Cone hits the "top 3 Heat players" and Spotlight hits the "lowest-Heat player" — what happens on ties?
3. **Seat-based effects with eliminated players** (e.g. Joker Deflect "2 seats anticlockwise"): skip eliminated seats?
4. **Collective pool persistence:** current assumption is that collective cards resolve immediately (hit everyone once) and only traps remain in the pool. Confirm.
5. **Mode lock for non-damage effects:** which effects make sense collectively (e.g. Type Swap obviously can't)? Define which cards are targeted-only.

## Git

- Small, focused commits with clear messages. Keep `main` runnable.
- Don't commit `.godot/` or exports (see `.gitignore`).
