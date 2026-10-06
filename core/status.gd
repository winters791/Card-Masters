class_name Status
extends RefCounted
## Ids for lasting effects on a player (all public).

## Venom: tick damage each round end for a number of rounds. Stacks.
const POISON: StringName = &"poison"
## Scorch: tick damage each round end until the player changes type. Stacks.
const BURN: StringName = &"burn"
## Rot: the player's next resist is halved (0.5x -> 0.75x). Doesn't stack.
const ROT: StringName = &"rot"
