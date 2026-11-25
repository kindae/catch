## Données d'un coup (frame data). Purement logique : aucune référence au rendu.
## Les durées sont exprimées en frames logiques (60 par seconde).
class_name MoveData
extends Resource

@export var id: StringName
@export var display_name := ""
## Identifiant d'animation dans AnimLib (le rendu lit cet identifiant).
@export var anim: StringName = &"jab"
@export var startup := 6
@export var active := 3
@export var recovery := 12
@export var damage := 8.0
@export var stamina_cost := 4.0
@export var hit_stun := 16
@export var block_stun := 10
## Recul infligé à la cible (mètres).
@export var push := 0.25
## Centre de la hitbox dans le repère local de l'attaquant (-Z = vers l'avant).
@export var hitbox_offset := Vector3(0, 1.45, -0.75)
@export var hitbox_radius := 0.22
## Distance parcourue vers l'avant pendant startup + active.
@export var lunge := 0.0
## Projette la cible au sol (knockdown).
@export var launches := false
@export var launch_velocity := Vector3(0, 4.5, 3.0)
## Coup aérien (exécuté pendant un saut, actif jusqu'à l'atterrissage).
@export var aerial := false
## Enchaînements : action -> id du coup suivant.
@export var chain: Dictionary = {}
## Fenêtre d'annulation supplémentaire après la phase active.
@export var cancel_late := 8
@export var hitstop := 5
@export var unblockable := false
@export var shake := 0.15

func total_frames() -> int:
	return startup + active + recovery

func is_active(f: int) -> bool:
	return f > startup and f <= startup + active

func duplicate_with(overrides: Dictionary) -> MoveData:
	var m: MoveData = duplicate(true)
	for k in overrides:
		m.set(k, overrides[k])
	return m
