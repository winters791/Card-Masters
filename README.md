# Card Masters

*Working title.* A 2–4 player digital card game where every card is a weapon. There are no self-buffs: you survive by attacking strategically, shifting your type and setting traps, while a drama-loving game host punishes whoever causes the most chaos. Last player standing wins.

This repo holds the **Godot 4.x prototype**.

- [Design doc](docs/design.md) — the full rules
- [Roadmap](docs/roadmap.md) — prototype phases and progress
- [CLAUDE.md](CLAUDE.md) — instructions for Claude Code working in this repo

## The game in 30 seconds

- Everyone starts at 100 HP as Normal type. Types: Grass → Water → Fire → Grass (2x strong, 0.5x resisted).
- Each turn: draw up to 3 and optionally discard 1; play up to one **Trap/Joker** card and one **Attack/Effect** card, into the **collective pool** (hits everyone) or at **one target**.
- Every play builds **Drama** (Heat). At the end of each round the host (the Joker) hits whoever has the most, for 10 damage, +10 every round.
- Getting hit resets your Drama. By round 10 the host one-shots.

## Status

Phases 1 and 2 done: a headless rules core that plays full matches with all 37 cards of the first batch (attacks, damage over time, type changes, disruption, Heat manipulation, Joker modifiers and traps). Phase 3 done too: random and greedy bots plus a headless simulator (`godot --headless --path . -s res://ai/simulate.gd`).

**Playable:** Phase 4's hotseat prototype. Run `godot --path .`, pick 2–4 seats (each a human or a bot) and play on one computer; a pass-the-device screen hides each hand between human turns. Hover a card for details, click the draw pile to draw, and drag cards onto a player's pool (targeted), the collective pool (everyone) or the discard pile. Next up: Phase 5, playtesting and balance.
