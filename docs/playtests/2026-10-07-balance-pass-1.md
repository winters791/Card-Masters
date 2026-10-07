# Balance pass 1: match length (7 Oct 2026)

Simulation only, no humans yet. Goal from the roadmap: matches of about **20 minutes / ~10 rounds** where no single strategy dominates. All runs: 500 matches, seed 1, GreedyBot in every seat unless noted. GreedyBot plays more aggressively than people probably will, and RandomBot more passively, so real matches likely land between the two.

Reproduce any row with, for example:

```bash
godot --headless --path . -s res://ai/simulate.gd -- --matches=500 --players=4 --seed=1 \
    --set=STARTING_HP=250 --damage-scale=0.5 --dot-scale=0.5
```

## Correction: there is no real seat advantage

The first baseline (6 Oct) reported that seat 1 wins about 3% and seat 4 about 40% of 4-player matches. That was a **bot bug**. When several plays scored the same, GreedyBot took the first one, and targets are listed in seat order, so every bot defaulted to attacking Player 1, then Player 2. With ties broken at random, seats are fair (4 players: 26 / 24 / 19 / 20%; 3 players: 26 / 36 / 28%, within the noise of 500 matches). The "last-seat advantage" watch-list item stays open for human playtests, but the simulation no longer shows it.

## Why matches are short

With today's numbers, a 4-player match lasts **3.7 rounds** on average. Per match, the damage comes from:

| Source | Damage per match | Share |
|---|---|---|
| Cards (direct damage) | ~242 | 59% |
| Damage over time and traps | ~79 | 19% |
| The Joker | ~92 | 22% |

So players knock each other out with cards long before the Joker gets dangerous. The Joker only hits more than one player 14% of the time, so ties aren't the problem.

Damage over time hits harder than it looks. A collective Scorch burns *every* player for 10 a round for the rest of the match, and burns stack.

## What each dial does (4 players)

| Settings | Avg rounds | Draws | Eliminated by the Joker | Eliminated by cards |
|---|---|---|---|---|
| Today (HP 100) | 3.7 | 11% | 35% | 48% |
| HP 150 | 4.8 | 8% | 43% | 39% |
| HP 200 | 5.8 | 9% | 49% | 32% |
| HP 300 | 7.5 | 8% | 56% | 26% |
| HP 400 | 8.9 | 7% | 60% | 23% |
| Card damage x0.5 | 4.7 | 11% | 49% | 24% |
| **No** card damage at all | 5.3 | 12% | 58% | 0% |
| HP 200, cards x0.5 | 7.0 | 9% | 57% | 15% |
| HP 150, cards x0.5, damage over time x0.5 | 6.5 | 10% | 62% | 18% |
| HP 200, cards x0.5, damage over time x0.5 | 7.5 | 10% | 66% | 16% |
| HP 250, cards x0.5, damage over time x0.5 | **8.5** | 7% | 65% | 17% |
| HP 250, cards x0.5, damage over time x0.5, Joker +15/round | 7.7 | 9% | 72% | 11% |

Same HP 250 / x0.5 / x0.5 settings at other player counts: 2 players 7.5 rounds, 3 players 8.3 rounds. With RandomBots at 4 players it's 10.7 rounds.

What this shows:
- **No single dial reaches ~10 rounds.** Cutting card damage alone stalls around 5 rounds, because damage over time and the Joker still end things.
- **HP is the strongest dial.** Raising it also shifts the kills toward the Joker, which matches the "escalation via the Joker" pillar.
- **A faster-growing Joker shortens matches** (more Joker kills, fewer rounds).

## The design problem (for Uday)

The design asks for two things that pull against each other:
1. **~10 rounds** per match (§7).
2. **"Round 10: the Joker one-shots anyone at neutral"**, i.e. the Joker's damage around round 10 is about a full HP bar.

If HP grows to make matches last, the Joker's +10 a round no longer one-shots anyone by round 10 (it hits for 100 against 250 or 400 HP). If the Joker grows faster to keep the one-shot, matches get shorter again.

## Options

| | Change | Bots say | Trade-off |
|---|---|---|---|
| **A** | HP 100 → **400**; card text unchanged | ~9 rounds | One number to change. But a 40-damage Cataclysm becomes a tenth of a life bar, and the Joker never one-shots. |
| **B** | HP → **250**; **halve** card damage and poison/burn ticks (Ember 5, Thornlash 10, Tidal Crash 10, Wildfire 8, Cataclysm 20, Shed Skin 5, Venom 3/round, Scorch 5/round) | ~8.5 rounds (≈10 with gentler players); the Joker gets ~65% of the kills | Every damage number in §8 changes, and the Joker's round-10 hit is 100 of 250 HP. Biggest step toward "the Joker is the threat". |
| **C** | HP → **200**; cards x0.75; poison/burn x0.5 | ~6.8 rounds | A smaller change, still short of 10. |
| **D** | Keep everything; change the target to **~4–5 rounds (~10 min)** | 3.7 rounds | No rules change. Fast, brutal matches, mostly decided by cards. |

**My suggestion:** playtest **B** first. It gets closest to the target, makes the Joker the main source of elimination, and keeps every card relevant compared with the HP bar. The round-10 one-shot line in §7 would become "by round 10 the Joker takes ~40% of a life bar per hit", or grow the Joker to +15 a round if the matches still feel long with people.

Nothing in the game has changed yet. The defaults in `core/config.gd` and the card files are still the design-doc values until Uday picks.

## Tools added in this pass

- `--set=NAME=value[,…]` overrides any balance number for one simulator run (e.g. `STARTING_HP`, `JOKER_DAMAGE_PER_ROUND`, `COPIES_COMMON`). See `Config.TUNABLE`.
- `--damage-scale=x` scales every card's direct damage; `--dot-scale=x` scales every poison/burn tick.
- GreedyBot breaks ties at random (the seat-advantage fix above).
