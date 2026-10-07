# First simulation baseline (6 Oct 2026)

Bots only, after Phase 3. GreedyBot is a rough heuristic player, so treat these as signals to check in human playtests, not verdicts.

> **Correction (7 Oct):** the early-seat disadvantage below was a GreedyBot bug (ties always went to the lowest seat, so every bot ganged up on Player 1). With random tie-breaks seats are fair. See `2026-10-07-balance-pass-1.md`.

Reproduce with:

```bash
godot --headless --path . -s res://ai/simulate.gd -- --matches=1000 --players=4 --bots=greedy --seed=1
```

## Signals worth checking

- **Matches are far too short.** About 4 rounds with GreedyBot (5.5 with RandomBot) against the ~10-round target in `design.md` §7. Card damage, not the Joker, is the main killer for GreedyBot (about half of eliminations), so either card damage is too high for 100 HP, or players are much more aggressive than intended.
- **Early seats lose badly with GreedyBot.** With 4 players, seat 1 wins about 3% and seat 4 about 40% (3 players: 8% / 26% / 58%). Random bots are fair, so it comes from play order, not the deck: the first player each round commits Heat and attacks first, then everyone else reacts. With matches this short, the starting-seat rotation can't even it out. This is the "last-seat advantage" item on the watch list.
- **Draws happen 7–15% of the time**, mostly from Joker ties late in the match.
- **Rarely played:** Rot, Rooted, Type Swap, Convert, Silence, Cone and the Joker type cards show up less than once per 10 matches with GreedyBot. That may be the bot's simple scoring rather than the cards; check with humans.

## 4 players, all GreedyBot, 1000 matches

```
=== Card Masters simulation ===
1000 matches (1000 finished, 0 stalled), 4 players, bots ["greedy", "greedy", "greedy", "greedy"]
Match length (rounds): mean 3.9, median 4, min 2, max 7
    2 rounds:    19
    3 rounds:   312
    4 rounds:   454
    5 rounds:   185
    6 rounds:    29
    7 rounds:     1
Draw rate: 12.5%
Win rate by seat:                2.8%   11.0%   34.2%   39.5%
Avg elimination round by seat:    2.6     3.3     3.7     3.7
Who eliminates players:
  card                49.4%
  joker               31.6%
  damage over time    11.9%
  trap                 7.1%
Heat at the Joker attack: mean 7.4, median 6, p90 14, max 33
Skips per match: 0.0
Card plays per match:
  scorch              1.75
  wildfire            1.49
  tidal_crash         1.48
  thornlash           1.45
  ember               1.37
  venom               1.34
  invert              1.21
  stand_down          1.14
  tripwire            1.10
  poison_to_healing   1.09
  shed_skin           0.98
  lock_on             0.90
  venom_fang          0.82
  wild_card           0.78
  joker_deflect       0.68
  grudge              0.62
  cataclysm           0.52
  type_snare          0.46
  backfire            0.42
  overcharge          0.39
  wellspring          0.34
  dry_well            0.32
  double_tap          0.32
  pickpocket          0.29
  exposed             0.29
  scapegoat           0.26
  ignite              0.13
  flashpoint          0.11
  spotlight           0.11
  flood               0.10
  cone                0.07
  silence             0.07
  convert             0.06
  overgrow            0.04
  rot                 0.03
  rooted              0.02
  type_swap           0.01
```

## 2 players, all GreedyBot, 1000 matches (summary)

```
Match length (rounds): mean 3.7, median 4, min 2, max 7
Draw rate: 7.2%
Win rate by seat:               46.8%   46.0%
Avg elimination round by seat:    3.7     3.7
  joker               46.1%
  card                33.8%
  trap                11.0%
  damage over time     9.1%
Heat at the Joker attack: mean 6.7, median 6, p90 13, max 27
```

## 3 players, all GreedyBot, 1000 matches (summary)

```
Match length (rounds): mean 3.9, median 4, min 2, max 7
Draw rate: 7.8%
Win rate by seat:                8.0%   26.0%   58.2%
Avg elimination round by seat:    3.2     3.7     3.9
  card                41.2%
  joker               36.7%
  damage over time    13.2%
  trap                 8.8%
Heat at the Joker attack: mean 7.5, median 6, p90 14, max 30
```

## 4 players, all RandomBot, 1000 matches (summary)

```
Match length (rounds): mean 5.5, median 5, min 3, max 10
Draw rate: 14.5%
Win rate by seat:               22.3%   21.1%   20.6%   21.5%
Avg elimination round by seat:    4.8     4.7     4.8     4.8
  joker               69.6%
  damage over time    14.4%
  card                11.1%
  trap                 4.9%
Heat at the Joker attack: mean 6.7, median 6, p90 13, max 31
Skips per match: 4.5
```
