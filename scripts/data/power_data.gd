## Pouvoir mystique : coût, temps de recharge et moyens de défense.
class_name PowerData
extends Resource

enum Kind { SHOCKWAVE, ORB, TELEPORT, SHIELD, FIRE_AURA, POWER_UP, ILLUSION, SPIRIT, BEAM }

@export var id: StringName
@export var display_name := ""
@export var kind: Kind = Kind.SHOCKWAVE
@export var energy_cost := 25.0
## Temps de recharge en frames.
@export var cooldown := 240
@export var startup := 14
@export var recovery := 22
@export var damage := 12.0
@export var speed := 9.0
@export var range_m := 7.0
@export var width := 0.55
@export var color := Color(1.0, 0.55, 0.1)
## Texte affiché dans le guide : comment se défendre.
@export var counter_hint := ""
## Implémenté dans le prototype ?
@export var implemented := true
