## Bibliothèque d'animations procédurales par poses clés.
## Chaque animation : { "keys": [[frame, pose], ...], "loop": bool, "marks": Vector3i }
## Une pose = Dictionary joint -> Vector3 (degrés, ordre YXZ) + "pos" (décalage du bassin).
## "marks" (fin du startup, fin de la phase active, fin) permet de recaler
## l'animation sur la frame data réelle du coup : rendu et hitbox restent synchrones.
##
## Conventions (combattant tourné vers -Z) :
##  X+ : bras/jambes vers l'avant, buste/tête vers l'arrière ; genou X- = flexion
##  Z  : abduction (droite +Z, gauche -Z) ; Y+ : rotation vers la gauche.
class_name AnimLib
extends RefCounted

const JOINTS := [&"pelvis", &"spine", &"chest", &"neck", &"head",
	&"sh_l", &"el_l", &"hd_l", &"sh_r", &"el_r", &"hd_r",
	&"hip_l", &"kn_l", &"ft_l", &"hip_r", &"kn_r", &"ft_r"]

static var _lib: Dictionary = {}

static func get_anim(id: StringName) -> Dictionary:
	if _lib.is_empty():
		_build()
	return _lib.get(id, _lib[&"idle"])

static func has_anim(id: StringName) -> bool:
	if _lib.is_empty():
		_build()
	return _lib.has(id)

static func V(x: float, y := 0.0, z := 0.0) -> Vector3:
	return Vector3(x, y, z)

static func P(base: Dictionary, o: Dictionary) -> Dictionary:
	var d := base.duplicate()
	for k in o:
		d[k] = o[k]
	return d

static func _add(id: StringName, keys: Array, loop := false, marks := Vector3i.ZERO) -> void:
	_lib[id] = {"keys": keys, "loop": loop, "marks": marks, "length": int(keys[keys.size() - 1][0])}

## Échantillonne une pose (interpolation lissée entre clés).
static func sample(id: StringName, frame: float) -> Dictionary:
	var a := get_anim(id)
	var keys: Array = a.keys
	var length: float = maxf(1.0, a.length)
	var f := frame
	if a.loop:
		f = fposmod(frame, length)
	else:
		f = clampf(frame, 0.0, length)
	var i := 0
	while i < keys.size() - 1 and keys[i + 1][0] <= f:
		i += 1
	if i >= keys.size() - 1:
		return keys[keys.size() - 1][1]
	var f0: float = keys[i][0]
	var f1: float = keys[i + 1][0]
	var t := 0.0 if f1 <= f0 else (f - f0) / (f1 - f0)
	t = t * t * (3.0 - 2.0 * t)
	var p0: Dictionary = keys[i][1]
	var p1: Dictionary = keys[i + 1][1]
	var out := {}
	for k in p0:
		out[k] = p0[k].lerp(p1.get(k, p0[k]), t)
	for k in p1:
		if not out.has(k):
			out[k] = Vector3.ZERO.lerp(p1[k], t) if k != &"pos" else p1[k] * t
	return out

static func _build() -> void:
	# ---------------------------------------------------------- garde
	var G := {
		&"pos": V(0, -0.06, 0), &"pelvis": V(0, -22), &"spine": V(-6, -5), &"chest": V(-4, -6),
		&"neck": V(0, 10), &"head": V(6, 20),
		&"sh_l": V(58, -12, -12), &"el_l": V(100), &"hd_l": V(0),
		&"sh_r": V(42, 18, 18), &"el_r": V(128), &"hd_r": V(0),
		&"hip_l": V(22, 0, -5), &"kn_l": V(-26), &"ft_l": V(6),
		&"hip_r": V(-16, 0, 8), &"kn_r": V(-22), &"ft_r": V(14),
	}
	var G2 := P(G, {&"pos": V(0, -0.08, 0), &"chest": V(-2, -6), &"sh_l": V(60, -12, -14), &"sh_r": V(44, 18, 20)})
	_add(&"idle", [[0, G], [30, G2], [60, G]], true)
	var STAND := {&"pos": V(0, 0, 0), &"pelvis": V(0), &"spine": V(0), &"chest": V(2), &"head": V(0),
		&"sh_l": V(4, 0, -8), &"el_l": V(12), &"sh_r": V(4, 0, 8), &"el_r": V(12),
		&"hip_l": V(0, 0, -3), &"kn_l": V(-3), &"ft_l": V(0), &"hip_r": V(0, 0, 3), &"kn_r": V(-3), &"ft_r": V(0)}
	_add(&"stand", [[0, STAND], [60, P(STAND, {&"chest": V(4)})], [120, STAND]], true)

	# ---------------------------------------------------------- déplacements
	var WA := P(G, {&"hip_l": V(34, 0, -5), &"kn_l": V(-12), &"hip_r": V(-24, 0, 8), &"kn_r": V(-30), &"pos": V(0, -0.07, 0)})
	var WB := P(G, {&"hip_l": V(8, 0, -5), &"kn_l": V(-40), &"hip_r": V(18, 0, 8), &"kn_r": V(-48), &"pos": V(0, -0.04, 0)})
	var WC := P(G, {&"hip_l": V(-14, 0, -5), &"kn_l": V(-30), &"hip_r": V(30, 0, 8), &"kn_r": V(-14), &"pos": V(0, -0.07, 0)})
	var WD := P(G, {&"hip_l": V(18, 0, -5), &"kn_l": V(-50), &"hip_r": V(6, 0, 8), &"kn_r": V(-36), &"pos": V(0, -0.04, 0)})
	_add(&"walk_f", [[0, WA], [8, WB], [16, WC], [24, WD], [32, WA]], true)
	_add(&"walk_b", [[0, WC], [9, WB], [18, WA], [27, WD], [36, WC]], true)
	var SA := P(G, {&"hip_l": V(20, 0, -18), &"hip_r": V(-14, 0, 4), &"kn_l": V(-20), &"pos": V(0, -0.07, 0)})
	var SB := P(G, {&"hip_l": V(20, 0, -2), &"hip_r": V(-14, 0, 18), &"kn_r": V(-36), &"pos": V(0, -0.04, 0)})
	_add(&"side", [[0, SA], [14, SB], [28, SA]], true)

	# ---------------------------------------------------------- saut
	var CROUCH := P(G, {&"pos": V(0, -0.22, 0), &"hip_l": V(55, 0, -6), &"kn_l": V(-80), &"hip_r": V(35, 0, 8), &"kn_r": V(-75), &"spine": V(-15, -5), &"ft_l": V(-10), &"ft_r": V(-5)})
	var TUCK := P(G, {&"pos": V(0, 0.1, 0), &"hip_l": V(75, 0, -8), &"kn_l": V(-110), &"hip_r": V(60, 0, 8), &"kn_r": V(-115), &"spine": V(-10, -5), &"sh_l": V(30, 0, -40), &"sh_r": V(30, 0, 40)})
	var EXT := P(G, {&"pos": V(0, 0.05, 0), &"hip_l": V(10, 0, -5), &"kn_l": V(-10), &"hip_r": V(-5, 0, 6), &"kn_r": V(-15), &"ft_l": V(-30), &"ft_r": V(-30)})
	_add(&"jump", [[0, CROUCH], [5, EXT], [14, TUCK], [30, TUCK], [40, EXT]])
	_add(&"land", [[0, CROUCH], [8, G]])

	# ---------------------------------------------------------- défense / réactions
	var BLOCK := P(G, {&"spine": V(-12, -10), &"head": V(-8, 25), &"sh_l": V(82, -20, -6), &"el_l": V(138), &"sh_r": V(80, 25, 8), &"el_r": V(140), &"pos": V(0, -0.1, 0)})
	_add(&"block", [[0, BLOCK], [40, P(BLOCK, {&"pos": V(0, -0.11, 0)})], [80, BLOCK]], true)
	_add(&"blockstun", [[0, BLOCK], [3, P(BLOCK, {&"spine": V(4, -10), &"pos": V(0, -0.14, 0)})], [12, BLOCK]])
	var HIT_HI := P(G, {&"spine": V(14, 6), &"chest": V(10, 10), &"head": V(28, -20, 10), &"sh_l": V(30, 0, -45), &"el_l": V(40), &"sh_r": V(25, 0, 50), &"el_r": V(50)})
	var HIT_HI2 := P(HIT_HI, {&"head": V(24, 30, -12), &"spine": V(12, -16)})
	var HIT_MID := P(G, {&"spine": V(-28, 0), &"chest": V(-12), &"head": V(-10), &"sh_l": V(40, 0, -20), &"el_l": V(70), &"sh_r": V(40, 0, 20), &"el_r": V(70), &"pos": V(0, -0.14, 0)})
	_add(&"hit_high", [[0, G], [3, HIT_HI], [12, HIT_HI], [22, G]])
	_add(&"hit_high2", [[0, G], [3, HIT_HI2], [12, HIT_HI2], [22, G]])
	_add(&"hit_mid", [[0, G], [3, HIT_MID], [14, HIT_MID], [24, G]])
	var STAG := P(G, {&"spine": V(8, 10, 8), &"head": V(15, 0, 12), &"sh_l": V(10, 0, -25), &"el_l": V(30), &"sh_r": V(15, 0, 30), &"el_r": V(25), &"pos": V(0, -0.1, 0)})
	_add(&"stagger", [[0, STAG], [20, P(STAG, {&"spine": V(8, -10, -8), &"head": V(15, 0, -12)})], [40, STAG]], true)

	var FLY := P(G, {&"pelvis": V(55), &"spine": V(15), &"head": V(25), &"pos": V(0, 0, 0), &"sh_l": V(60, 0, -80), &"el_l": V(20), &"sh_r": V(70, 0, 80), &"el_r": V(30), &"hip_l": V(50, 0, -10), &"kn_l": V(-40), &"hip_r": V(30, 0, 10), &"kn_r": V(-60)})
	_add(&"knock_fly", [[0, HIT_HI], [8, FLY], [30, P(FLY, {&"pelvis": V(80)})]])
	var LYING := {&"pos": V(0, -0.86, 0), &"pelvis": V(90), &"spine": V(0), &"chest": V(0), &"neck": V(0), &"head": V(-12),
		&"sh_l": V(10, 0, -70), &"el_l": V(30), &"sh_r": V(20, 0, 75), &"el_r": V(20),
		&"hip_l": V(5, 0, -10), &"kn_l": V(-10), &"ft_l": V(20), &"hip_r": V(15, 0, 8), &"kn_r": V(-30), &"ft_r": V(20)}
	var LYING2 := P(LYING, {&"head": V(-20, 15), &"sh_r": V(30, 0, 60), &"kn_r": V(-40)})
	_add(&"lying", [[0, LYING], [50, LYING2], [100, LYING]], true)
	_add(&"knock_land", [[0, P(LYING, {&"pos": V(0, -0.7, 0), &"pelvis": V(80)})], [6, LYING], [14, LYING2]])
	var SIT := {&"pos": V(0, -0.72, 0), &"pelvis": V(35), &"spine": V(-35), &"chest": V(-10), &"head": V(-5),
		&"sh_l": V(-30, 0, -20), &"el_l": V(10), &"sh_r": V(-30, 0, 20), &"el_r": V(10),
		&"hip_l": V(50, 0, -10), &"kn_l": V(-60), &"hip_r": V(80, 0, 10), &"kn_r": V(-120)}
	var KNEEL := P(G, {&"pos": V(0, -0.4, 0), &"pelvis": V(0), &"spine": V(-20), &"hip_l": V(85, 0, -8), &"kn_l": V(-90), &"hip_r": V(-5, 0, 8), &"kn_r": V(-110), &"ft_r": V(-40)})
	_add(&"getup", [[0, LYING], [8, SIT], [16, KNEEL], [26, G]])
	_add(&"ko_fall", [[0, HIT_HI], [12, P(HIT_HI, {&"pos": V(0, -0.3, 0), &"kn_l": V(-70), &"kn_r": V(-70), &"hip_l": V(40), &"hip_r": V(40), &"pelvis": V(20)})], [26, P(SIT, {&"pelvis": V(60)})], [40, LYING]])
	var DEFEAT := P(KNEEL, {&"spine": V(-35), &"head": V(-35), &"sh_l": V(10, 0, -10), &"el_l": V(20), &"sh_r": V(30, 0, 10), &"el_r": V(60)})
	_add(&"defeat", [[0, LYING], [10, SIT], [24, DEFEAT], [120, P(DEFEAT, {&"head": V(-25)})], [240, DEFEAT]], false)

	# ---------------------------------------------------------- esquives
	var DODGE := P(G, {&"pos": V(0, -0.2, 0), &"spine": V(-18, -5, 18), &"head": V(0, 20, -10), &"hip_l": V(40, 0, -20), &"kn_l": V(-60), &"hip_r": V(20, 0, 15), &"kn_r": V(-60)})
	_add(&"dodge", [[0, G], [4, DODGE], [14, DODGE], [22, G]], false, Vector3i(4, 14, 22))
	var DODGE_B := P(G, {&"pos": V(0, -0.12, 0), &"spine": V(18, -5), &"head": V(15, 20), &"hip_l": V(5, 0, -5), &"kn_l": V(-30), &"hip_r": V(-30, 0, 8), &"kn_r": V(-40)})
	_add(&"dodge_back", [[0, G], [4, DODGE_B], [14, DODGE_B], [22, G]], false, Vector3i(4, 14, 22))

	# ---------------------------------------------------------- frappes
	var JAB := P(G, {&"pelvis": V(0, -32), &"spine": V(-6, -8), &"sh_l": V(88, -6, -4), &"el_l": V(4), &"head": V(4, 34)})
	_add(&"jab", [[0, G], [4, P(G, {&"sh_l": V(70, -10, -8), &"el_l": V(60)})], [6, JAB], [8, JAB], [19, G]], false, Vector3i(6, 8, 19))
	var CROSS := P(G, {&"pelvis": V(0, 12), &"spine": V(-10, 10), &"chest": V(-4, 6), &"head": V(4, -12), &"sh_r": V(90, 10, 2), &"el_r": V(4), &"sh_l": V(70, -20, -10), &"el_l": V(130), &"hip_r": V(-24, 0, 8), &"ft_r": V(30)})
	_add(&"cross", [[0, G], [5, P(G, {&"pelvis": V(0, -30), &"sh_r": V(50, 15, 25), &"el_r": V(110)})], [8, CROSS], [11, CROSS], [25, G]], false, Vector3i(8, 11, 25))
	var UPC_DIP := P(G, {&"pos": V(0, -0.18, 0), &"spine": V(-18, -15), &"sh_r": V(15, 10, 20), &"el_r": V(115), &"kn_l": V(-50), &"kn_r": V(-45)})
	var UPC := P(G, {&"pos": V(0, 0.0, 0), &"pelvis": V(0, 15), &"spine": V(8, 12), &"chest": V(6, 6), &"head": V(14, -10), &"sh_r": V(150, 20, 10), &"el_r": V(55), &"kn_l": V(-8), &"kn_r": V(-10), &"ft_r": V(-20)})
	_add(&"uppercut", [[0, G], [8, UPC_DIP], [11, UPC], [14, UPC], [36, G]], false, Vector3i(11, 14, 36))
	var KM_CH := P(G, {&"hip_r": V(85, 0, 12), &"kn_r": V(-105), &"spine": V(6, -10), &"pos": V(0, -0.02, 0), &"kn_l": V(-14)})
	var KM := P(G, {&"hip_r": V(88, 10, 14), &"kn_r": V(-6), &"ft_r": V(-35), &"spine": V(18, -12), &"pelvis": V(0, -5), &"kn_l": V(-10), &"pos": V(0, -0.02, 0)})
	_add(&"kick_mid", [[0, G], [6, KM_CH], [10, KM], [13, KM], [29, G]], false, Vector3i(10, 13, 29))
	var KH_CH := P(G, {&"pelvis": V(0, -45), &"hip_l": V(100, 0, -25), &"kn_l": V(-115), &"spine": V(10, -10, 8), &"kn_r": V(-12), &"hip_r": V(-5, 0, 8)})
	var KH := P(G, {&"pelvis": V(0, -60), &"hip_l": V(125, -10, -40), &"kn_l": V(-6), &"ft_l": V(-30), &"spine": V(28, -12, 18), &"head": V(-10, 40), &"kn_r": V(-8), &"hip_r": V(-5, 0, 10), &"sh_l": V(40, 0, -50), &"el_l": V(60)})
	_add(&"kick_high", [[0, G], [8, KH_CH], [13, KH], [16, KH], [36, G]], false, Vector3i(13, 16, 36))
	var HAM_UP := P(G, {&"pos": V(0, 0.02, 0), &"spine": V(16, 0), &"chest": V(8), &"pelvis": V(0), &"head": V(12, 0), &"sh_l": V(172, 0, -6), &"el_l": V(35), &"sh_r": V(172, 0, 6), &"el_r": V(35)})
	var HAM := P(G, {&"pos": V(0, -0.2, 0), &"pelvis": V(0), &"spine": V(-34, 0), &"chest": V(-10), &"head": V(-5, 0), &"sh_l": V(78, 8, -2), &"el_l": V(12), &"sh_r": V(78, -8, 2), &"el_r": V(12), &"hip_l": V(45, 0, -8), &"kn_l": V(-65), &"hip_r": V(-10, 0, 8), &"kn_r": V(-40)})
	_add(&"heavy", [[0, G], [10, HAM_UP], [16, HAM], [20, HAM], [42, G]], false, Vector3i(16, 20, 42))
	var SPIN1 := P(G, {&"pelvis": V(0, -150), &"spine": V(0, -20), &"head": V(0, 60), &"hip_r": V(30, 0, 30), &"kn_r": V(-90)})
	var SPIN2 := P(G, {&"pelvis": V(0, -320), &"spine": V(15, -15, 15), &"hip_r": V(95, 0, 45), &"kn_r": V(-4), &"ft_r": V(-30), &"sh_l": V(20, 0, -60), &"sh_r": V(20, 0, 70), &"el_r": V(30), &"kn_l": V(-10)})
	_add(&"spin_kick", [[0, G], [8, SPIN1], [14, SPIN2], [18, SPIN2], [38, P(G, {&"pelvis": V(0, -382)})]], false, Vector3i(14, 18, 38))
	var AK := P(G, {&"pelvis": V(-35), &"spine": V(10), &"head": V(-15), &"hip_l": V(70, 0, -8), &"kn_l": V(-10), &"hip_r": V(75, 0, 8), &"kn_r": V(-5), &"ft_l": V(-40), &"ft_r": V(-40), &"sh_l": V(-30, 0, -50), &"sh_r": V(-30, 0, 50)})
	_add(&"air_kick", [[0, TUCK], [5, AK], [45, AK], [55, CROUCH]], false, Vector3i(5, 45, 55))
	var AE := P(TUCK, {&"spine": V(-25, 20), &"sh_r": V(100, 20, 55), &"el_r": V(150), &"head": V(-10, -10)})
	_add(&"air_elbow", [[0, TUCK], [6, AE], [46, AE], [56, CROUCH]], false, Vector3i(6, 46, 56))

	# ---------------------------------------------------------- prises
	var REACH := P(G, {&"pelvis": V(0, 0), &"spine": V(-18, 0), &"head": V(0, 0), &"sh_l": V(85, 10, -16), &"el_l": V(25), &"sh_r": V(85, -10, 16), &"el_r": V(25), &"pos": V(0, -0.08, 0)})
	_add(&"grab_try", [[0, G], [7, REACH], [10, REACH], [30, G]], false, Vector3i(7, 10, 30))
	var CLINCH := P(REACH, {&"spine": V(-28, 0), &"sh_l": V(72, 20, -28), &"el_l": V(70), &"sh_r": V(72, -20, 28), &"el_r": V(70), &"pos": V(0, -0.16, 0), &"hip_l": V(40, 0, -10), &"kn_l": V(-55), &"hip_r": V(5, 0, 10), &"kn_r": V(-40)})
	var LIFT := P(STAND, {&"spine": V(12, 0), &"chest": V(6), &"head": V(15), &"sh_l": V(175, 0, -22), &"el_l": V(28), &"sh_r": V(175, 0, 22), &"el_r": V(28), &"hip_l": V(10, 0, -12), &"hip_r": V(-5, 0, 12), &"pos": V(0, 0.02, 0)})
	var SLAM := P(G, {&"pelvis": V(0), &"spine": V(-45, 0), &"chest": V(-10), &"head": V(-15), &"sh_l": V(60, 0, -15), &"el_l": V(20), &"sh_r": V(60, 0, 15), &"el_r": V(20), &"pos": V(0, -0.34, 0), &"hip_l": V(60, 0, -12), &"kn_l": V(-85), &"hip_r": V(20, 0, 12), &"kn_r": V(-90)})
	_add(&"slam_atk", [[0, CLINCH], [10, CLINCH], [26, LIFT], [44, LIFT], [53, SLAM], [62, SLAM], [72, G]])
	var DEF_BENT := P(HIT_MID, {&"pos": V(0, -0.1, 0), &"sh_l": V(70, 0, -40), &"sh_r": V(70, 0, 40)})
	var LIFTED := P(LYING, {&"pos": V(0, 1.25, 0), &"pelvis": V(90, 0, 90), &"sh_l": V(40, 0, -60), &"sh_r": V(40, 0, 60), &"kn_l": V(-20), &"kn_r": V(-35)})
	_add(&"slam_def", [[0, DEF_BENT], [10, DEF_BENT], [26, LIFTED], [44, P(LIFTED, {&"pos": V(0, 1.3, 0)})], [53, LYING], [72, LYING2]])
	var TOSS1 := P(CLINCH, {&"pelvis": V(0, 30), &"spine": V(-20, 20), &"sh_r": V(110, -30, 30), &"el_r": V(60)})
	var TOSS2 := P(G, {&"pelvis": V(0, 70), &"spine": V(-35, 30), &"head": V(-10, -30), &"sh_l": V(70, 0, -30), &"el_l": V(30), &"sh_r": V(50, -20, 40), &"el_r": V(20), &"pos": V(0, -0.2, 0), &"hip_l": V(45, 0, -15), &"kn_l": V(-60), &"hip_r": V(10, 0, 15), &"kn_r": V(-50)})
	_add(&"throw_atk", [[0, CLINCH], [10, CLINCH], [22, TOSS1], [34, TOSS2], [46, TOSS2], [58, G]])
	var AIR1 := P(FLY, {&"pelvis": V(200), &"pos": V(0, 1.2, 0)})
	_add(&"throw_def", [[0, DEF_BENT], [10, DEF_BENT], [22, P(DEF_BENT, {&"pos": V(0, 0.35, 0), &"pelvis": V(40)})], [33, AIR1], [44, P(LYING, {&"pelvis": V(450)})], [58, LYING2]])
	_add(&"grabbed", [[0, DEF_BENT], [20, DEF_BENT]], true)

	# ---------------------------------------------------------- immobilisation
	var PIN := {&"pos": V(0, -0.62, 0), &"pelvis": V(-10), &"spine": V(-55), &"chest": V(-10), &"head": V(10), &"neck": V(0),
		&"sh_l": V(70, 0, -20), &"el_l": V(20), &"sh_r": V(70, 0, 20), &"el_r": V(20),
		&"hip_l": V(95, 0, -15), &"kn_l": V(-120), &"ft_l": V(-30), &"hip_r": V(60, 0, 20), &"kn_r": V(-110), &"ft_r": V(-40)}
	_add(&"pin_atk", [[0, G], [10, PIN], [40, P(PIN, {&"spine": V(-58)})], [70, PIN]], true)
	_add(&"pinned", [[0, LYING], [8, P(LYING, {&"sh_l": V(10, 0, -40), &"kn_l": V(-40)})], [16, LYING]], true)

	# ---------------------------------------------------------- mystique
	var CHARGE := P(G, {&"pos": V(0, -0.16, 0), &"pelvis": V(0, -10), &"spine": V(-12, -10), &"sh_l": V(-35, 0, -22), &"el_l": V(95), &"sh_r": V(-35, 0, 22), &"el_r": V(95), &"head": V(0, 10)})
	var PUSH := P(G, {&"pos": V(0, -0.12, 0), &"pelvis": V(0, 0), &"spine": V(-8, 0), &"head": V(0, 0), &"sh_l": V(86, 8, -8), &"el_l": V(5), &"sh_r": V(86, -8, 8), &"el_r": V(5), &"hd_l": V(70), &"hd_r": V(70)})
	_add(&"cast_push", [[0, G], [9, CHARGE], [14, PUSH], [24, PUSH], [36, G]], false, Vector3i(14, 24, 36))
	var GROUND := P(SLAM, {&"sh_l": V(35, 0, -10), &"el_l": V(0), &"sh_r": V(35, 0, 10), &"el_r": V(0), &"spine": V(-55, 0), &"pos": V(0, -0.4, 0)})
	var RAISE := P(HAM_UP, {&"pos": V(0, 0.04, 0)})
	_add(&"cast_ground", [[0, G], [10, RAISE], [16, GROUND], [26, GROUND], [40, G]], false, Vector3i(16, 26, 40))
	var GATHER := P(G, {&"pos": V(0, -0.28, 0), &"pelvis": V(0), &"spine": V(-30, 0), &"head": V(-30, 0), &"sh_l": V(75, -35, -10), &"el_l": V(120), &"sh_r": V(75, 35, 10), &"el_r": V(120), &"hip_l": V(50, 0, -15), &"kn_l": V(-80), &"hip_r": V(50, 0, 15), &"kn_r": V(-80)})
	var BURST := P(STAND, {&"pos": V(0, 0.02, 0), &"spine": V(18), &"chest": V(10), &"head": V(25), &"sh_l": V(30, 0, -130), &"el_l": V(10), &"sh_r": V(30, 0, 130), &"el_r": V(10), &"hip_l": V(0, 0, -14), &"hip_r": V(0, 0, 14)})
	_add(&"transform", [[0, G], [16, GATHER], [36, GATHER], [42, BURST], [70, BURST], [80, G]])
	var RUSH := P(G, {&"pos": V(0, -0.15, 0), &"pelvis": V(0, 0), &"spine": V(-35, 0), &"head": V(25, 0), &"sh_l": V(-45, 0, -25), &"el_l": V(40), &"sh_r": V(-45, 0, 25), &"el_r": V(40), &"hip_l": V(60, 0, -5), &"kn_l": V(-70), &"hip_r": V(-30, 0, 5), &"kn_r": V(-50)})
	var RUSH_HIT := P(RUSH, {&"sh_r": V(90, 0, 5), &"el_r": V(0), &"spine": V(-20, 15)})
	_add(&"ult_rush", [[0, G], [16, RUSH], [30, RUSH_HIT], [40, RUSH_HIT], [74, G]], false, Vector3i(16, 34, 74))
	var JAB2 := P(JAB, {&"spine": V(-12, -8)})
	var LEAP := P(TUCK, {&"pos": V(0, 1.3, 0), &"sh_l": V(150, 0, -30), &"sh_r": V(150, 0, 30)})
	var OVER := P(HAM_UP, {&"pos": V(0, 1.75, 0), &"hip_l": V(70, 0, -8), &"kn_l": V(-100), &"hip_r": V(60, 0, 8), &"kn_r": V(-100)})
	var SMASH := P(GROUND, {&"pos": V(0, -0.36, 0)})
	_add(&"ult_atk", [[0, RUSH_HIT], [8, JAB2], [14, CROSS], [22, P(JAB, {&"pelvis": V(0, -45)})], [30, CROSS], [40, UPC], [50, CROUCH], [60, LEAP], [80, OVER], [95, SMASH], [118, SMASH], [134, BURST], [150, BURST]])
	var HANG := P(FLY, {&"pelvis": V(85), &"pos": V(0, 1.7, 0)})
	_add(&"ult_def", [[0, HIT_HI], [8, HIT_HI2], [14, HIT_HI], [22, HIT_MID], [30, HIT_HI2], [40, P(FLY, {&"pos": V(0, 0.6, 0)})], [60, P(HANG, {&"pos": V(0, 1.6, 0)})], [80, HANG], [95, LYING], [150, LYING2]])

	# ---------------------------------------------------------- entrées / victoires
	var FLEX := P(STAND, {&"chest": V(10), &"head": V(10), &"sh_l": V(0, 0, -92), &"el_l": V(0, 0, -95), &"sh_r": V(0, 0, 92), &"el_r": V(0, 0, 95), &"hip_l": V(0, 0, -10), &"hip_r": V(0, 0, 10)})
	var ROAR := P(FLEX, {&"head": V(30), &"chest": V(16)})
	var MUSC := P(STAND, {&"pos": V(0, -0.08, 0), &"spine": V(-15), &"chest": V(-8), &"head": V(-5), &"sh_l": V(30, 0, -40), &"el_l": V(105), &"sh_r": V(30, 0, 40), &"el_r": V(105), &"hip_l": V(0, 0, -14), &"hip_r": V(0, 0, 14), &"kn_l": V(-20), &"kn_r": V(-20)})
	_add(&"intro_flex", [[0, STAND], [20, FLEX], [55, FLEX], [70, ROAR], [95, ROAR], [110, MUSC], [150, MUSC], [170, G]])
	var D1 := P(STAND, {&"pelvis": V(0, 0, 10), &"spine": V(0, 0, -12), &"sh_l": V(40, 0, -110), &"el_l": V(40), &"sh_r": V(20, 0, 60), &"el_r": V(80), &"kn_l": V(-20)})
	var D2 := P(STAND, {&"pelvis": V(0, 0, -10), &"spine": V(0, 0, 12), &"sh_l": V(20, 0, -60), &"el_l": V(80), &"sh_r": V(40, 0, 110), &"el_r": V(40), &"kn_r": V(-20)})
	var POINT := P(STAND, {&"sh_r": V(95, 0, 6), &"el_r": V(0), &"head": V(0, 0), &"sh_l": V(0, 0, -35), &"el_l": V(0, 0, -100)})
	_add(&"intro_dance", [[0, STAND], [15, D1], [30, D2], [45, D1], [60, D2], [75, D1], [100, POINT], [150, POINT], [170, G]])
	var CROSSED := P(STAND, {&"head": V(12), &"chest": V(8), &"sh_l": V(70, -45, -10), &"el_l": V(110), &"sh_r": V(70, 45, 10), &"el_r": V(115)})
	var FIST_UP := P(STAND, {&"sh_r": V(178, 0, 12), &"el_r": V(12), &"head": V(20), &"chest": V(8)})
	_add(&"victory_chief", [[0, G], [25, FIST_UP], [80, FIST_UP], [105, CROSSED], [240, P(CROSSED, {&"head": V(16)})]])
	var SKY := P(STAND, {&"sh_r": V(170, 0, 20), &"el_r": V(0), &"head": V(28), &"sh_l": V(0, 0, -35), &"el_l": V(0, 0, -100), &"pelvis": V(0, 0, -5)})
	_add(&"victory_sky", [[0, G], [12, CROUCH], [22, P(SKY, {&"pos": V(0, 0.15, 0)})], [32, SKY], [80, SKY], [100, D1], [120, D2], [140, D1], [160, SKY], [240, SKY]])
	_add(&"victory_arms", [[0, G], [25, P(STAND, {&"sh_l": V(170, 0, -25), &"sh_r": V(170, 0, 25), &"head": V(20)})], [240, P(STAND, {&"sh_l": V(165, 0, -30), &"sh_r": V(165, 0, 30), &"head": V(20)})]])
