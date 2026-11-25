## Projectile mystique (logique). Le visuel est un nœud recyclé fourni par Match.
class_name Projectile
extends RefCounted

var owner_f: Fighter
var power: PowerData
var pos := Vector3.ZERO
var dir := Vector3.FORWARD
var traveled := 0.0
var alive := true
var damage := 10.0
var width := 0.5
var speed := 9.0
var visual: Node3D

func setup(o: Fighter, p: PowerData) -> void:
	owner_f = o
	power = p
	dir = o.fwd()
	speed = p.speed * (1.2 if o.transformed else 1.0)
	width = p.width * (1.6 if o.transformed else 1.0)
	damage = p.damage * o.dmg_mult()
	if p.kind == PowerData.Kind.SHOCKWAVE:
		pos = o.position + dir * 0.8
		pos.y = 0.05
	else:
		pos = o.position + dir * 0.75 + Vector3.UP * 1.25 * o.data.height

func is_ground() -> bool:
	return power.kind == PowerData.Kind.SHOCKWAVE

## Teste le contact avec un combattant. Retourne true en cas de contact.
func touches(f: Fighter) -> bool:
	var rel := f.position - pos
	rel.y = 0
	var along := rel.dot(dir)
	var lateral := (rel - dir * along).length()
	if absf(along) > 0.35 + speed / 60.0:
		return false
	if lateral > width + 0.27 * f.data.bulk:
		return false
	if is_ground():
		return f.position.y < 0.35
	var fy := f.position.y
	return pos.y > fy + 0.2 and pos.y < fy + 1.75 * f.data.height
