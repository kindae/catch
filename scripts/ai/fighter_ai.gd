## IA de combat. Produit des FighterCmd comme un joueur (même règles, aucune triche
## sur la frame data). Perception retardée selon la difficulté (temps de réaction),
## gestion de la distance, défense, esquive, combos, prises, punitions, énergie.
class_name FighterAI
extends RefCounted

enum Level { EASY, NORMAL, HARD, MASTER }

const PROFILES := {
	Level.EASY: {"react": 26, "block": 0.18, "dodge": 0.08, "aggr": 0.35, "combo": 0.25, "punish": 0.1,
		"grab": 0.12, "tech": 0.05, "power": 0.25, "mash": 0.08, "think": 18, "parry": 0.0},
	Level.NORMAL: {"react": 16, "block": 0.42, "dodge": 0.25, "aggr": 0.55, "combo": 0.55, "punish": 0.4,
		"grab": 0.3, "tech": 0.22, "power": 0.5, "mash": 0.18, "think": 12, "parry": 0.05},
	Level.HARD: {"react": 10, "block": 0.65, "dodge": 0.45, "aggr": 0.68, "combo": 0.8, "punish": 0.7,
		"grab": 0.5, "tech": 0.45, "power": 0.7, "mash": 0.3, "think": 8, "parry": 0.15},
	Level.MASTER: {"react": 6, "block": 0.82, "dodge": 0.65, "aggr": 0.78, "combo": 0.95, "punish": 0.92,
		"grab": 0.65, "tech": 0.7, "power": 0.85, "mash": 0.45, "think": 5, "parry": 0.3},
}

var me: Fighter
var level: int = Level.NORMAL
var p: Dictionary
var enabled := true
## Mode mannequin (entraînement) : 0 = IA, 1 = immobile, 2 = garde, 3 = esquive
var dummy_mode := 0

var _rng := RandomNumberGenerator.new()
var _history: Array = []
var _think := 0
var _intent := &"approach"
var _intent_frames := 0
var _strafe := 1.0
var _hold_block := 0
var _cmd := FighterCmd.new()
var _pending_chain: StringName = &""

func setup(f: Fighter, lvl: int) -> void:
	me = f
	level = clampi(lvl, 0, 3)
	p = PROFILES[level]
	_rng.randomize()

## Instantané observable de l'adversaire (ce que verrait un joueur).
func _snapshot() -> Dictionary:
	var o := me.opponent
	return {
		"state": o.state, "startup": o.in_startup(), "recovery": o.in_recovery(),
		"attacking": o.state == Fighter.S.ATTACK or o.state == Fighter.S.CAST or o.state == Fighter.S.GRAB_TRY,
		"casting": o.state == Fighter.S.CAST, "grab": o.state == Fighter.S.GRAB_TRY,
		"blocking": o.state == Fighter.S.BLOCK, "lying": o.can_be_pinned(), "ult": o.state == Fighter.S.ATTACK and o.move == Fighter.ult_move(),
		"dist": me.flat_dist(o), "hp": o.hp_ratio(), "air": o.position.y > 0.1,
	}

func next_cmd(projectiles: Array) -> FighterCmd:
	_cmd.clear()
	if not enabled or me.opponent == null:
		return _cmd
	_history.append(_snapshot())
	while _history.size() > p.react + 1:
		_history.pop_front()
	var seen: Dictionary = _history[0]
	if dummy_mode != 0:
		return _dummy(seen)
	match me.state:
		Fighter.S.GRABBED:
			if me.sframe <= 10 and me.sframe == int(p.react * 0.5) and _rng.randf() < p.tech:
				_cmd.press(&"grab")
			return _cmd
		Fighter.S.PINNED:
			if _rng.randf() < p.mash:
				_cmd.press(&"punch")
			return _cmd
		Fighter.S.KNOCKDOWN:
			if _rng.randf() < 0.05:
				_cmd.press(&"punch")
			return _cmd
		Fighter.S.ATTACK:
			_continue_combo()
			return _cmd
	if not me.is_neutral() and me.state != Fighter.S.JUMP:
		return _cmd
	var d: float = seen.dist
	var to_opp := me.fwd()
	var side := me.right()
	# --- défense : projectiles
	for pr in projectiles:
		var proj: Projectile = pr
		if proj.owner_f != me and proj.alive:
			var dd := (proj.pos - me.position)
			dd.y = 0
			if dd.length() < 3.2 and _rng.randf() < p.dodge * 0.25:
				_cmd.dir = side * _strafe
				_cmd.press(&"dodge")
				return _cmd
			if dd.length() < 2.2 and _rng.randf() < p.block * 0.3:
				_cmd.block = true
				return _cmd
	# --- défense : attaques vues (avec retard de réaction)
	if seen.ult and d < 4.5 and _rng.randf() < p.dodge:
		_cmd.dir = side * _strafe
		_cmd.press(&"dodge")
		return _cmd
	if seen.attacking and seen.startup and d < 2.2 and not seen.grab:
		if _hold_block > 0 or _rng.randf() < p.block * 0.35:
			_hold_block = 14
		elif _rng.randf() < p.dodge * 0.08:
			_cmd.dir = side * _strafe
			_cmd.press(&"dodge")
			return _cmd
	if _hold_block > 0:
		_hold_block -= 1
		_cmd.block = true
		if _rng.randf() < p.parry * 0.1:
			_cmd.block = false
		return _cmd
	# --- punition : adversaire en récupération proche
	if seen.recovery and d < 1.6 and _rng.randf() < p.punish * 0.4:
		_attack(d, true)
		return _cmd
	# --- adversaire au sol : tombé
	if seen.lying and d < 1.9 and seen.hp < 0.4 and _rng.randf() < 0.3:
		_cmd.press(&"grab")
		return _cmd
	# --- énergie
	if me.energy >= 100.0 and not me.transformed and d > 1.6 and _rng.randf() < p.power * 0.08:
		_cmd.press(&"ultimate")
		return _cmd
	if me.transformed and d < 3.6 and d > 1.0 and _rng.randf() < p.power * 0.04:
		_cmd.press(&"ultimate")
		return _cmd
	if me.data.power and me.energy >= me.data.power.energy_cost and me.power_cd == 0 and d > 1.9 and _rng.randf() < p.power * 0.06:
		_cmd.press(&"power")
		return _cmd
	# --- décision périodique
	_think -= 1
	if _think <= 0:
		_think = p.think + _rng.randi_range(0, p.think)
		_decide(d, seen)
	match _intent:
		&"approach":
			_cmd.dir = to_opp
			if d < 1.25:
				_intent = &"attack"
		&"retreat":
			_cmd.dir = -to_opp
		&"circle":
			_cmd.dir = side * _strafe + to_opp * (0.4 if d > 1.6 else -0.2)
		&"wait":
			if d > 1.9:
				_cmd.dir = to_opp * 0.6
		&"attack":
			if d < 1.35:
				_attack(d, false)
				_intent = &"wait"
			else:
				_cmd.dir = to_opp
		&"jump_in":
			if d < 3.2 and d > 1.6:
				_cmd.dir = to_opp
				_cmd.press(&"jump")
				_intent = &"air"
			else:
				_cmd.dir = to_opp
	if me.state == Fighter.S.JUMP and me.sframe > 10 and d < 1.6:
		_cmd.press(&"kick" if _rng.randf() < 0.6 else &"punch")
	return _cmd

func _decide(d: float, seen: Dictionary) -> void:
	var r := _rng.randf()
	if me.exhausted:
		_intent = &"retreat"
		return
	if d > 2.2:
		if r < p.aggr:
			_intent = &"approach"
		elif r < p.aggr + 0.1:
			_intent = &"jump_in"
		else:
			_intent = &"circle"
			_strafe = -_strafe if _rng.randf() < 0.4 else _strafe
	else:
		if r < p.aggr:
			_intent = &"attack"
		elif r < p.aggr + 0.15:
			_intent = &"circle"
		elif r < p.aggr + 0.25:
			_intent = &"retreat"
		else:
			_intent = &"wait"

func _attack(d: float, punish: bool) -> void:
	var r := _rng.randf()
	var opp_blocking: bool = _history[0].blocking
	if (opp_blocking and r < p.grab) or (not opp_blocking and r < p.grab * 0.25):
		if d < 1.1:
			if _rng.randf() < 0.5:
				_cmd.dir = me.fwd()
			_cmd.press(&"grab")
			return
	r = _rng.randf()
	if punish and r < 0.5:
		_cmd.press(&"punch")
		_pending_chain = &"punch"
		return
	if r < 0.4:
		_cmd.press(&"punch")
		_pending_chain = &"punch" if _rng.randf() < 0.6 else &"kick"
	elif r < 0.7:
		_cmd.press(&"kick")
		_pending_chain = &"kick"
	elif r < 0.85:
		_cmd.dir = me.fwd()
		_cmd.press(&"punch")
		_pending_chain = &""
	else:
		_cmd.dir = me.fwd()
		_cmd.press(&"kick")
		_pending_chain = &""

func _continue_combo() -> void:
	var m := me.move
	if m == null or m.chain.is_empty() or _pending_chain == &"":
		return
	if me.sframe == m.startup + m.active - 1:
		if (me.move_connected or _rng.randf() < 0.4) and _rng.randf() < p.combo:
			if m.chain.has(_pending_chain):
				_cmd.press(_pending_chain)
				var keys := m.chain.keys()
				_pending_chain = keys[_rng.randi() % keys.size()]
		else:
			_pending_chain = &""

func _dummy(seen: Dictionary) -> FighterCmd:
	match dummy_mode:
		2:
			_cmd.block = true
		3:
			if seen.attacking and seen.startup and seen.dist < 2.0 and me.is_neutral():
				_cmd.dir = me.right()
				_cmd.press(&"dodge")
	if me.state == Fighter.S.GRABBED and _rng.randf() < 0.0:
		_cmd.press(&"grab")
	return _cmd
