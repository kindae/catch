## Commande d'un combattant pour une frame logique (joueur, IA ou réseau).
class_name FighterCmd
extends RefCounted

## Direction de déplacement dans le monde (plan XZ, longueur <= 1).
var dir := Vector3.ZERO
var block := false
## Actions pressées ce tick : punch, kick, grab, dodge, jump, power, ultimate.
var pressed: Dictionary = {}

func press(a: StringName) -> void:
	pressed[a] = true

func clear() -> void:
	dir = Vector3.ZERO
	block = false
	pressed.clear()
