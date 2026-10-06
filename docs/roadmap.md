# Card Masters — Prototype Roadmap

Goal of the prototype: **find out whether the game is fun**, as cheaply as possible. Placeholder art, local hotseat play, and bots that can simulate thousands of matches to sanity-check the numbers. Online play and real art come only after the core loop is proven.

Engine: **Godot 4.x, GDScript.** Rules are specified in [`design.md`](design.md).

Each phase ends with something runnable. Tick boxes as work lands.

---

## Phase 0 — Project setup

- [x] Create the Godot 4.x project at the repo root (`project.godot`), 2D, GDScript only.
- [x] Folder layout as described in `CLAUDE.md` (`core/`, `cards/`, `ui/`, `ai/`, `tests/`).
- [x] Add the **GUT** test framework (addons/gut) and a headless test command.
- [x] Empty main scene that boots without errors.

**Done when:** the project opens in the editor and `godot --headless` runs an empty test suite.

---

## Phase 1 — Rules core (headless, no UI)

Pure game logic that can play a whole match in code. Every rule here gets unit tests.

- [x] `GameState`, `PlayerState` (HP 100, type, Heat, hand, alive/eliminated).
- [x] Type chart and multipliers (Grass → Water → Fire → Grass, Normal neutral; 2x / 0.5x / 1x).
- [x] Shared deck: build from card data with copies by rarity, shuffle with a **seeded RNG**, reshuffle discard pile when empty.
- [x] Dealing: 7-card starting hand; draw step of up to 3 sequential draws plus 1 optional discard; hand cap 10 (discard before drawing at the cap).
- [x] Turn loop: sequential turns, starting seat rotates each round, up to 1 slot-1 card + 1 slot-2 card, skip = +1 Heat.
- [x] Heat formula: Base × mode (collective 1x, targeted 2x), +1 after multiplier for effects with direct damage.
- [x] Joker (round end): Normal type, damage 10 + 10 per round, hits highest Heat; ties hit all tied players for full damage; Heat resets to 0 only on an actual hit.
- [x] Elimination; win when one player remains; **draw** when the last two die to the same hit.
- [x] Event log of everything that happens (used later by UI, bots and debugging).

**Done when:** a test can script a full match from seed to winner using only plain attacks.

---

## Phase 2 — Card system

Data-driven cards, implemented family by family in this order (each family playable before starting the next):

- [x] Card data format (custom `Resource` per card: id, name, family, slot, type, base Heat, rarity, mode lock, effect params).
- [x] **Attacks:** Ember, Thornlash, Tidal Crash, Wildfire (collective only), Cataclysm (targeted only).
- [x] **Damage over time:** Venom (stacking poison), Scorch (stacking burn until type change), Rot (halves the next resist). Round end: traps → burns → poison → Joker.
- [x] **Type manipulation:** Type Swap, Convert, Rooted, Shed Skin.
- [x] **Joker modifiers** with the three slots (targeting replaces, pattern replaces, effects stack): Cone, Double Tap, Stand Down, Lock-On, Wild Card, Invert, Ignite / Flood / Overgrow, Venom Fang, Overcharge.
- [x] **Trigger / event system** for traps (hidden effect, visible placement, owner revealed and Heat applied on fire, before the Joker hit).
- [x] **Traps:** Poison to Healing, Joker Deflect, Backfire, Tripwire, Type Snare, Grudge, Wellspring.
- [x] **Hand and turn disruption:** Pickpocket, Silence, Exposed, Dry Well.
- [x] **Heat manipulation:** Scapegoat, Spotlight, Flashpoint.

**Done when:** every card in `design.md` §8 is implemented with at least one test.

---

## Phase 3 — Bots and simulation

Cheap AI players so the numbers can be tested without humans.

- [ ] `RandomBot`: plays any legal move.
- [ ] `GreedyBot`: simple heuristics (avoid being highest Heat, exploit type advantages, use collective cards when resisted).
- [ ] Headless simulation runner: N matches with given seeds/player counts → CSV/JSON summary.
- [ ] Report: match length in rounds, elimination round per seat, win rate per seat (checks rotation fairness), Heat distribution, how often the Joker kills vs cards, draw rate, card play frequency.

**Done when:** one command simulates 1,000 matches and prints the summary.

---

## Phase 4 — Hotseat playable prototype

Placeholder-art UI on top of the rules core; 2–4 humans on one screen (bots can fill seats).

- [ ] Table layout: player seats with HP, type (colour-coded terrain placeholder), Drama (Heat) meter.
- [ ] Hand view with pass-the-device screen between turns (hand hidden from others).
- [ ] Two play slots, mode picker (collective / targeted), target picker.
- [ ] Collective pool in the middle; face-down trap markers showing where traps sit.
- [ ] Joker (host) display: current damage, type, modifier slots, who it will hit.
- [ ] 30-second turn timer (timeout = skip).
- [ ] Event log panel; end-of-match screen.

**Done when:** four people can play a full match on one computer.

---

## Phase 5 — Playtest and balance

- [ ] Run hotseat sessions; collect notes in `docs/playtests/`.
- [ ] Tune with simulation + playtests: Joker +10/round, HP 100, card damage, Base Heat values, copy counts.
- [ ] Watch list from the design doc: Joker type-changer count, uncommon share of the deck, "Stand Down" chaining, last-seat advantage, Normal-type camping, turtling.
- [ ] Prune cards that are unfun or dominant.

**Done when:** matches land around 20 minutes / ~10 rounds and no single strategy dominates.

---

## Phase 6 — Online multiplayer

- [ ] Host-authoritative networking with Godot high-level multiplayer (rules core already deterministic and UI-free).
- [ ] Lobby, join by code, reconnect, leave without penalty, spectate as ghost.
- [ ] Hidden information stays server-side (hands, trap effects).

---

## Phase 7 — Theme and presentation

- [ ] Cartoon fantasy art direction (original art, Adventure Time–inspired feel, not copied).
- [ ] Types as terrain on each player's side; hologram-style card effects.
- [ ] Guillame El Cid (placeholder name), the drama-loving host: animations, voice lines.
- [ ] Audio, juice, onboarding/tutorial.

---

## Later (parked — see `design.md` §9)

Heroes with passives, roguelike elements, more types, hidden typing, personal decks, purchasable cosmetics/artifacts (never pay-to-win), final name.
