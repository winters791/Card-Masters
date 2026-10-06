# Card Masters — Design Doc

*Working title: Card Masters · Status: core rules, first card batch and theme direction done · Last updated: 6 Oct 2026 (draw step, rounding, seat rotation, draws)*

---

## 1. Vision

A 2–4 player digital card game where **every card is a weapon**. There are no self-buffs: you survive by attacking strategically, shifting your type, and setting traps. The last player standing wins.

**Pillars**

- **No self-buffs.** Defense comes only from type changes and traps. Buffs (rare) can only be used on others.
- **You can't turtle.** Your hand pushes you to attack, so every turn you make an enemy.
- **Politics is the real game.** Who to provoke, who to leave alone, and how to survive once everyone hates you.
- **Escalation.** A shared threat in the middle of the table, the Joker, makes the game high-stakes after the midpoint.
- **Simple, but a tad more complex than UNO No Mercy.** New mechanics must earn their complexity.

### Theme

Cartoon fantasy in the spirit of Adventure Time: a bright, hand-drawn tabletop game where cards project glowing holograms onto an ordinary table. Inspiration only; all creatures, terrains and visuals are original.

- **Types as terrain:** each player's side of the table shows their type. Grass sprouts a meadow, Water floods into a swamp, Fire cracks into lava, Normal stays plain wood.
- **The collective pool** is the middle of the table, where effects project up for everyone to see.
- **The Joker is Guillame El Cid** (placeholder name), **a mischievous game host** in the style of a gleeful game-show presenter who loves drama. At the end of every round it singles out the most exciting player (highest Heat), it gets hungrier for a show each round, and it can be bribed, heckled or distracted with Joker cards. A Joker hit resets your Heat because you've had your moment.
- **Elimination** means the host kicks you off the table.

---

## 2. Players and types

- **Players:** 2–4. **Starting HP:** 100 (starting point for playtesting).
- **Win condition:** last player alive.
- Each player has **one type**, always visible to everyone. **Everyone starts as Normal.**

### Type chart

Grass → Water → Fire → Grass (each beats the next), plus **Normal**, which is strong and weak against nothing.

| Attacker ↓ / Defender → | Grass | Water | Fire | Normal |
|---|---|---|---|---|
| **Grass** | 1x | **2x** | 0.5x | 1x |
| **Water** | 0.5x | 1x | **2x** | 1x |
| **Fire** | **2x** | 0.5x | 1x | 1x |
| **Normal** | 1x | 1x | 1x | 1x |

- **Strong:** 2x · **Resisted:** 0.5x · **Same type / neutral:** 1x
- **Rounding:** fractional damage rounds down (15 at 0.5x = 7).
- Every hit has a type: card hits are labelled with their type, and Joker hits use the Joker's current type.
- Players change type only through effect cards (e.g. swapping types with another player), so changing type always costs Heat.

---

## 3. Turn structure

- **Sequential turns.** The **starting seat rotates every round** (seat 1 starts round 1, seat 2 starts round 2, …). Rotation follows the original seat numbers: if the scheduled seat is eliminated, the next living seat clockwise starts instead (so a seat can occasionally start two rounds in a row).
- **Turn timer:** 30 seconds. Running out of time **ends your turn**; cards drawn so far stay in your hand. It counts as a **skip** only if you haven't played a card.
- **Per turn, play up to 2 cards:** one from each slot (below).
- **Skipping is allowed**, but costs Heat (see §5) and forgoes setting traps or changing type.

### Card slots

| Slot | Card kinds | Notes |
|---|---|---|
| Slot 1 | Trap **or** Joker modifier | Trap Heat lands later; Joker Heat lands now |
| Slot 2 | Attack **or** Effect | **Attack** = pure typed damage. **Effect** = manipulation (type changes, type swaps, debuffs); **+1 Heat** if it also deals direct damage |

- Every turn is a statement of intent: **trap + effect** is a quiet setup turn (Heat deferred), **Joker + attack** is an aggressive turn (Heat now).
- Every effect harms someone in some way. Healing exists only indirectly (e.g. through traps).

### Hand

- **Starting hand:** 7 cards.
- **Draw step (start of every turn, including skips):** draw **up to 3 cards, one at a time**; you can stop at any point, even before drawing any. You may also **discard 1 card from your hand** (any card, drawn this turn or older) at any point during the step. Discarding is optional, so a turn can net up to +3 cards.
- **Draw, then play:** playing your first card ends the draw step.
- **Hand cap:** 10. At 10 cards you **can't draw until you discard**. With one discard per turn, a full hand gets at most one new card per turn.
- Discarded cards go face up to the shared discard pile (they do **not** go into any pool).

### Decks

- **One shared deck** for the whole table. Simplest rules, perfectly fair, easy to balance, and card counting feeds the politics.
- **Same deck at every player count.** No scaling.
- **When the deck runs out,** reshuffle the discard pile.
- **Copies by rarity,** with rarity set by Base Heat. A full 4-player match draws about 150 cards, so the deck reshuffles roughly once near the end.

| Rarity | Rule | Cards | Copies each | Total |
|---|---|---|---|---|
| Common | Base 1 | 11 | 4 | 44 |
| Uncommon | Base 2 | 22 | 3 | 66 |
| Rare | Base 3 (Cone, Double Tap, Overcharge) | 3 | 2 | 6 |
| Legendary | Hand-picked (Cataclysm) | 1 | 1 | 1 |
| **Total** | | **37** | | **117** |

*Watch in playtesting:* Ignite / Flood / Overgrow give 9 Joker type-changers in the deck, and uncommons make up more than half of it. With up to 3 draws a turn, card flow may be faster than the ~150-card estimate.

- **No pay-to-win.** Anything purchasable is **cosmetic** or a **sidegrade** (different, not stronger), such as card art, terrain skins and host voice packs.

---

## 4. Pools and traps

### Pools

- **Collective pool:** effects hit **every** player, including the one who played it. Gets stronger as your type advantages line up with what's in the pool.
- **Targeted (opponent) pool:** effects hit **one** chosen player.
- **The player picks the mode** when playing a card. A few cards are printed as locked to one mode (e.g. Wildfire, Cataclysm).

### Traps

- Everyone can see **that** a trap was placed and **where** (on a player or in the collective pool), but **not what it does**.
- A trap's effect is revealed only when its condition is met.
- **When a trap fires, everyone learns who placed it.**
- Collective traps feel "safe" early (they hurt no one until triggered); personal traps carry social weight from the start.
- Collective traps can be used to protect yourself, since you can't target yourself with cards (e.g. a Joker-deflect trap).

---

## 5. Heat

Heat (called **Drama** in-game) is a **visible meter** on each player. It works as the game's cost system: aggression draws the Joker's attention.

### Formula

**Heat = printed Base Heat × mode**

| Base Heat | Card power |
|---|---|
| 1 | Weak / utility (small damage, minor debuffs) |
| 2 | Solid (standard attacks, most Joker modifiers) |
| 3 | Big swings (heavy damage, cone, double attack) |

| Mode | Multiplier |
|---|---|
| Collective | 1x |
| Targeted | 2x |

- **Joker modifier cards:** add Heat; count as collective (1x).
- **Effects that also deal direct damage:** +1 Heat, added **after** the targeted 2x (a Base 2 targeted damage effect = 5).
- **Skip / timeout:** +1 flat.
- **Traps:** same formula, but the Heat lands **when the trap fires**. No extra "betrayal tax"; the delay is the tradeoff.

### Rules

- The Joker attacks the **player with the most Heat**.
- **Ties:** if several players are tied for the most Heat, the Joker hits **all of them for full damage** (no splitting). This includes everyone skipping in round 1.
- **Heat resets to 0 only when you're actually hit by the Joker.** Dodging or deflecting does **not** reset it.
- **Order:** Heat from a trap firing is applied **before** the Joker's hit.
- Dogpiling limits itself: everyone ganging up on the leader gets hot, and the Joker picks one of them.
- **Defense is never free.** Every type change is an effect and costs Heat, so a hot player on a bad type gets hotter by escaping it. This death spiral is intended: the only release is taking a Joker hit, which becomes fatal late in the game.

### Examples

| Card | Base | Mode | Heat |
|---|---|---|---|
| Small poison on one player | 1 | targeted | 2 |
| 40-damage attack on one player | 2 | targeted | 4 |
| Firestorm into the collective pool | 2 | collective | 2 |
| Joker: cone attack | 3 | collective | 3 |
| Skip | — | — | 1 |

---

## 6. The Joker (escalation)

The Joker is the game's centerpiece and escalation mechanic: a shared, indestructible threat that everyone fights to control.

- **On the field from the start.** Starts as **Normal** type.
- **Damage:** 10 in round 1, **+10 every round**. Eventually one hit kills whoever receives it.
- **Attacks at the end of every round**, targeting the highest-Heat player.
- **Indestructible.**

### Modifiers

Players change the Joker's behaviour with Joker cards. Examples:

- Attack twice at round end
- Skip its attack
- Cone attack (hits 3 players)
- Apply poison
- Lock onto the current target
- Random target (ignores Heat)
- Invert (targets the **lowest**-Heat player, an anti-turtle card)
- Change the Joker's type (a precision weapon: Heat picks *who*, type decides *how hard*)

### Modifier slots (proposed)

| Slot | Rule | Examples |
|---|---|---|
| Targeting | One at a time; new replaces old | Lock, random, invert |
| Pattern | One at a time; new replaces old | Single, cone, double, skip |
| Effects | Stack | Poison, burn |

---

## 7. Elimination and match length

- **Elimination is final.** If all remaining players die to the same hit (one card or one Joker attack), the game is a **draw**.
- Eliminated players can stay as **ghosts to spectate**, or leave without losing any rewards. Nobody should feel pushed to stay in a game they're no longer playing.
- **Target match length:** ~20 minutes.

### Pacing (starting point for playtesting)

- ~30-second turns → ~2 minutes per round with 4 players → **~10 rounds** per match (rounds speed up as players drop out).
- **Round 5 is the danger zone:** the Joker deals 50, or 100 at 2x, which is lethal against the wrong type.
- **Round 10:** the Joker one-shots anyone at neutral.
- **Card damage:** mostly 10–30. Big cards (~40) are rare, top-tier and 3 Base Heat.

---

## 8. Card list (first batch)

A first batch across seven families; everything stays in until playtesting prunes it. **Base** is the printed Heat before the collective 1x / targeted 2x multiplier. The player chooses collective or targeted unless a card is locked to one mode.

### Attacks (slot 2): pure typed damage

| Card | Type | Base | Effect |
|---|---|---|---|
| Ember | Fire | 1 | 10 damage |
| Thornlash | Grass | 2 | 20 damage |
| Tidal Crash | Water | 2 | 20 damage |
| Wildfire | Fire | 1 | 15 damage, **collective only**. A cheap way to flood the pool |
| Cataclysm | Normal | 3 | 40 damage, **targeted only**. Rare |

### Damage over time (slot 2, effects)

| Card | Base | Effect |
|---|---|---|
| Venom | 1 | Poison: 5 damage per round for 3 rounds. Stacks |
| Scorch | 1 | Burn: 10 per round until the target changes type |
| Rot | 2 | Halves the next type advantage the target gets |

### Type manipulation (slot 2, effects)

| Card | Base | Effect |
|---|---|---|
| Type Swap | 2 | Swap your type with a target's |
| Convert | 2 | Set a target's type to one of your choice |
| Rooted | 2 | Target can't change type for 1 round |
| Shed Skin | 1 | Change your own type and deal 10 damage to a target (+1 for direct damage) |

### Hand and turn disruption (slot 2, effects)

| Card | Base | Effect |
|---|---|---|
| Pickpocket | 1 | Target discards 2 random cards |
| Silence | 2 | Target can only play 1 card next turn |
| Exposed | 1 | Target's hand is shown to everyone for 1 round |
| Dry Well | 1 | On their next turn the target can't discard: they may still draw up to 3 (or stop early) but keep every card they draw, and with a full hand they can't draw at all |

### Heat manipulation (slot 2, effects)

Guardrail: these always cost you more Heat than they give.

| Card | Base | Effect |
|---|---|---|
| Scapegoat | 2 | Target gains +3 Heat; you pay 4 (targeted) |
| Spotlight | 2 | Collective: the lowest-Heat player gains +3 |
| Flashpoint | 2 | Collective: everyone at 6+ Heat gains +2 |

### Joker modifiers (slot 1)

| Card | Base | Effect |
|---|---|---|
| Cone | 3 | Hits the top 3 Heat players this round |
| Double Tap | 3 | Joker attacks twice |
| Stand Down | 2 | Joker skips this round's attack (still grows +10) |
| Lock-On | 2 | Locks onto the current hottest player |
| Wild Card | 2 | Random target this round |
| Invert | 2 | Targets the lowest-Heat player |
| Ignite / Flood / Overgrow | 2 | Sets the Joker's type to Fire / Water / Grass |
| Venom Fang | 2 | Joker's hit also applies poison (stacks) |
| Overcharge | 3 | +20 Joker damage this round only |

### Traps (slot 1)

| Card | Base | Trigger → effect |
|---|---|---|
| Poison to Healing | 1 | Someone stacks poison → it becomes healing instead |
| Joker Deflect | 2 | The Joker would hit you → it redirects 2 seats anticlockwise (no Heat reset) |
| Backfire | 2 | The next targeted attack on you → it hits the attacker instead |
| Tripwire | 1 | The next player to play a targeted card → they gain +3 Heat |
| Type Snare | 2 | The next player to change type → they take 20 damage |
| Grudge | 2 | You get hit by the Joker → the hottest *other* player takes the same damage |
| Wellspring | 1 | A Water card enters the collective pool → all Water players heal 10 |

---

## 9. Parked ideas

Not cut, just shelved until they fit:

- **Roguelike elements** (drafting, run structure, unlocks). Judge against the game's philosophy later.
- **Theme details:** the host's name and personality, creature designs.
- **Hero characters** with a passive ability and a themed starting type. Every player starts with one, for variety. Passives should bend rules rather than act as self-buffs.
- **Hidden typing**, plus scouting via collective cards, a "when your type is revealed, reveal everyone's" trap, and secret type-change cards.
- **Secondary type slot.**
- **More types** (e.g. Electric, Rock).
- **Extra Joker-like units** placed during play, with a 1-turn setup window (no attack if placed on the round's last turn).
- **Buff cards** usable only on others (a friend, or as a bribe).
- **Heat-slowing cards** that soften the Heat death spiral.
- **Direct healing** (e.g. "heal yourself 20, deal 20 to everyone"). Retired for now as too strong.
- **Personal decks** alongside the shared deck (a hybrid). Shelved because it adds complexity; could return as an expansion or separate mode.
- **Purchasable artifacts.** Must follow the no-pay-to-win rule.

---

## 10. Open questions

1. **Final name** (working title: Card Masters).
