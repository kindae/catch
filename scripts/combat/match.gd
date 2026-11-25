## Gestionnaire de combat (« arbitre ») : construit la scène, distribue les
## commandes, résout les contacts hitbox/hurtbox, gère manches, chrono,
## cinématiques (transformation, ultime, finition), ralentis et effets.
## Toute la logique tourne dans step() à 60 Hz fixes, indépendante du rendu.
class_name Match
extends Node3D

signal finished(result: Dictionary)
signal pause_requested

enum Phase { INTRO, ROUND_START, FIGHT, ROUND_END, MATCH_END }

const DT := 1.0 / 60.0
const ROUND_FRAMES := 99 * 60

var headless := false
var training := false
var ai_vs_ai := false
var rounds_to_win := 2

var arena: ArenaBase
var fighters: Array[Fighter] = []
var camera: FightCamera
var vfx: Vfx
var hud: Hud
var touch: TouchControls
var ui_layer: CanvasLayer
var player_input: PlayerInput
var ais: Array = [null, null]
var projectiles: Array[Projectile] = []

var phase: int = Phase.INTRO
var phase_t := 0
var round_num := 1
var wins := [0, 0]
var timer_frames := ROUND_FRAMES
var hitstop := 0
var cine_owner: Fighter
var slowmo_frames := 0
var excitement := 0.3
var finisher_pending := false
var last_hit_tick := [0, 0]
var tick := 0
var round_winner := -1
var end_reason := ""
var stats := {"hits": [0, 0], "damage": [0.0, 0.0], "max_combo": [0, 0], "parries": [0, 0], "grabs": [0, 0], "powers": [0, 0], "transforms": [0, 0], "ults": [0, 0], "ticks": 0}
var logic_usec_total := 0
var logic_usec_max := 0

var _orb_pool: Array[Node3D] = []
var _wave_pool: Array[Node3D] = []
var _power_moves: Dictionary = {}
var _debug_mesh: MeshInstance3D
var _imm: ImmediateMesh
var _empty_cmd := FighterCmd.new()

# =============================================================== construction
func setup(p1: FighterData, p2: FighterData, c1: int, c2: int, ai_level: int, is_training := false, both_ai := false, no_render := false) -> void:
	training = is_training
	ai_vs_ai = both_ai
	headless = no_render
	rounds_to_win = Game.rounds_to_win
	if not headless:
		arena = KinshasaRing.new()
		add_child(arena)
	else:
		arena = ArenaBase.new()
		add_child(arena)
	var datas := [p1, p2]
	var costumes := [c1, c2]
	for i in 2:
		var ft := Fighter.new()
		ft.name = "Fighter%d" % (i + 1)
		ft.setup(datas[i], i)
		ft.arbiter = self
		add_child(ft)
		fighters.append(ft)
		if not headless:
			var rig := FighterRig.new()
			ft.add_child(rig)
			rig.setup(ft, datas[i], costumes[i])
			ft.rig = rig
		ft.event.connect(_on_fighter_event.bind(ft))
	fighters[0].opponent = fighters[1]
	fighters[1].opponent = fighters[0]
	for i in 2:
		if i == 1 or ai_vs_ai:
			var ai := FighterAI.new()
			ai.setup(fighters[i], ai_level)
			ais[i] = ai
	if training:
		fighters[0].infinite_energy = false
	if not headless:
		camera = FightCamera.new()
		add_child(camera)
		camera.current = true
		vfx = Vfx.new()
		add_child(vfx)
		_build_ui()
		_build_pools()
		_imm = ImmediateMesh.new()
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.mesh = _imm
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.vertex_color_use_as_albedo = true
		dm.no_depth_test = true
		_debug_mesh.material_override = dm
		_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_debug_mesh)
	player_input = PlayerInput.new()
	player_input.camera = camera
	player_input.touch = touch
	_reset_positions()
	if camera:
		camera.setup(fighters[0], fighters[1])
	if training:
		_start_phase(Phase.ROUND_START)
	else:
		_start_phase(Phase.INTRO)
	if not headless:
		Sfx.play_crowd(true)
		Sfx.play_music(true)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	hud = Hud.new()
	hud.match_ref = self
	hud.f = [fighters[0], fighters[1]]
	ui_layer.add_child(hud)
	hud.pause_requested.connect(func(): pause_requested.emit())
	if Settings.touch_enabled() and not ai_vs_ai:
		touch = TouchControls.new()
		touch.fighter = fighters[0]
		ui_layer.add_child(touch)

func _build_pools() -> void:
	var fx_shader := preload("res://shaders/fx_add.gdshader")
	for i in 4:
		var orb := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.28
		s.height = 0.56
		s.radial_segments = 16
		s.rings = 8
		orb.mesh = s
		var m := ShaderMaterial.new()
		m.shader = fx_shader
		m.set_shader_parameter("mode", 1)
		orb.material_override = m
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.visible = false
		var trail := CPUParticles3D.new()
		trail.amount = int(24 * Settings.profile().particles)
		trail.lifetime = 0.35
		trail.local_coords = false
		trail.gravity = Vector3.ZERO
		trail.initial_velocity_min = 0.2
		trail.initial_velocity_max = 0.8
		trail.spread = 180
		var q := QuadMesh.new()
		q.size = Vector2(0.18, 0.18)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.vertex_color_use_as_albedo = true
		qm.albedo_texture = FxTextures.soft_dot()
		q.material = qm
		trail.mesh = q
		trail.emitting = false
		trail.name = "Trail"
		orb.add_child(trail)
		add_child(orb)
		_orb_pool.append(orb)
	for i in 3:
		var w := MeshInstance3D.new()
		var qq := QuadMesh.new()
		qq.size = Vector2(1.4, 0.9)
		qq.orientation = PlaneMesh.FACE_Y
		w.mesh = qq
		var m2 := ShaderMaterial.new()
		m2.shader = fx_shader
		m2.set_shader_parameter("mode", 0)
		w.material_override = m2
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.visible = false
		var flame := CPUParticles3D.new()
		flame.amount = int(30 * Settings.profile().particles)
		flame.lifetime = 0.5
		flame.local_coords = false
		flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		flame.emission_box_extents = Vector3(0.6, 0.05, 0.2)
		flame.direction = Vector3.UP
		flame.spread = 20
		flame.gravity = Vector3(0, 3, 0)
		flame.initial_velocity_min = 1.0
		flame.initial_velocity_max = 2.5
		var fq := QuadMesh.new()
		fq.size = Vector2(0.25, 0.35)
		fq.material = (_orb_pool[0].get_node("Trail") as CPUParticles3D).mesh.surface_get_material(0)
		flame.mesh = fq
		flame.emitting = false
		flame.name = "Trail"
		w.add_child(flame)
		add_child(w)
		_wave_pool.append(w)

func _reset_positions() -> void:
	fighters[0].position = Vector3(-1.5, 0, 0)
	fighters[1].position = Vector3(1.5, 0, 0)
	for ft in fighters:
		ft.vel = Vector3.ZERO
		ft.face_now()
		ft.reset_physics_interpolation()

# =============================================================== boucle
func _physics_process(_delta: float) -> void:
	step()

func step() -> void:
	tick += 1
	phase_t += 1
	var t0 := Time.get_ticks_usec()
	match phase:
		Phase.INTRO:
			_tick_presentation()
			if phase_t == 1 and camera:
				camera.focus(fighters[0], 2.4, 2.8, 1.4, 60)
				hud.announce(fighters[0].data.display_name.to_upper(), 2.2, Color.WHITE)
				hud.subtitle("« %s »  —  %s" % [fighters[0].data.epithet, fighters[0].data.intro_line], 2.2)
			if phase_t == 150 and camera:
				camera.focus(fighters[1], 2.4, 2.8, 1.4, -60)
				hud.announce(fighters[1].data.display_name.to_upper(), 2.2, Color.WHITE)
				hud.subtitle("« %s »  —  %s" % [fighters[1].data.epithet, fighters[1].data.intro_line], 2.2)
			var skip := Input.is_action_just_pressed(&"punch") or (touch != null and not touch.consume_presses().is_empty())
			if phase_t >= 300 or (skip and phase_t > 20) or headless:
				_start_phase(Phase.ROUND_START)
		Phase.ROUND_START:
			_tick_presentation()
			if phase_t == 70 and hud:
				hud.announce("COMBATTEZ !", 1.0, Color(1, 0.4, 0.2))
				Sfx.play(&"bell", 0.0)
			if phase_t >= 95 or headless:
				_start_phase(Phase.FIGHT)
		Phase.FIGHT:
			_fight_tick()
		Phase.ROUND_END:
			_tick_presentation()
			_update_projectiles()
			if phase_t == 100:
				_victory_pose()
			if phase_t >= 280 or (headless and phase_t >= 2):
				if wins[0] >= rounds_to_win or wins[1] >= rounds_to_win:
					_start_phase(Phase.MATCH_END)
				else:
					round_num += 1
					_start_phase(Phase.ROUND_START)
		Phase.MATCH_END:
			_tick_presentation()
			if phase_t == 60 or (headless and phase_t == 1):
				finished.emit(_result())
	if slowmo_frames > 0:
		slowmo_frames -= 1
		if slowmo_frames == 0:
			Engine.time_scale = 1.0
	if not headless:
		excitement = move_toward(excitement, 0.25, DT * 0.15)
		arena.set_excitement(excitement)
		Sfx.crowd_intensity(excitement)
		_draw_debug()
	var us := Time.get_ticks_usec() - t0
	logic_usec_total += us
	logic_usec_max = maxi(logic_usec_max, us)
	stats.ticks += 1

func _tick_presentation() -> void:
	for ft in fighters:
		ft.tick(_empty_cmd)
		ft.position = arena.clamp_position(ft.position)

func _start_phase(p: int) -> void:
	phase = p
	phase_t = 0
	match p:
		Phase.INTRO:
			for ft in fighters:
				ft.play_presentation(Fighter.S.INTRO, ft.data.intro_anim)
		Phase.ROUND_START:
			_reset_round()
			if hud:
				hud.announce("ROUND %d" % round_num if not training else "ENTRAÎNEMENT", 1.1, Color(1, 0.85, 0.2))
			if camera:
				camera.release()
		Phase.FIGHT:
			pass
		Phase.MATCH_END:
			var w := 0 if wins[0] > wins[1] else 1
			if hud:
				hud.announce("%s GAGNE !" % fighters[w].data.display_name.to_upper(), 3.0, Color(1, 0.85, 0.2))

func _reset_round() -> void:
	timer_frames = ROUND_FRAMES
	projectiles.clear()
	for v in _orb_pool + _wave_pool:
		v.visible = false
	for i in 2:
		var ft := fighters[i]
		var carry := Game.carry_hp_ratio if (i == 0 and Game.mode == Game.Mode.SURVIVAL and round_num == 1) else 1.0
		ft.hp = ft.data.max_hp * carry
		ft.stamina = ft.data.max_stamina
		ft.energy = ft.energy * 0.5 if round_num > 1 else 0.0
		if training:
			ft.energy = 100.0 if i == 0 else 30.0
		ft.transformed = false
		ft.transform_left = 0
		ft.power_cd = 0
		ft.partner = null
		ft.invuln = 0
		ft._enter(Fighter.S.IDLE, &"idle")
	_reset_positions()
	cine_owner = null
	hitstop = 0
	Engine.time_scale = 1.0
	slowmo_frames = 0

func timer_text() -> String:
	if training:
		return "∞"
	return str(ceili(timer_frames / 60.0))

# =============================================================== combat
func _get_cmd(i: int) -> FighterCmd:
	if ais[i] != null:
		return (ais[i] as FighterAI).next_cmd(projectiles)
	return player_input.next_cmd()

func _fight_tick() -> void:
	var cmds := [_get_cmd(0), _get_cmd(1)]
	if hitstop > 0:
		hitstop -= 1
		for ft in fighters:
			ft.anim_frozen = true
		return
	for i in 2:
		var ft := fighters[i]
		if cine_owner != null and ft != cine_owner and ft.partner != cine_owner:
			ft.anim_frozen = true
			continue
		ft.anim_frozen = false
		ft.tick(cmds[i])
	_separate()
	for ft in fighters:
		ft.position = arena.clamp_position(ft.position)
	_resolve_strikes()
	_update_projectiles()
	if camera and camera.mode == FightCamera.Mode.GRAB:
		if fighters[0].state != Fighter.S.GRAB_ATK and fighters[1].state != Fighter.S.GRAB_ATK and fighters[0].state != Fighter.S.PIN_ATK and fighters[1].state != Fighter.S.PIN_ATK:
			camera.release()
	if camera and camera.mode == FightCamera.Mode.FOCUS and cine_owner == null:
		var busy := false
		for ft in fighters:
			if ft.state == Fighter.S.GRAB_ATK:
				busy = true
		if not busy:
			camera.release()
	if training:
		for i in 2:
			var ft := fighters[i]
			if tick - last_hit_tick[i] > 120 and ft.is_neutral():
				ft.hp = move_toward(ft.hp, ft.data.max_hp, ft.data.max_hp * DT)
		_update_training_info()
	elif cine_owner == null:
		timer_frames -= 1
		if timer_frames <= 0:
			_time_over()
			return
	for i in 2:
		if fighters[i].hp <= 0.0 and fighters[i].state in [Fighter.S.KO, Fighter.S.KNOCKDOWN] :
			if fighters[i].state != Fighter.S.KO:
				fighters[i]._enter(Fighter.S.KO, &"lying")
			_round_over(1 - i, "ko")
			return

func _separate() -> void:
	var a := fighters[0]
	var b := fighters[1]
	for ft in fighters:
		if ft.state in [Fighter.S.GRAB_ATK, Fighter.S.GRABBED, Fighter.S.PIN_ATK, Fighter.S.PINNED] or ft.is_lying():
			return
	if absf(a.position.y - b.position.y) > 1.2:
		return
	var d := b.position - a.position
	d.y = 0
	var min_d := 0.58 * (a.data.bulk + b.data.bulk) * 0.5 + 0.08
	var l := d.length()
	if l < min_d:
		var n := d / l if l > 0.001 else a.right()
		var push := (min_d - l) * 0.5
		a.position -= n * push
		b.position += n * push

static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	var l2 := ab.length_squared()
	if l2 > 0.0:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _resolve_strikes() -> void:
	var hits := []
	for i in 2:
		var a := fighters[i]
		var d := fighters[1 - i]
		if not a.is_hit_active():
			continue
		var hb := a.hitbox_world()
		if d.state == Fighter.S.DODGE and not a.evade_notified and a.flat_dist(d) < 2.3:
			a.evade_notified = true
			d.counter_ready = 40
			if hud:
				hud.side_msg(d.index, "ESQUIVE !")
		if not d.can_be_struck():
			continue
		for hurt in d.hurtboxes():
			if _seg_dist(hb, hurt[0], hurt[1]) <= hurt[2] + a.move.hitbox_radius:
				hits.append([a, d, hb])
				break
	# les échanges simultanés sont résolus ensemble (« trade »)
	for h in hits:
		_on_strike(h[0], h[1], h[2])

func _on_strike(a: Fighter, d: Fighter, hb: Vector3) -> void:
	var m := a.move
	a.on_move_connected()
	var to_a := a.position - d.position
	to_a.y = 0
	var facing_ok := d.fwd().dot(to_a.normalized()) > 0.2
	var blocking := (d.state == Fighter.S.BLOCK or d.state == Fighter.S.BLOCKSTUN) and facing_ok and not m.unblockable
	var is_ult := m == Fighter.ult_move()
	if blocking:
		if d.state == Fighter.S.BLOCK and d.tick_count - d.block_press_tick <= Fighter.PARRY_WINDOW and not is_ult:
			a.stagger(34)
			d.gain_energy(12.0)
			d.counter_ready = 40
			stats.parries[d.index] += 1
			hitstop = 10
			_fx_spark(hb, Color(0.6, 0.9, 1.0), true)
			_sfx(&"block", 0.02)
			if hud:
				hud.announce("CONTRE !", 0.8, Color(0.5, 0.85, 1.0))
			excitement += 0.15
			return
		d.receive_block(a, m, m.damage * (0.15 if is_ult else 0.0))
		a.gain_energy(1.0)
		hitstop = 3
		_fx_spark(hb, Color(0.7, 0.85, 1.0), false)
		_sfx(&"block")
		return
	var dmg := m.damage * a.dmg_mult() / d.data.defense_mult
	var counter := d.in_startup()
	if counter:
		dmg *= 1.25
		if hud:
			hud.side_msg(a.index, "COUP DE CONTRE")
	if a.counter_ready > 0:
		dmg *= 1.35
		a.counter_ready = 0
		if hud:
			hud.side_msg(a.index, "CONTRE-ATTAQUE !")
	dmg *= maxf(0.45, pow(0.88, d.combo_taken))
	if is_ult:
		_start_ultimate(a, d)
		return
	d.receive_hit(a, m, dmg, hb.y - d.position.y)
	a.gain_energy(dmg * 0.6)
	last_hit_tick[d.index] = tick
	stats.hits[a.index] += 1
	stats.damage[a.index] += dmg
	stats.max_combo[a.index] = maxi(stats.max_combo[a.index], d.combo_taken)
	hitstop = m.hitstop + (2 if counter else 0)
	var heavy := m.damage >= 11.0
	_fx_spark(hb, Color(1, 0.75, 0.35) if not a.transformed else a.data.aura_color, heavy)
	if camera:
		camera.shake(m.shake)
	_sfx(&"hit_heavy" if heavy else &"hit_light")
	if hud:
		hud.combo(a.index, d.combo_taken)
	excitement += 0.04 + (0.08 if heavy else 0.0)
	if heavy:
		Settings.vibrate(30)
	if d.hp <= 0.0:
		_on_ko_hit(a, d)

func _on_ko_hit(a: Fighter, d: Fighter) -> void:
	Engine.time_scale = 0.3
	slowmo_frames = 40
	if camera:
		camera.shake(0.6)
	_sfx(&"ko")

func _start_ultimate(a: Fighter, d: Fighter) -> void:
	var predicted := a.data.ultimate_damage * a.dmg_mult()
	finisher_pending = d.hp <= predicted
	stats.ults[a.index] += 1
	a.begin_grab_sequence(d, &"ultimate")
	cine_owner = a
	hitstop = 6
	if camera:
		camera.focus(a, 2.5, 3.4, 1.5, 120)
	if hud:
		if finisher_pending:
			hud.announce("TECHNIQUE DE FINITION", 2.0, Color(1, 0.3, 0.2))
			hud.subtitle(a.data.finisher_name, 2.4)
		else:
			hud.announce(a.data.ultimate_name.to_upper(), 1.6, a.data.aura_color.lightened(0.3))
	_sfx(&"power")
	excitement = 1.0

func try_grab(a: Fighter, kind: StringName) -> bool:
	var d := a.opponent
	if not d.can_be_grabbed():
		return false
	if a.flat_dist(d) > 1.2:
		return false
	var dir := d.position - a.position
	dir.y = 0
	if a.fwd().dot(dir.normalized()) < 0.5:
		return false
	if d.state == Fighter.S.GRAB_TRY and d.sframe >= 8 and d.sframe <= 10:
		# deux prises simultanées : dégagement mutuel
		grab_tech(a, d)
		return true
	a.begin_grab_sequence(d, kind)
	stats.grabs[a.index] += 1
	if camera:
		camera.mode = FightCamera.Mode.GRAB
	if hud:
		hud.subtitle(GrabLib.SEQS[kind].name, 1.4)
	_sfx(&"whoosh")
	return true

func grab_tech(a: Fighter, d: Fighter) -> void:
	a.partner = null
	d.partner = null
	a._recover(18, &"hit_high")
	d._recover(18, &"hit_high2")
	a.position -= a.fwd() * 0.45
	d.position -= d.fwd() * 0.45
	if hud:
		hud.side_msg(d.index, "DÉGAGEMENT !")
	if camera:
		camera.release()
	_sfx(&"block")

func apply_sequence_hit(a: Fighter, d: Fighter, dmg: float, final: bool) -> void:
	dmg /= d.data.defense_mult
	d.hp = maxf(0.0, d.hp - dmg)
	d.last_damage = dmg
	a.gain_energy(dmg * 0.4)
	d.gain_energy(dmg * 0.3)
	stats.hits[a.index] += 1
	stats.damage[a.index] += dmg
	last_hit_tick[d.index] = tick
	if d.rig:
		d.rig.flash(1.0)
	var p := d.position + Vector3.UP * 0.4
	if d.rig:
		p = d.rig.joint_global(&"chest")
	var is_ult := a.grab_kind == &"ultimate"
	if final:
		hitstop = 8
		if vfx:
			vfx.dust(d.position, true)
			vfx.ring(Vector3(d.position.x, 0.03, d.position.z), a.data.aura_color if is_ult else Color(1, 0.9, 0.7), 3.5 if is_ult else 2.2, 0.5)
			if is_ult:
				vfx.burst(p, a.data.aura_color, 2.0, 0.5)
		if camera:
			camera.shake(0.7 if is_ult else 0.5)
		_sfx(&"slam")
		excitement = 1.0
		Settings.vibrate(60)
		if is_ult:
			Engine.time_scale = 0.3
			slowmo_frames = 30
			cine_owner = null
			if d.hp <= 0.0 and hud:
				hud.announce("FINITION !", 1.6, Color(1, 0.3, 0.2))
	else:
		hitstop = 3
		_fx_spark(p, a.data.aura_color if is_ult else Color(1, 0.8, 0.4), false)
		_sfx(&"hit_light" if not is_ult else &"zap")

# =============================================================== tombé
func start_pin(a: Fighter, d: Fighter) -> void:
	a.start_pin(d)
	if camera:
		camera.mode = FightCamera.Mode.GRAB
	if hud:
		hud.announce("TOMBÉ !", 0.8, Color(1, 1, 1))

func pin_count(a: Fighter, n: int) -> void:
	if hud:
		hud.announce(str(n), 0.6, Color(1, 0.85, 0.2))
	_sfx(&"hit_heavy", 0.0)
	excitement += 0.2

func pin_win(a: Fighter, d: Fighter) -> void:
	d.hp = 0.0
	d._enter(Fighter.S.KO, &"lying")
	a._enter(Fighter.S.RECOVER, &"getup")
	a.stun_len = 26
	_round_over(a.index, "pin")

func pin_escape(a: Fighter, d: Fighter) -> void:
	d.escape_pin()
	a._recover(24, &"getup")
	a.partner = null
	if hud:
		hud.side_msg(d.index, "DÉGAGÉ !")
	if camera:
		camera.release()

# =============================================================== mystique
func spawn_power(o: Fighter, p: PowerData) -> void:
	var pr := Projectile.new()
	pr.setup(o, p)
	stats.powers[o.index] += 1
	var pool := _wave_pool if pr.is_ground() else _orb_pool
	for v in pool:
		if not v.visible:
			pr.visual = v
			break
	if pr.visual:
		pr.visual.visible = true
		pr.visual.global_position = pr.pos
		var m: ShaderMaterial = (pr.visual as MeshInstance3D).material_override
		m.set_shader_parameter("color", p.color)
		m.set_shader_parameter("alpha", 1.0)
		var sc := 1.6 if o.transformed else 1.0
		pr.visual.scale = Vector3.ONE * sc
		if pr.is_ground():
			pr.visual.look_at(pr.visual.global_position + pr.dir, Vector3.UP)
		var trail: CPUParticles3D = pr.visual.get_node("Trail")
		trail.color = p.color
		trail.emitting = true
	projectiles.append(pr)
	if vfx:
		vfx.burst(pr.pos, p.color, 0.8, 0.25)
		if pr.is_ground():
			vfx.dust(pr.pos, true)
	if camera:
		camera.shake(0.2)
	_sfx(&"zap" if p.kind == PowerData.Kind.ORB else &"power")

func _power_move(p: PowerData) -> MoveData:
	if not _power_moves.has(p.id):
		var m := MoveData.new()
		m.id = p.id
		m.display_name = p.display_name
		m.damage = p.damage
		m.hit_stun = 24
		m.block_stun = 16
		m.push = 0.6
		m.hitstop = 6
		m.launches = p.kind == PowerData.Kind.SHOCKWAVE
		m.launch_velocity = Vector3(0, 4.5, 2.0)
		_power_moves[p.id] = m
	return _power_moves[p.id]

func _update_projectiles() -> void:
	for pr in projectiles:
		if not pr.alive:
			continue
		var step_v := pr.dir * pr.speed * DT
		pr.pos += step_v
		pr.traveled += step_v.length()
		if pr.visual:
			pr.visual.global_position = pr.pos
		# collision entre projectiles : annulation mutuelle
		for other in projectiles:
			if other != pr and other.alive and other.owner_f != pr.owner_f and other.pos.distance_to(pr.pos) < 0.7:
				pr.alive = false
				other.alive = false
				if vfx:
					vfx.burst((pr.pos + other.pos) * 0.5, Color.WHITE, 1.4, 0.3)
				_sfx(&"zap")
		if not pr.alive:
			continue
		var t := pr.owner_f.opponent
		if not t.is_invulnerable() and not t.is_lying() and pr.touches(t):
			pr.alive = false
			var m := _power_move(pr.power)
			var to_o := pr.owner_f.position - t.position
			to_o.y = 0
			var blocking := (t.state == Fighter.S.BLOCK or t.state == Fighter.S.BLOCKSTUN) and t.fwd().dot(to_o.normalized()) > 0.2
			if blocking:
				t.receive_block(pr.owner_f, m, pr.damage * 0.25)
				_fx_spark(pr.pos, pr.power.color, false)
				_sfx(&"block")
			else:
				var dmg := pr.damage / t.data.defense_mult * maxf(0.45, pow(0.88, t.combo_taken))
				t.receive_hit(pr.owner_f, m, dmg, 1.3)
				pr.owner_f.gain_energy(dmg * 0.3)
				last_hit_tick[t.index] = tick
				stats.hits[pr.owner_f.index] += 1
				stats.damage[pr.owner_f.index] += dmg
				hitstop = 6
				_fx_spark(pr.pos + Vector3.UP * (0.8 if pr.is_ground() else 0.0), pr.power.color, true)
				if vfx:
					vfx.burst(t.position + Vector3.UP, pr.power.color, 1.2, 0.3)
				if camera:
					camera.shake(0.35)
				_sfx(&"hit_heavy")
				if t.hp <= 0.0:
					_on_ko_hit(pr.owner_f, t)
		elif pr.traveled > pr.power.range_m or absf(pr.pos.x) > 4.5 or absf(pr.pos.z) > 4.5:
			pr.alive = false
			if vfx:
				vfx.burst(pr.pos, pr.power.color, 0.6, 0.2)
	for i in range(projectiles.size() - 1, -1, -1):
		var pr := projectiles[i]
		if not pr.alive:
			if pr.visual:
				pr.visual.visible = false
				(pr.visual.get_node("Trail") as CPUParticles3D).emitting = false
			projectiles.remove_at(i)

# =============================================================== cinématiques
func begin_cinematic(owner: Fighter, kind: StringName, frames: int) -> void:
	cine_owner = owner
	stats.transforms[owner.index] += 1
	if camera:
		camera.focus(owner, frames / 60.0, 2.7, 1.3, 75)
	if hud:
		hud.announce(owner.data.transform_name.to_upper(), 1.4, owner.data.aura_color.lightened(0.3))
	_sfx(&"transform", 0.0)
	excitement = 1.0
	if vfx:
		vfx.ring(Vector3(owner.position.x, 0.03, owner.position.z), owner.data.aura_color, 2.4, 1.2)

func end_cinematic(owner: Fighter) -> void:
	if cine_owner == owner:
		cine_owner = null
	if camera:
		camera.release()

# =============================================================== manches
func _time_over() -> void:
	var r0 := fighters[0].hp_ratio()
	var r1 := fighters[1].hp_ratio()
	if hud:
		hud.announce("TEMPS ÉCOULÉ", 1.5, Color.WHITE)
	if absf(r0 - r1) < 0.001:
		wins[0] += 1
		wins[1] += 1
		_round_over(-1, "draw")
	else:
		_round_over(0 if r0 > r1 else 1, "time")

func _round_over(winner: int, reason: String) -> void:
	if phase != Phase.FIGHT:
		return
	round_winner = winner
	end_reason = reason
	if winner >= 0:
		wins[winner] += 1
	_start_phase(Phase.ROUND_END)
	cine_owner = null
	if reason == "ko" or reason == "pin":
		Engine.time_scale = 0.35
		slowmo_frames = 45
		_sfx(&"ko")
		_sfx(&"cheer")
		if hud:
			hud.announce("K.O. !" if reason == "ko" else "1, 2, 3 — TOMBÉ !", 2.0, Color(1, 0.25, 0.2))
	excitement = 1.0
	if training:
		round_num += 1

func _victory_pose() -> void:
	if round_winner < 0:
		return
	var w := fighters[round_winner]
	var l := w.opponent
	w.play_presentation(Fighter.S.VICTORY, w.data.victory_anim)
	w.face_now()
	if l.state != Fighter.S.KO:
		l.play_presentation(Fighter.S.DEFEAT, &"defeat")
	if camera:
		camera.focus(w, 3.0, 3.0, 1.45, 50)
	if hud:
		hud.subtitle("%s remporte la manche" % w.data.display_name, 2.0)

func _result() -> Dictionary:
	var w := 0 if wins[0] > wins[1] else 1
	return {"winner": w, "p1_won": w == 0, "wins": wins.duplicate(), "stats": stats.duplicate(true),
		"p1": fighters[0].data.id, "p2": fighters[1].data.id, "reason": end_reason, "ticks": tick}

# =============================================================== effets
func _fx_spark(p: Vector3, c: Color, big: bool) -> void:
	if vfx:
		vfx.spark(p, c, big)

func _sfx(n: StringName, var_ := 0.06) -> void:
	if not headless:
		Sfx.play(n, var_)

func _on_fighter_event(kind: StringName, info: Dictionary, ft: Fighter) -> void:
	if headless:
		return
	match kind:
		&"whoosh":
			Sfx.play(&"whoosh", 0.15, -6.0)
		&"dodge":
			Sfx.play(&"whoosh", 0.1, -3.0)
		&"land":
			vfx.dust(ft.position, not info.get("soft", true))
			if not info.get("soft", true):
				Sfx.play(&"slam", 0.1, -3.0)
				camera.shake(0.25)
		&"denied":
			if ais[ft.index] == null:
				var what: String = info.get("what", "")
				var msg: String = {"ultimate": "ÉNERGIE INSUFFISANTE", "power": "POUVOIR INDISPONIBLE", "dodge": "ÉPUISÉ"}.get(what, "")
				hud.side_msg(ft.index, msg)
		&"guard_break":
			hud.side_msg(ft.opponent.index, "GARDE BRISÉE !")
			Sfx.play(&"hit_heavy")
		&"transform_burst":
			vfx.burst(ft.position + Vector3.UP, ft.data.aura_color, 2.4, 0.6)
			vfx.ring(Vector3(ft.position.x, 0.03, ft.position.z), ft.data.aura_color, 4.0, 0.7)
			vfx.dust(ft.position, true)
			camera.shake(0.45)
			Sfx.play(&"power", 0.0)
			Settings.vibrate(80)
		&"transform_end":
			vfx.burst(ft.position + Vector3.UP, ft.data.aura_color, 1.0, 0.3)
		&"cast_start":
			if ft.rig:
				vfx.burst(ft.rig.joint_global(&"hd_r"), ft.data.power.color, 0.5, 0.3)
		&"ult_rush":
			hud.side_msg(ft.index, ft.data.ultimate_name.to_upper())
			Sfx.play(&"power", 0.05)
			vfx.ring(Vector3(ft.position.x, 0.03, ft.position.z), ft.data.aura_color, 2.0, 0.4)

# =============================================================== entraînement / debug
func set_dummy_mode(m: int) -> void:
	if ais[1]:
		(ais[1] as FighterAI).dummy_mode = m

func _update_training_info() -> void:
	if hud == null:
		return
	var p := fighters[0]
	var m := p.move
	var txt := "ENTRAÎNEMENT\n"
	if m:
		var adv := m.block_stun - (m.active - 1 + m.recovery)
		txt += "%s : %d/%d/%d frames\n" % [m.display_name, m.startup, m.active, m.recovery]
		txt += "Dégâts %.0f  |  Avantage garde %+d\n" % [m.damage * p.dmg_mult(), adv]
	txt += "Dernier coup subi : %.1f\n" % fighters[1].last_damage
	txt += "Combo max : %d" % stats.max_combo[0]
	hud.info_text = txt

func _draw_debug() -> void:
	_imm.clear_surfaces()
	if not Settings.show_hitboxes:
		return
	_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for ft in fighters:
		for hb in ft.hurtboxes():
			_capsule_lines(hb[0], hb[1], hb[2], Color(0.2, 1, 0.3))
		if ft.state == Fighter.S.ATTACK and ft.move:
			var c := Color(1, 0.15, 0.1) if ft.is_hit_active() else Color(1, 0.8, 0.2, 0.5)
			var p := ft.hitbox_world()
			_capsule_lines(p, p, ft.move.hitbox_radius, c)
	for pr in projectiles:
		_capsule_lines(pr.pos, pr.pos, pr.width, Color(0.6, 0.4, 1))
	_imm.surface_end()

func _capsule_lines(a: Vector3, b: Vector3, r: float, c: Color) -> void:
	var seg := 16
	for center in [a, b]:
		for i in seg:
			var t0 := TAU * i / seg
			var t1 := TAU * (i + 1) / seg
			for axis in 3:
				var p0: Vector3
				var p1: Vector3
				match axis:
					0:
						p0 = center + Vector3(cos(t0), 0, sin(t0)) * r
						p1 = center + Vector3(cos(t1), 0, sin(t1)) * r
					1:
						p0 = center + Vector3(cos(t0), sin(t0), 0) * r
						p1 = center + Vector3(cos(t1), sin(t1), 0) * r
					_:
						p0 = center + Vector3(0, cos(t0), sin(t0)) * r
						p1 = center + Vector3(0, cos(t1), sin(t1)) * r
				_imm.surface_set_color(c)
				_imm.surface_add_vertex(p0)
				_imm.surface_set_color(c)
				_imm.surface_add_vertex(p1)
	for o in [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
		_imm.surface_set_color(c)
		_imm.surface_add_vertex(a + o)
		_imm.surface_set_color(c)
		_imm.surface_add_vertex(b + o)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
