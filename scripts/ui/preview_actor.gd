## Acteur de prévisualisation (menus) : expose les mêmes champs qu'un Fighter
## pour que FighterRig puisse l'afficher sans logique de combat.
class_name PreviewActor
extends Node3D

var anim: StringName = &"idle"
var anim_frame := 0.0
var anim_marks := Vector3i.ZERO
var anim_frozen := true
var transformed := false
var rig: FighterRig
var _queue: Array = []

func show_fighter(d: FighterData, costume: int) -> void:
	if rig:
		rig.queue_free()
	rig = FighterRig.new()
	add_child(rig)
	rig.setup(self, d, costume)
	play(d.intro_anim)
	_queue = [&"idle"]

func play(a: StringName) -> void:
	anim = a
	anim_frame = 0.0

func _process(dt: float) -> void:
	anim_frame += dt * 60.0
	var info := AnimLib.get_anim(anim)
	if not info.loop and anim_frame > info.length + 20 and not _queue.is_empty():
		play(_queue.pop_front())
