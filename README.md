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

Phase 1 done: a headless rules core that plays full matches with the five attack cards (turns, draw/keep, Heat, the Joker, elimination, event log). Next up: Phase 2, the rest of the card families.
