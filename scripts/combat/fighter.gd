## Logique d'un combattant : machine à états à 60 ticks/s, frame data,
## ressources (vie, endurance, énergie mystique), transformation.
## Aucun code de rendu ici : le FighterRig lit anim / anim_frame / anim_marks.
class_name Fighter
extends Node3D

signal event(kind: StringName, info: Dictionary)

enum S { INTRO, IDLE, WALK, JUMP, ATTACK, BLOCK, BLOCKSTUN, HITSTUN, STAGGER, RECOVER, KNOCKDOWN,
	GETUP, DODGE, GRAB_TRY, GRAB_ATK, GRABBED, CAST, TRANSFORM, PIN_ATK, PINNED, KO, VICTORY, DEFEAT }

const GRAVITY := 24.0
const DT := 1.0 / 60.0
const BUFFER := 8
const PARRY_WINDOW := 6

static var ULT_MOVE: MoveData

var data: FighterData
var index := 0
var opponent: Fighter
var arbiter  # Match : résolution des contacts, effets globaux
var rig: FighterRig

var hp := 100.0
var stamina := 100.0
var energy := 0.0
var state: int = S.IDLE
var sframe := 0
var move: MoveData
var move_connected := false
var evade_notified := false
var vel := Vector3.ZERO
var transformed := false
var transform_left := 0
var power_cd := 0
var invuln := 0
var counter_ready := 0
var block_press_tick := -999
var tick_count := 0
var combo_taken := 0
var juggle := 0
var exhausted := false
var stamina_delay := 0
var dodge_dir := Vector3.ZERO
var dodge_alt := 1.0
var grab_seq: Dictionary = {}
var grab_kind: StringName = &""
var partner: Fighter
var kd_phase := 0
var stun_len := 0
var push_vec := Vector3.ZERO
var push_frames := 0
var mash := 0
var infinite_energy := false
var last_damage := 0.0

# --- État exposé au rendu
var anim: StringName = &"idle"
var anim_frame := 0.0
var anim_marks := Vector3i.ZERO
var anim_frozen := false

var cmd := FighterCmd.new()
var _buf: Dictionary = {}
var _prev_block := false

static func ult_move() -> MoveData:
	if ULT_MOVE == null:
		var m := MoveData.new()
		m.id = &"ult_rush"
		m.display_name = "Charge ultime"
		m.anim = &"ult_rush"
		m.startup = 16
		m.active = 18
		m.recovery = 40
		m.damage = 6.0
		m.hit_stun = 30
		m.block_stun = 22
		m.push = 0.6
		m.hitbox_offset = Vector3(0, 1.3, -0.75)
		m.hitbox_radius = 0.42
		m.lunge = 3.6
		m.hitstop = 10
		m.shake = 0.5
		m.stamina_cost = 0.0
		ULT_MOVE = m
	return ULT_MOVE

func setup(d: FighterData, idx: int) -> void:
	data = d
	index = idx
	hp = d.max_hp
	stamina = d.max_stamina

# ================================================================ utilitaires
func fwd() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0
	return f.normalized()

func right() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0
	return r.normalized()

func flat_dist(o: Node3D) -> float:
	var d := o.position - position
	d.y = 0
	return d.length()

func dmg_mult() -> float:
	return data.power_mult * (data.transform_damage_mult if transformed else 1.0)

func speed_mult() -> float:
	return (data.transform_speed_mult if transformed else 1.0) * (0.75 if exhausted else 1.0)

func hp_ratio() -> float:
	return hp / data.max_hp

func is_lying() -> bool:
	return (state == S.KNOCKDOWN and kd_phase >= 1) or state == S.PINNED or (state == S.KO and position.y <= 0.01)

func is_invulnerable() -> bool:
	if invuln > 0:
		return true
	if state == S.DODGE and sframe >= 2 and sframe <= 13:
		return true
	return state in [S.GETUP, S.TRANSFORM, S.INTRO, S.VICTORY, S.DEFEAT, S.GRAB_ATK, S.GRABBED, S.PIN_ATK, S.PINNED, S.KO]

func can_be_struck() -> bool:
	if is_invulnerable() or is_lying():
		return false
	if state == S.KNOCKDOWN and juggle >= 2:
		return false
	return true

func can_be_grabbed() -> bool:
	return not is_invulnerable() and not is_lying() and position.y < 0.05 and state not in [S.KNOCKDOWN, S.JUMP]

func can_be_pinned() -> bool:
	return state == S.KNOCKDOWN and kd_phase >= 1 and sframe > 6

func is_hit_active() -> bool:
	if state != S.ATTACK or move == null or move_connected:
		return false
	return move.is_active(sframe)

func in_startup() -> bool:
	return (state == S.ATTACK and move != null and sframe <= move.startup) or (state == S.CAST and sframe < data.power.startup) or (state == S.GRAB_TRY and sframe < 8)

func in_recovery() -> bool:
	if state == S.ATTACK and move != null:
		return sframe > move.startup + move.active
	if state == S.CAST:
		return sframe > data.power.startup
	if state == S.GRAB_TRY:
		return sframe > 10
	if state == S.DODGE:
		return sframe > 13
	return state in [S.RECOVER, S.STAGGER]

func is_neutral() -> bool:
	return state in [S.IDLE, S.WALK, S.BLOCK]

func hurtboxes() -> Array:
	var h := data.height
	var p := position
	if state == S.KNOCKDOWN or (state == S.KO and p.y > 0.01):
		return [[p + Vector3(0, 0.55, 0), p + Vector3(0, 1.25, 0), 0.36]]
	var top := 1.42 * h
	if state == S.DODGE:
		top = 1.15 * h
	return [[p + Vector3(0, 0.22, 0), p + Vector3(0, top, 0), 0.27 * data.bulk], [p + Vector3(0, top + 0.18 * h, 0), p + Vector3(0, top + 0.2 * h, 0), 0.14]]

func hitbox_world() -> Vector3:
	return global_transform * move.hitbox_offset

func _consume(a: StringName) -> bool:
	if _buf.has(a):
		_buf.erase(a)
		return true
	return false

func _enter(s: int, anim_id: StringName) -> void:
	state = s
	sframe = 0
	anim = anim_id
	anim_frame = 0.0
	anim_marks = Vector3i.ZERO
	if s == S.IDLE or s == S.WALK:
		combo_taken = 0
		juggle = 0

func _set_loop_anim(anim_id: StringName) -> void:
	if anim != anim_id:
		anim = anim_id
		anim_frame = 0.0
		anim_marks = Vector3i.ZERO
	else:
		anim_frame += 1.0

func _track(rate := 1.0) -> void:
	if opponent == null:
		return
	var d := opponent.position - position
	d.y = 0
	if d.length() < 0.05:
		return
	var target := atan2(-d.x, -d.z)
	var diff := angle_difference(rotation.y, target)
	var mx := deg_to_rad(14.0) * rate
	rotation.y += clampf(diff, -mx, mx)

func face_now() -> void:
	var d := opponent.position - position
	d.y = 0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)

func _air(gravity_scale := 1.0) -> bool:
	vel.y -= GRAVITY * gravity_scale * DT
	position += vel * DT
	if position.y <= 0.0 and vel.y <= 0.0:
		position.y = 0.0
		vel = Vector3.ZERO
		return true
	return false

func _emit(kind: StringName, info := {}) -> void:
	event.emit(kind, info)

# ================================================================ tick
func tick(c: FighterCmd) -> void:
	cmd = c
	tick_count += 1
	sframe += 1
	for a in c.pressed:
		_buf[a] = BUFFER
	if c.block and not _prev_block:
		block_press_tick = tick_count
	_prev_block = c.block
	if invuln > 0:
		invuln -= 1
	if power_cd > 0:
		power_cd -= 1
	if counter_ready > 0:
		counter_ready -= 1
	_resources()
	match state:
		S.IDLE, S.WALK:
			_neutral()
		S.JUMP:
			_st_jump()
		S.ATTACK:
			_st_attack()
		S.BLOCK:
			_st_block()
		S.BLOCKSTUN, S.HITSTUN, S.STAGGER, S.RECOVER:
			_st_stun()
		S.KNOCKDOWN:
			_st_knockdown()
		S.GETUP:
			anim_frame = sframe
			if sframe >= 26:
				_enter(S.IDLE, &"idle")
		S.DODGE:
			_st_dodge()
		S.GRAB_TRY:
			_st_grab_try()
		S.GRAB_ATK:
			_st_grab_atk()
		S.GRABBED:
			_st_grabbed()
		S.CAST:
			_st_cast()
		S.TRANSFORM:
			_st_transform()
		S.PIN_ATK:
			_st_pin_atk()
		S.PINNED:
			_st_pinned()
		S.KO:
			if position.y > 0.0 or vel.y > 0.0:
				_air()
			anim_frame = sframe
		_:
			anim_frame = sframe
	for a in _buf.keys():
		_buf[a] -= 1
		if _buf[a] <= 0:
			_buf.erase(a)
	if push_frames > 0:
		push_frames -= 1
		position += push_vec

func _resources() -> void:
	if stamina_delay > 0:
		stamina_delay -= 1
	var regen := 5.0 if (stamina_delay > 0 or state == S.BLOCK) else 22.0
	stamina = minf(data.max_stamina, stamina + regen * DT)
	if stamina <= 0.5:
		exhausted = true
	elif stamina > 35.0:
		exhausted = false
	if infinite_energy and not transformed:
		energy = 100.0
	if transformed:
		if state != S.GRAB_ATK and state != S.TRANSFORM:
			transform_left -= 1
			if transform_left <= 0 and not (state == S.ATTACK and move == ult_move()):
				_end_transform()
	elif state not in [S.INTRO, S.VICTORY, S.DEFEAT, S.KO]:
		energy = minf(100.0, energy + 1.25 * DT)

func gain_energy(v: float) -> void:
	if not transformed:
		energy = clampf(energy + v, 0.0, 100.0)

func spend_stamina(v: float) -> void:
	stamina = maxf(0.0, stamina - v)
	stamina_delay = 40

# ================================================================ neutre
func _neutral() -> void:
	_track(1.0)
	if _try_actions():
		return
	if cmd.block:
		_enter(S.BLOCK, &"block")
		return
	var d := cmd.dir
	if d.length() > 0.2:
		var f := fwd()
		var r := right()
		var along := d.dot(f)
		var side := d.dot(r)
		var v := f * along * (data.walk_speed if along > 0.0 else data.back_speed) + r * side * data.side_speed
		position += v * speed_mult() * DT
		state = S.WALK
		var a := &"walk_f" if along > 0.35 else (&"walk_b" if along < -0.35 else &"side")
		_set_loop_anim(a)
	else:
		if state != S.IDLE:
			state = S.IDLE
		_set_loop_anim(&"idle")

func _try_actions() -> bool:
	if _consume(&"ultimate"):
		if transformed:
			_start_move(ult_move())
			return true
		elif energy >= 100.0:
			_start_transform()
			return true
		_emit(&"denied", {"what": "ultimate"})
	if _consume(&"power"):
		if data.power and energy >= data.power.energy_cost and power_cd == 0:
			_start_cast()
			return true
		_emit(&"denied", {"what": "power"})
	if _consume(&"jump"):
		_start_jump()
		return true
	if _consume(&"dodge"):
		if stamina >= 12.0 and not exhausted:
			_start_dodge()
			return true
		_emit(&"denied", {"what": "dodge"})
	if _consume(&"grab"):
		if opponent.can_be_pinned() and flat_dist(opponent) < 2.0:
			arbiter.start_pin(self, opponent)
			return true
		_start_grab()
		return true
	var fwd_held := cmd.dir.dot(fwd()) > 0.6
	if _consume(&"punch"):
		_start_move(data.move(&"heavy" if fwd_held else &"jab"))
		return true
	if _consume(&"kick"):
		_start_move(data.move(&"spin_kick" if fwd_held else &"kick_mid"))
		return true
	return false

# ================================================================ attaques
func _start_move(m: MoveData) -> void:
	move = m
	move_connected = false
	evade_notified = false
	spend_stamina(m.stamina_cost)
	_enter(S.ATTACK, m.anim)
	anim_marks = Vector3i(m.startup, m.startup + m.active, m.total_frames())
	if m == ult_move():
		_emit(&"ult_rush", {})
	else:
		_emit(&"whoosh", {})

func _st_attack() -> void:
	var m := move
	if m.aerial:
		if _air():
			if sframe <= m.startup + m.active:
				sframe = m.startup + m.active
				anim_marks = Vector3i(m.startup, sframe, sframe + m.recovery)
			_emit(&"land", {"soft": true})
	else:
		if sframe <= maxi(2, m.startup / 2):
			_track(0.7)
		if m.lunge > 0.0 and sframe <= m.startup + m.active:
			position += fwd() * (m.lunge / float(m.startup + m.active)) * (speed_mult() if m == ult_move() else 1.0)
	anim_frame = sframe
	# enchaînements (strings)
	if not m.chain.is_empty() and sframe > m.startup:
		var open_from := m.startup + 1 if move_connected else m.startup + m.active
		if sframe >= open_from and sframe <= m.startup + m.active + m.cancel_late:
			for a in m.chain:
				if _buf.has(a):
					_buf.erase(a)
					_start_move(data.move(m.chain[a]))
					return
	if m.aerial and sframe > m.startup + m.active and position.y > 0.0:
		return
	if sframe >= anim_marks.z:
		if m == ult_move():
			_end_transform()
		_enter(S.IDLE, &"idle")

func on_move_connected() -> void:
	move_connected = true

# ================================================================ saut
func _start_jump() -> void:
	_enter(S.JUMP, &"jump")
	var d := cmd.dir
	vel = Vector3(d.x, 0, d.z) * 2.4 * speed_mult()
	spend_stamina(4.0)

func _st_jump() -> void:
	anim_frame = sframe
	if sframe < 4:
		return
	if sframe == 4:
		vel.y = data.jump_velocity
		position.y = 0.01
		return
	if _consume(&"kick"):
		_start_move(data.move(&"air_kick"))
		return
	if _consume(&"punch"):
		_start_move(data.move(&"air_elbow"))
		return
	if _air():
		_emit(&"land", {"soft": true})
		_recover(7, &"land")

func _recover(frames: int, anim_id: StringName) -> void:
	_enter(S.RECOVER, anim_id)
	stun_len = frames

# ================================================================ défense
func _st_block() -> void:
	_track(1.0)
	_set_loop_anim(&"block")
	if _consume(&"dodge") and stamina >= 12.0 and not exhausted:
		_start_dodge()
		return
	if not cmd.block:
		_enter(S.IDLE, &"idle")

func _st_stun() -> void:
	anim_frame = sframe
	if sframe >= stun_len:
		if state == S.BLOCKSTUN and cmd.block:
			_enter(S.BLOCK, &"block")
		else:
			_enter(S.IDLE, &"idle")

func _start_dodge() -> void:
	spend_stamina(12.0)
	var along := cmd.dir.dot(fwd())
	var side := cmd.dir.dot(right())
	if along < -0.5 and absf(side) < 0.5:
		dodge_dir = -fwd()
		_enter(S.DODGE, &"dodge_back")
	else:
		var sgn := signf(side) if absf(side) > 0.2 else dodge_alt
		dodge_alt = -dodge_alt
		dodge_dir = right() * sgn
		_enter(S.DODGE, &"dodge")
	anim_marks = Vector3i(4, 14, 22)
	_emit(&"dodge", {})

func _st_dodge() -> void:
	anim_frame = sframe
	if sframe <= 14:
		position += dodge_dir * (1.2 / 14.0) * speed_mult()
		if dodge_dir.dot(fwd()) > -0.5:
			_track(0.6)
	if sframe >= 22:
		_enter(S.IDLE, &"idle")

## Réception d'un coup (appelée par l'arbitre après résolution).
func receive_hit(attacker: Fighter, m: MoveData, dmg: float, hit_height: float) -> void:
	last_damage = dmg
	hp = maxf(0.0, hp - dmg)
	gain_energy(dmg * 0.45)
	combo_taken += 1
	if rig:
		rig.flash(1.0)
	var away := attacker.fwd()
	if state == S.KNOCKDOWN:
		juggle += 1
	if hp <= 0.0:
		_enter(S.KO, &"ko_fall")
		vel = away * 3.0 + Vector3.UP * 4.0
		position.y = maxf(position.y, 0.02)
		return
	if m.launches or state == S.KNOCKDOWN or position.y > 0.05:
		_enter(S.KNOCKDOWN, &"knock_fly")
		kd_phase = 0
		var lv := m.launch_velocity if m.launches else Vector3(0, 3.0, 2.0)
		vel = away * lv.z + Vector3.UP * lv.y * (0.7 if juggle > 0 else 1.0)
		position.y = maxf(position.y, 0.02)
		return
	_enter(S.HITSTUN, &"hit_mid" if hit_height < 1.2 else (&"hit_high" if combo_taken % 2 == 1 else &"hit_high2"))
	stun_len = m.hit_stun
	push_vec = away * (m.push / 6.0)
	push_frames = 6

func receive_block(attacker: Fighter, m: MoveData, chip: float) -> void:
	hp = maxf(1.0, hp - chip)
	spend_stamina(m.damage * 0.9)
	gain_energy(2.0)
	if stamina <= 0.0:
		_enter(S.STAGGER, &"stagger")
		stun_len = 40
		_emit(&"guard_break", {})
		return
	_enter(S.BLOCKSTUN, &"blockstun")
	stun_len = m.block_stun
	push_vec = attacker.fwd() * (m.push * 1.2 / 6.0)
	push_frames = 6

func stagger(frames: int) -> void:
	_enter(S.STAGGER, &"stagger")
	stun_len = frames

func _st_knockdown() -> void:
	if kd_phase == 0:
		anim = &"knock_fly"
		anim_frame = sframe
		if _air():
			kd_phase = 1
			sframe = 0
			anim = &"knock_land"
			anim_frame = 0
			_emit(&"land", {"soft": false})
		return
	anim_frame = sframe
	if sframe > 14 and anim == &"knock_land":
		anim = &"lying"
		anim_frame = 0
	var pressed_any := not cmd.pressed.is_empty()
	if sframe >= 55 or (sframe > 24 and pressed_any):
		_enter(S.GETUP, &"getup")

func set_lying(frames_in := 0) -> void:
	_enter(S.KNOCKDOWN, &"lying")
	kd_phase = 1
	sframe = frames_in
	position.y = 0.0
	vel = Vector3.ZERO

# ================================================================ prises
func _start_grab() -> void:
	grab_kind = &"throw" if cmd.dir.length() > 0.5 else &"slam"
	spend_stamina(10.0)
	_enter(S.GRAB_TRY, &"grab_try")
	anim_marks = Vector3i(7, 10, 30)

func _st_grab_try() -> void:
	anim_frame = sframe
	if sframe <= 4:
		_track(0.6)
	if sframe >= 8 and sframe <= 10:
		if arbiter.try_grab(self, grab_kind):
			return
	if sframe >= 30:
		_enter(S.IDLE, &"idle")

func begin_grab_sequence(victim: Fighter, kind: StringName) -> void:
	grab_kind = kind
	grab_seq = GrabLib.SEQS[kind]
	partner = victim
	_enter(S.GRAB_ATK, grab_seq.atk_anim)
	victim.partner = self
	victim.grab_seq = grab_seq
	victim._enter(S.GRABBED, grab_seq.def_anim)
	victim.anim_frozen = false
	victim.face_now()
	face_now()

func _st_grab_atk() -> void:
	var seq := grab_seq
	anim_frame = sframe
	var off := GrabLib.offset_at(seq, sframe)
	partner.position = position + fwd() * off
	partner.position.y = 0.0
	partner.face_now()
	partner.sframe = sframe
	partner.anim_frame = sframe
	if seq.has("hits"):
		for h in seq.hits:
			if sframe == h[0]:
				arbiter.apply_sequence_hit(self, partner, data.ultimate_damage * h[1] * dmg_mult(), h == seq.hits[seq.hits.size() - 1])
	elif sframe == seq.hit_frame:
		arbiter.apply_sequence_hit(self, partner, seq.damage * dmg_mult(), true)
	if sframe >= seq.length:
		var victim := partner
		if grab_kind == &"ultimate":
			_end_transform()
		_enter(S.IDLE, &"idle")
		partner = null
		if victim.hp <= 0.0:
			victim._enter(S.KO, &"lying")
		else:
			victim.set_lying(10)
		victim.partner = null

func _st_grabbed() -> void:
	if grab_seq.get("tech_window", 0) > 0 and sframe <= grab_seq.tech_window and _consume(&"grab"):
		arbiter.grab_tech(partner, self)

# ================================================================ immobilisation (tombé)
func start_pin(victim: Fighter) -> void:
	partner = victim
	_enter(S.PIN_ATK, &"pin_atk")
	var side := victim.right()
	position = victim.position + side * 0.55
	position.y = 0.0
	victim.partner = self
	victim._enter(S.PINNED, &"pinned")
	victim.mash = 0
	var d := victim.position - position
	rotation.y = atan2(-d.x, -d.z)

func _st_pin_atk() -> void:
	_set_loop_anim(&"pin_atk")
	if sframe % 50 == 0 and sframe > 0:
		arbiter.pin_count(self, sframe / 50)
	if sframe >= 150:
		arbiter.pin_win(self, partner)

func pin_threshold() -> int:
	return 3 + int(12.0 * (1.0 - hp_ratio()))

func _st_pinned() -> void:
	_set_loop_anim(&"pinned")
	mash += cmd.pressed.size()
	var auto_escape := hp_ratio() > 0.35 and sframe >= 70
	if mash >= pin_threshold() or auto_escape:
		arbiter.pin_escape(partner, self)

func escape_pin() -> void:
	partner = null
	_enter(S.GETUP, &"getup")
	invuln = 20

# ================================================================ mystique
func _start_cast() -> void:
	var p := data.power
	energy -= p.energy_cost
	power_cd = p.cooldown
	var a := &"cast_ground" if p.kind == PowerData.Kind.SHOCKWAVE else &"cast_push"
	_enter(S.CAST, a)
	anim_marks = Vector3i(p.startup, p.startup + 10, p.startup + p.recovery)
	_emit(&"cast_start", {})

func _st_cast() -> void:
	var p := data.power
	anim_frame = sframe
	if sframe < p.startup - 4:
		_track(1.0)
	if sframe == p.startup:
		arbiter.spawn_power(self, p)
	if sframe >= p.startup + p.recovery:
		_enter(S.IDLE, &"idle")

func _start_transform() -> void:
	energy = 0.0
	_enter(S.TRANSFORM, &"transform")
	arbiter.begin_cinematic(self, &"transform", 80)
	_emit(&"transform_start", {})

func _st_transform() -> void:
	anim_frame = sframe
	if sframe == 40:
		transformed = true
		transform_left = data.transform_frames
		_emit(&"transform_burst", {})
	if sframe >= 80:
		_enter(S.IDLE, &"idle")
		arbiter.end_cinematic(self)

func _end_transform() -> void:
	if transformed:
		transformed = false
		transform_left = 0
		_emit(&"transform_end", {})

func transform_ratio() -> float:
	return float(transform_left) / float(maxi(1, data.transform_frames))

# ================================================================ présentation
func play_presentation(s: int, anim_id: StringName) -> void:
	_enter(s, anim_id if AnimLib.has_anim(anim_id) else &"stand")
