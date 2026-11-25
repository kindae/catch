## Caméra dynamique de combat 3D : suit les deux combattants, adapte la
## distance, reste du même côté de l'axe (pas de saut brutal), se recentre
## pendant les prises et propose des plans cinématiques (transformation, ultime).
class_name FightCamera
extends Camera3D

enum Mode { FIGHT, FOCUS, INTRO, GRAB }

var f1: Node3D
var f2: Node3D
var mode: int = Mode.FIGHT
var focus_target: Node3D
var focus_time := 0.0
var focus_dur := 1.0
var focus_dist := 2.6
var focus_height := 1.2
var focus_orbit := 50.0
var focus_start_angle := 0.0

var _look := Vector3(0, 1, 0)
var _trauma := 0.0
var _noise_t := 0.0
var _side_dir := Vector3(0, 0, 1)
var _fov_base := 50.0

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = _fov_base
	near = 0.1
	far = 120.0

func setup(a: Node3D, b: Node3D) -> void:
	f1 = a
	f2 = b
	var mid := (a.global_position + b.global_position) * 0.5
	var axis := b.global_position - a.global_position
	axis.y = 0
	_side_dir = axis.normalized().cross(Vector3.UP)
	global_position = mid + _side_dir * 6.0 + Vector3.UP * 2.4
	_look = mid + Vector3.UP
	look_at(_look)

func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func focus(target: Node3D, duration: float, dist := 2.6, height := 1.2, orbit := 50.0) -> void:
	mode = Mode.FOCUS
	focus_target = target
	focus_time = 0.0
	focus_dur = duration
	focus_dist = dist
	focus_height = height
	focus_orbit = orbit
	var to_cam := global_position - target.global_position
	to_cam.y = 0
	focus_start_angle = atan2(to_cam.x, to_cam.z)

func release() -> void:
	mode = Mode.FIGHT

## Directions écran projetées au sol (pour convertir le joystick).
func screen_right() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0
	return r.normalized()

func screen_forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0
	return f.normalized()

func _pos_of(n: Node3D) -> Vector3:
	var r = n.get(&"rig")
	if r is Node3D:
		return (r as Node3D).global_position
	return n.global_position

func _process(dt: float) -> void:
	if f1 == null or f2 == null:
		return
	var rdt := dt / maxf(Engine.time_scale, 0.05)  # la caméra reste fluide pendant les ralentis
	rdt = minf(rdt, 0.05)
	var a := _pos_of(f1)
	var b := _pos_of(f2)
	var desired: Vector3
	var look: Vector3
	var smooth := 5.0
	match mode:
		Mode.FOCUS:
			focus_time += rdt
			var t := clampf(focus_time / focus_dur, 0.0, 1.0)
			var ang := focus_start_angle + deg_to_rad(focus_orbit) * (t * t * (3.0 - 2.0 * t))
			var c := _pos_of(focus_target)
			desired = c + Vector3(sin(ang), 0, cos(ang)) * focus_dist + Vector3.UP * focus_height
			look = c + Vector3.UP * (focus_height - 0.15)
			smooth = 4.0
		_:
			var mid := (a + b) * 0.5
			var axis := b - a
			axis.y = 0
			var sep := axis.length()
			if sep > 0.05:
				var perp := axis.normalized().cross(Vector3.UP)
				if perp.dot(_side_dir) < 0.0:
					perp = -perp
				# rotation limitée : évite les mouvements excessifs
				_side_dir = _side_dir.slerp(perp, minf(1.0, rdt * 2.5)).normalized()
			var dist := clampf(sep * 0.95 + 3.4, 4.6, 9.0)
			var h := 2.25 + sep * 0.12
			if mode == Mode.GRAB:
				dist = 3.6
				h = 1.5
			var hy := maxf(a.y, b.y) * 0.5
			desired = mid + _side_dir * dist + Vector3.UP * (h + hy)
			look = mid + Vector3.UP * (0.95 + hy * 0.8)
			# reste dans l'arène (ne traverse pas les tribunes)
			desired.x = clampf(desired.x, -9.0, 9.0)
			desired.z = clampf(desired.z, -9.0, 9.0)
	var k := 1.0 - exp(-rdt * smooth)
	global_position = global_position.lerp(desired, k)
	_look = _look.lerp(look, 1.0 - exp(-rdt * smooth * 1.6))
	look_at(_look)
	# tremblement (trauma²)
	_trauma = maxf(0.0, _trauma - rdt * 1.6)
	_noise_t += rdt * 30.0
	var s := _trauma * _trauma
	if s > 0.0:
		rotate_object_local(Vector3.RIGHT, sin(_noise_t * 1.3) * 0.03 * s)
		rotate_object_local(Vector3.UP, sin(_noise_t * 1.7 + 2.0) * 0.03 * s)
		rotate_object_local(Vector3.FORWARD, sin(_noise_t * 0.9 + 4.0) * 0.04 * s)
	fov = lerpf(fov, _fov_base - (6.0 if mode == Mode.FOCUS else 0.0), 1.0 - exp(-rdt * 3.0))
