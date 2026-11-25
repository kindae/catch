## Point d'entrée : navigation entre écrans (menu, sélection, options, combat,
## résultats), pause automatique en arrière-plan, résolution adaptative,
## modes --benchmark et --selftest (ligne de commande).
extends Node

var _ui: CanvasLayer
var _screen: Control
var _stage: Node3D
var _stage_cam: Camera3D
var _preview: PreviewActor
var _match: Match
var _pause: Control
var _select_side := 0
var _sel := [0, 1]
var _costume := [0, 0]
var _perf_acc := 0.0
var _perf_frames := 0
var _perf_good := 0.0
var _bench := {}
var _cam_angle := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_run_selftest.call_deferred()
		return
	if "--benchmark" in args:
		_start_benchmark.call_deferred(args)
		return
	if Array(args).any(func(a): return a.begins_with("--shot")):
		_shot_mode.call_deferred(args)
		return
	_show_main_menu()

# =============================================================== scène de menu
func _ensure_stage() -> void:
	if _stage:
		return
	_stage = Node3D.new()
	add_child(_stage)
	var ring := KinshasaRing.new()
	_stage.add_child(ring)
	_preview = PreviewActor.new()
	_stage.add_child(_preview)
	_preview.position = Vector3(0.6, 0, 0)
	_preview.rotation_degrees.y = 205
	_stage_cam = Camera3D.new()
	_stage_cam.fov = 45
	_stage.add_child(_stage_cam)
	_stage_cam.current = true
	_preview.show_fighter(Roster.playable()[0], 0)
	Sfx.play_crowd(true)
	Sfx.play_music(true)

func _free_stage() -> void:
	if _stage:
		_stage.queue_free()
		_stage = null
		_preview = null

func _process(dt: float) -> void:
	if _stage_cam and is_instance_valid(_stage_cam):
		_cam_angle += dt * 0.12
		var target := Vector3(0.6, 1.15, 0)
		_stage_cam.position = target + Vector3(sin(_cam_angle) * 0.6 - 0.9, 0.25, 3.4 + cos(_cam_angle) * 0.3)
		_stage_cam.look_at(target + Vector3(0.55, 0, 0))
	_adaptive_resolution(dt)

## Résolution adaptative : réduit l'échelle 3D si le FPS chute, la remonte sinon.
func _adaptive_resolution(dt: float) -> void:
	if not Settings.adaptive_resolution or get_tree().paused:
		return
	_perf_acc += dt
	_perf_frames += 1
	if _perf_acc < 1.0:
		return
	var avg := _perf_acc / _perf_frames
	var budget := 1.0 / Settings.target_fps()
	if avg > budget * 1.18 and Settings.current_scale > Settings.profile().min_scale:
		Settings.set_render_scale(Settings.current_scale - 0.05)
		_perf_good = 0.0
	elif avg < budget * 1.03:
		_perf_good += _perf_acc
		if _perf_good > 4.0 and Settings.current_scale < Settings.profile().scale:
			Settings.set_render_scale(Settings.current_scale + 0.05)
			_perf_good = 0.0
	_perf_acc = 0.0
	_perf_frames = 0

func _notification(what: int) -> void:
	# économie : suspendre le jeu lorsque l'application passe en arrière-plan
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _match and not get_tree().paused:
			_open_pause()
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# bouton Retour Android
		if _match:
			if get_tree().paused:
				_close_pause()
			else:
				_open_pause()
		elif _screen and _screen.has_meta("main_menu"):
			get_tree().quit()
		else:
			_show_main_menu()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"pause") and _match:
		if get_tree().paused:
			_close_pause()
		else:
			_open_pause()
	if e.is_action_pressed(&"debug_hitbox"):
		Settings.show_hitboxes = not Settings.show_hitboxes

func _set_screen(c: Control) -> void:
	if _screen:
		_screen.queue_free()
	_screen = c
	if c:
		c.theme = UiTheme.get_theme()
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ui.add_child(c)

func _vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

# =============================================================== menu principal
func _show_main_menu() -> void:
	_ensure_stage()
	var root := Control.new()
	root.set_meta("main_menu", true)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.01, 0.05, 0.92))
	g.set_color(1, Color(0.02, 0.01, 0.05, 0.0))
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.size = Vector2(720, get_viewport().get_visible_rect().size.y)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var v := _vbox(7)
	v.position = Vector2(56, 22)
	root.add_child(v)
	v.add_child(UiTheme.title("CATCH 243", 80))
	var sub := UiTheme.title("LE CATCH CONGOLAIS", 26, Color.WHITE)
	v.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	v.add_child(UiTheme.button("Combat rapide", func(): _go_select(Game.Mode.QUICK)))
	v.add_child(UiTheme.button("Entraînement", func(): _go_select(Game.Mode.TRAINING)))
	v.add_child(UiTheme.button("Tournoi de Kinshasa", func(): _go_select(Game.Mode.TOURNAMENT)))
	v.add_child(UiTheme.button("Survie", func(): _go_select(Game.Mode.SURVIVAL)))
	var career := UiTheme.button("Carrière  (bientôt)", func(): pass)
	career.disabled = true
	v.add_child(career)
	v.add_child(UiTheme.button("Options", _show_options))
	if not OS.has_feature("mobile"):
		v.add_child(UiTheme.button("Quitter", func(): get_tree().quit()))
	var info := Label.new()
	info.text = "Victoires : %d / %d combats   •   Record survie : %d   •   v%s" % [Game.stats.wins, Game.stats.fights, Game.stats.survival_best, ProjectSettings.get_setting("application/config/version")]
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root.add_child(info)
	_set_screen(root)
	var vsz := get_viewport().get_visible_rect().size
	info.position = Vector2(vsz.x - 560, vsz.y - 34)

# =============================================================== sélection
func _go_select(mode: int) -> void:
	Game.start_run(mode)
	_select_side = 0
	_show_select()

func _show_select() -> void:
	_ensure_stage()
	var all := Roster.all()
	var root := Control.new()
	var top := UiTheme.title("CHOIX DU COMBATTANT" if _select_side == 0 else "CHOIX DE L'ADVERSAIRE", 40)
	top.position = Vector2(40, 18)
	root.add_child(top)
	var mode_l := Label.new()
	mode_l.text = Game.MODE_NAMES[Game.mode]
	mode_l.position = Vector2(44, 74)
	mode_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	root.add_child(mode_l)
	# grille des combattants
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.position = Vector2(40, 112)
	root.add_child(grid)
	for i in all.size():
		var d: FighterData = all[i]
		var b := Button.new()
		b.text = d.display_name + ("" if d.playable else "  · à venir")
		b.custom_minimum_size = Vector2(230, 50)
		b.add_theme_font_size_override("font_size", 19)
		b.toggle_mode = true
		b.button_pressed = (i == _sel[_select_side])
		b.disabled = not d.playable
		if not d.playable:
			b.tooltip_text = d.unlock_hint
		b.pressed.connect(func():
			Sfx.play(&"ui", 0.0)
			_sel[_select_side] = i
			_costume[_select_side] = 0
			_show_select())
		grid.add_child(b)
	var d: FighterData = all[_sel[_select_side]]
	_preview.show_fighter(d, _costume[_select_side])
	# fiche
	var panel := PanelContainer.new()
	var vs := get_viewport().get_visible_rect().size
	panel.position = Vector2(vs.x - 470, 84)
	panel.custom_minimum_size = Vector2(440, 0)
	root.add_child(panel)
	var v := _vbox(6)
	panel.add_child(v)
	v.add_child(UiTheme.title(d.display_name.to_upper(), 40))
	var ep := Label.new()
	ep.text = "« %s » — %s" % [d.epithet, d.style]
	ep.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	ep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ep.custom_minimum_size = Vector2(400, 0)
	ep.add_theme_font_size_override("font_size", 19)
	v.add_child(ep)
	var desc := Label.new()
	desc.text = d.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(400, 0)
	desc.add_theme_font_size_override("font_size", 17)
	v.add_child(desc)
	for k in d.stat_display:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = String(k).capitalize()
		l.custom_minimum_size = Vector2(130, 0)
		l.add_theme_font_size_override("font_size", 17)
		h.add_child(l)
		var bar := Label.new()
		bar.text = "■".repeat(d.stat_display[k]) + "□".repeat(5 - d.stat_display[k])
		bar.add_theme_color_override("font_color", UiTheme.YELLOW)
		h.add_child(bar)
		v.add_child(h)
	var pw := Label.new()
	pw.text = "Pouvoir : %s\nTransformation : %s\nFinition : %s" % [d.power.display_name, d.transform_name, d.finisher_name]
	pw.add_theme_font_size_override("font_size", 17)
	pw.add_theme_color_override("font_color", d.aura_color.lightened(0.4))
	v.add_child(pw)
	if d.power.counter_hint != "":
		var ch := Label.new()
		ch.text = "Parade : " + d.power.counter_hint
		ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch.custom_minimum_size = Vector2(400, 0)
		ch.add_theme_font_size_override("font_size", 15)
		ch.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
		v.add_child(ch)
	# costume
	var ch_box := HBoxContainer.new()
	var avail := Game.available_costumes(d)
	var prev := Button.new()
	prev.text = "◀"
	var next := Button.new()
	next.text = "▶"
	var cl := Label.new()
	var cur: int = _costume[_select_side]
	cl.text = d.costume(cur).get("name", "Tenue")
	cl.custom_minimum_size = Vector2(250, 0)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev.pressed.connect(func(): _cycle_costume(d, -1))
	next.pressed.connect(func(): _cycle_costume(d, 1))
	ch_box.add_child(prev)
	ch_box.add_child(cl)
	ch_box.add_child(next)
	v.add_child(ch_box)
	var locked := d.costumes.size() - avail.size()
	if locked > 0:
		var ll := Label.new()
		ll.text = "%d tenue(s) à débloquer (gagnez le tournoi)" % locked
		ll.add_theme_font_size_override("font_size", 14)
		ll.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		v.add_child(ll)
	# difficulté + arène + actions
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.position = Vector2(40, vs.y - 86)
	root.add_child(bottom)
	bottom.add_child(UiTheme.button("Retour", _back_from_select, 160))
	var diff := OptionButton.new()
	for n in Settings.DIFFICULTY_NAMES:
		diff.add_item("IA : " + n)
	diff.selected = Settings.difficulty
	diff.custom_minimum_size = Vector2(220, 58)
	diff.item_selected.connect(func(i): Settings.difficulty = i; Settings.save())
	bottom.add_child(diff)
	var arena := OptionButton.new()
	for a in Game.ARENAS:
		arena.add_item(a.name + ("" if a.available else " (bientôt)"))
		arena.set_item_disabled(arena.item_count - 1, not a.available)
	arena.selected = 0
	arena.custom_minimum_size = Vector2(330, 58)
	bottom.add_child(arena)
	var needs_p2 := Game.mode in [Game.Mode.QUICK, Game.Mode.TRAINING]
	var label := "Choisir l'adversaire ▶" if (_select_side == 0 and needs_p2) else "COMBATTRE !"
	var go := UiTheme.button(label, _confirm_select, 300)
	go.add_theme_color_override("font_color", UiTheme.YELLOW)
	bottom.add_child(go)
	_set_screen(root)

func _cycle_costume(d: FighterData, dir: int) -> void:
	var avail := Game.available_costumes(d)
	var idx := avail.find(_costume[_select_side])
	idx = (idx + dir + avail.size()) % avail.size()
	_costume[_select_side] = avail[idx]
	_show_select()

func _back_from_select() -> void:
	if _select_side == 1:
		_select_side = 0
		_show_select()
	else:
		_show_main_menu()

func _confirm_select() -> void:
	var all := Roster.all()
	var needs_p2 := Game.mode in [Game.Mode.QUICK, Game.Mode.TRAINING]
	if _select_side == 0 and needs_p2:
		_select_side = 1
		if _sel[1] == _sel[0] or not all[_sel[1]].playable:
			for i in all.size():
				if all[i].playable and i != _sel[0]:
					_sel[1] = i
					break
		_show_select()
		return
	Game.p1_id = all[_sel[0]].id
	Game.p1_costume = _costume[0]
	if needs_p2:
		Game.p2_id = all[_sel[1]].id
		Game.p2_costume = _costume[1]
		if Game.p2_id == Game.p1_id and Game.p2_costume == Game.p1_costume:
			Game.p2_costume = 1
	else:
		Game.p2_id = Game.next_opponent()
		Game.p2_costume = (Game.run_stage + Game.run_wins) % 2
	_start_match()

# =============================================================== combat
func _start_match(both_ai := false) -> void:
	_set_screen(null)
	_free_stage()
	if _match:
		_match.queue_free()
	Game.rounds_to_win = 1 if Game.mode == Game.Mode.SURVIVAL else 2
	_match = Match.new()
	add_child(_match)
	_match.process_mode = Node.PROCESS_MODE_PAUSABLE
	_match.setup(Roster.by_id(Game.p1_id), Roster.by_id(Game.p2_id), Game.p1_costume, Game.p2_costume,
		Game.difficulty_for_run(), Game.mode == Game.Mode.TRAINING, both_ai)
	_match.finished.connect(_on_match_finished)
	_match.pause_requested.connect(_open_pause)

func _end_match() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _match:
		_match.queue_free()
		_match = null
	if _pause:
		_pause.queue_free()
		_pause = null

func _on_match_finished(r: Dictionary) -> void:
	if Game.mode == Game.Mode.TRAINING:
		return
	Game.stats.fights += 1
	if r.p1_won:
		Game.stats.wins += 1
	var unlocked: Array[String] = []
	var next_label := ""
	match Game.mode:
		Game.Mode.TOURNAMENT:
			if r.p1_won:
				Game.run_stage += 1
				if Game.run_stage >= 3:
					Game.stats.tournaments += 1
					if Game.unlock("tournament_win"):
						unlocked.append("Tenues de champion pour tous les combattants")
				else:
					next_label = ["Quart de finale", "Demi-finale", "Finale"][Game.run_stage]
		Game.Mode.SURVIVAL:
			if r.p1_won:
				Game.run_wins += 1
				Game.carry_hp_ratio = minf(1.0, _match.fighters[0].hp_ratio() + 0.3)
				next_label = "Adversaire %d" % (Game.run_wins + 1)
			Game.stats.survival_best = maxi(Game.stats.survival_best, Game.run_wins)
	Game.save_progress()
	Game.last_result = r
	await get_tree().create_timer(1.2).timeout
	_show_results(r, next_label, unlocked)

func _show_results(r: Dictionary, next_label: String, unlocked: Array[String]) -> void:
	var p1 := Roster.by_id(r.p1)
	var p2 := Roster.by_id(r.p2)
	var root := Control.new()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(panel)
	var v := _vbox(10)
	panel.add_child(v)
	var won: bool = r.p1_won
	v.add_child(UiTheme.title("VICTOIRE !" if won else "DÉFAITE", 64, UiTheme.YELLOW if won else Color(0.9, 0.3, 0.3)))
	var s: Dictionary = r.stats
	var l := Label.new()
	l.text = "%s %d – %d %s\n\nCoups portés : %d   •   Dégâts : %.0f\nCombo max : %d   •   Contres : %d   •   Prises : %d   •   Pouvoirs : %d" % [
		p1.display_name, r.wins[0], r.wins[1], p2.display_name, s.hits[0], s.damage[0], s.max_combo[0], s.parries[0], s.grabs[0], s.powers[0]]
	v.add_child(l)
	if Game.mode == Game.Mode.TOURNAMENT and won and Game.run_stage >= 3:
		v.add_child(UiTheme.title("CHAMPION DE KINSHASA !", 36))
	if Game.mode == Game.Mode.SURVIVAL:
		var sl := Label.new()
		sl.text = "Série : %d victoire(s)   •   Record : %d" % [Game.run_wins, Game.stats.survival_best]
		v.add_child(sl)
	for u in unlocked:
		var ul := Label.new()
		ul.text = "Débloqué : " + u
		ul.add_theme_color_override("font_color", UiTheme.YELLOW)
		v.add_child(ul)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	if next_label != "" and won:
		h.add_child(UiTheme.button("Suivant : " + next_label, func():
			_end_match()
			Game.p2_id = Game.next_opponent()
			Game.p2_costume = (Game.run_stage + Game.run_wins) % 2
			_start_match(), 330))
	else:
		h.add_child(UiTheme.button("Revanche", func():
			_end_match()
			if Game.mode != Game.Mode.QUICK:
				Game.start_run(Game.mode)
				Game.p2_id = Game.next_opponent()
			_start_match(), 220))
	h.add_child(UiTheme.button("Menu principal", func():
		_end_match()
		_show_main_menu(), 260))
	_set_screen(root)
	await get_tree().process_frame
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2

# =============================================================== pause
func _open_pause() -> void:
	if _pause or _match == null:
		return
	get_tree().paused = true
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	h.position = Vector2(60, 50)
	root.add_child(h)
	var v := _vbox(10)
	h.add_child(v)
	v.add_child(UiTheme.title("PAUSE", 56))
	v.add_child(UiTheme.button("Reprendre", _close_pause))
	v.add_child(UiTheme.button("Recommencer", func():
		_end_match()
		_start_match()))
	if _match.training:
		var dummy := OptionButton.new()
		for n in ["Mannequin : IA", "Mannequin : immobile", "Mannequin : garde", "Mannequin : esquive"]:
			dummy.add_item(n)
		dummy.selected = (_match.ais[1] as FighterAI).dummy_mode
		dummy.custom_minimum_size = Vector2(360, 58)
		dummy.item_selected.connect(func(i): _match.set_dummy_mode(i))
		v.add_child(dummy)
		var inf := CheckButton.new()
		inf.text = "Énergie mystique infinie"
		inf.button_pressed = _match.fighters[0].infinite_energy
		inf.toggled.connect(func(on): _match.fighters[0].infinite_energy = on)
		v.add_child(inf)
		var hb := CheckButton.new()
		hb.text = "Afficher hitboxes / hurtboxes"
		hb.button_pressed = Settings.show_hitboxes
		hb.toggled.connect(func(on): Settings.show_hitboxes = on)
		v.add_child(hb)
	var eco := CheckButton.new()
	eco.text = "Économie d'énergie (30 FPS)"
	eco.button_pressed = Settings.eco_mode
	eco.toggled.connect(func(on): Settings.eco_mode = on; Settings.apply(); Settings.save())
	v.add_child(eco)
	v.add_child(UiTheme.button("Quitter le combat", func():
		_end_match()
		_show_main_menu()))
	var guide := PanelContainer.new()
	h.add_child(guide)
	var gl := Label.new()
	gl.text = _controls_text()
	gl.add_theme_font_size_override("font_size", 17)
	guide.add_child(gl)
	_pause = root
	_ui.add_child(root)

func _controls_text() -> String:
	return """COMMANDES
Joystick : déplacement (haut/bas = pas de côté)
POING : enchaînement Direct → Crochet → Uppercut
PIED : Coup de pied → Pied retourné (projette)
Avant + POING / PIED : coups lourds
PRISE : Body Slam   •   Direction + PRISE : Projection
PRISE sur adversaire au sol : tombé (1, 2, 3)
PRISE pendant une prise adverse : dégagement
GARDE (maintenir) : blocage
GARDE au moment de l'impact : CONTRE (parade)
ESQUIVE : pas de côté invulnérable → contre-attaque
SAUT puis POING / PIED : attaques aériennes
MYSTIQUE : pouvoir (coût + recharge)
TRANSFO (jauge pleine) puis ULTIME : charge ultime
  → sur adversaire faible : TECHNIQUE DE FINITION

Clavier : ZQSD/WASD, J poing, K pied, L prise,
I/Maj garde, U esquive, Espace saut, O mystique,
P transfo/ultime, Échap pause, F3 hitboxes"""

func _close_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false

# =============================================================== options
func _show_options() -> void:
	var root := Control.new()
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 24)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, get_viewport().get_visible_rect().size.y - 70)
	panel.add_child(scroll)
	var v := _vbox(8)
	v.custom_minimum_size = Vector2(690, 0)
	scroll.add_child(v)
	v.add_child(UiTheme.title("OPTIONS", 48))
	var q := OptionButton.new()
	for n in Settings.QUALITY_NAMES:
		q.add_item("Graphismes : " + n)
	q.selected = Settings.quality
	q.item_selected.connect(func(i):
		Settings.quality = i
		Settings.apply()
		Settings.save()
		_free_stage()
		_show_options())
	v.add_child(q)
	_check(v, "Économie d'énergie (30 FPS)", Settings.eco_mode, func(on): Settings.eco_mode = on; Settings.apply())
	_check(v, "Résolution interne adaptative", Settings.adaptive_resolution, func(on): Settings.adaptive_resolution = on)
	_check(v, "Afficher les FPS", Settings.show_fps, func(on): Settings.show_fps = on)
	_check(v, "Afficher hitboxes / hurtboxes", Settings.show_hitboxes, func(on): Settings.show_hitboxes = on)
	_check(v, "Forcer les commandes tactiles", Settings.force_touch, func(on): Settings.force_touch = on)
	_check(v, "Vibrations", Settings.vibration, func(on): Settings.vibration = on)
	_slider(v, "Opacité des commandes", Settings.touch_opacity, 0.2, 1.0, func(x): Settings.touch_opacity = x)
	_slider(v, "Taille des commandes", Settings.touch_scale, 0.7, 1.4, func(x): Settings.touch_scale = x)
	_slider(v, "Volume général", Settings.master_volume, 0.0, 1.0, func(x): Settings.master_volume = x; Settings._apply_audio())
	_slider(v, "Musique", Settings.music_volume, 0.0, 1.0, func(x): Settings.music_volume = x; Settings._apply_audio())
	_slider(v, "Effets sonores", Settings.sfx_volume, 0.0, 1.0, func(x): Settings.sfx_volume = x; Settings._apply_audio())
	v.add_child(UiTheme.button("Retour", func():
		Settings.save()
		_show_main_menu()))
	_ensure_stage()
	_set_screen(root)

func _check(v: VBoxContainer, text: String, val: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = val
	c.toggled.connect(func(on):
		cb.call(on)
		Settings.save())
	v.add_child(c)

func _slider(v: VBoxContainer, text: String, val: float, lo: float, hi: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(340, 40)
	s.value_changed.connect(func(x): cb.call(x))
	h.add_child(s)
	v.add_child(h)

# =============================================================== outils (CLI)
## --selftest : simule des combats IA contre IA sans rendu et vérifie les règles.
func _run_selftest() -> void:
	var problems := _validate_data()
	for pb in problems:
		print("DONNÉES: ", pb)
	var results := {}
	var t0 := Time.get_ticks_msec()
	var total_ticks := 0
	var errors := 0
	var max_us := 0
	var sum_us := 0
	for lv in [[0, 3], [1, 1], [3, 0], [2, 2]]:
		for pair in [[&"mokonzi", &"nkosi"], [&"nkosi", &"mokonzi"]]:
			for rep in 3:
				var m := Match.new()
				add_child(m)
				m.setup(Roster.by_id(pair[0]), Roster.by_id(pair[1]), 0, 1, lv[1], false, true, true)
				(m.ais[0] as FighterAI).setup(m.fighters[0], lv[0])
				m.set_physics_process(false)
				var done := [false]
				var res := [{}]
				m.finished.connect(func(r): done[0] = true; res[0] = r)
				var guard := 0
				while not done[0] and guard < 60 * 60 * 8:
					m.step()
					guard += 1
					for ft in m.fighters:
						if is_nan(ft.position.x) or absf(ft.position.x) > 3.5 or absf(ft.position.z) > 3.5 or ft.hp < 0.0 or ft.hp > ft.data.max_hp + 0.01:
							errors += 1
							print("ANOMALIE tick=%d f=%d state=%s pos=%s hp=%.1f" % [guard, ft.index, Fighter.S.keys()[ft.state], ft.position, ft.hp])
				if not done[0]:
					print("BLOCAGE phase=%d t=%d states=%s/%s hp=%.1f/%.1f wins=%s timer=%d" % [m.phase, m.phase_t, Fighter.S.keys()[m.fighters[0].state], Fighter.S.keys()[m.fighters[1].state], m.fighters[0].hp, m.fighters[1].hp, m.wins, m.timer_frames])
				total_ticks += guard
				sum_us += m.logic_usec_total
				max_us = maxi(max_us, m.logic_usec_max)
				var key := "IA%d vs IA%d" % [lv[0], lv[1]]
				if not results.has(key):
					results[key] = {"p1_wins": 0, "p2_wins": 0, "timeouts": 0, "reasons": {}}
				if res[0].is_empty():
					results[key].timeouts += 1
				else:
					results[key]["p1_wins" if res[0].p1_won else "p2_wins"] += 1
					var rs: String = res[0].reason
					results[key].reasons[rs] = results[key].reasons.get(rs, 0) + 1
					for k in ["hits", "grabs", "powers", "parries", "transforms", "ults"]:
						results[key][k] = results[key].get(k, 0) + res[0].stats[k][0] + res[0].stats[k][1]
				m.free()
	errors += problems.size()
	var report := {"results": results, "errors": errors, "data_problems": problems.size(), "ticks": total_ticks,
		"avg_logic_us_per_tick": float(sum_us) / maxf(1, total_ticks), "max_logic_us": max_us,
		"wall_ms": Time.get_ticks_msec() - t0}
	print("SELFTEST ", JSON.stringify(report, "  "))
	get_tree().quit(0 if errors == 0 else 1)

## Cohérence des données : chaque coup référence une animation existante,
## chaque enchaînement un coup existant, chaque prise ses deux animations.
func _validate_data() -> Array[String]:
	var out: Array[String] = []
	for d in Roster.all():
		for id in d.moves:
			var m: MoveData = d.moves[id]
			if not AnimLib.has_anim(m.anim):
				out.append("%s/%s : animation %s absente" % [d.id, id, m.anim])
			elif m.total_frames() <= 0:
				out.append("%s/%s : frame data invalide" % [d.id, id])
			for a in m.chain:
				if not d.moves.has(m.chain[a]):
					out.append("%s/%s : enchaînement vers %s inexistant" % [d.id, id, m.chain[a]])
		if d.playable:
			for a in [d.intro_anim, d.victory_anim]:
				if not AnimLib.has_anim(a):
					out.append("%s : animation %s absente" % [d.id, a])
			if d.power == null or not d.power.implemented:
				out.append("%s : pouvoir non implémenté" % d.id)
	for k in GrabLib.SEQS:
		var sq: Dictionary = GrabLib.SEQS[k]
		for a in [sq.atk_anim, sq.def_anim]:
			if not AnimLib.has_anim(a):
				out.append("prise %s : animation %s absente" % [k, a])
	for a in [&"ult_rush", &"cast_push", &"cast_ground", &"transform", &"pin_atk", &"pinned", &"getup", &"lying", &"knock_fly", &"ko_fall", &"dodge", &"dodge_back", &"defeat"]:
		if not AnimLib.has_anim(a):
			out.append("animation système %s absente" % a)
	return out

## --benchmark [secondes] : combat IA contre IA rendu, mesure FPS et temps de frame.
func _start_benchmark(args: PackedStringArray) -> void:
	var secs := 30.0
	for a in args:
		if a.is_valid_float():
			secs = float(a)
	for a in args:
		if a.begins_with("--quality="):
			Settings.quality = int(a.split("=")[1])
	Settings.adaptive_resolution = false
	Settings.apply()
	Game.mode = Game.Mode.QUICK
	Game.p1_id = &"mokonzi"
	Game.p2_id = &"nkosi"
	Game.rounds_to_win = 99
	_start_match(true)
	_match.rounds_to_win = 99
	if "--nohud" in args:
		_match.hud.visible = false
	if "--probe2d" in args:
		await get_tree().create_timer(2.0).timeout
		var h := _match.hud
		var vp := get_viewport()
		var probe := func(label: String):
			for i in 6:
				await get_tree().process_frame
			print("PROBE2D %s : %d" % [label, vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)])
		await probe.call("tout")
		for c in h.get_children():
			if c is Label:
				c.visible = false
		h.set_process(false)
		await probe.call("sans labels")
		h._pause_btn.visible = false
		await probe.call("sans bouton pause")
		h.f = [null, null]
		h.match_ref = null
		h.queue_redraw()
		await probe.call("sans barres")
		h.visible = false
		await probe.call("HUD masqué")
		get_tree().quit()
		return
	_bench = {"frames": [], "t": 0.0, "secs": secs, "draws": 0, "prims": 0, "n": 0}
	var timer := Timer.new()
	add_child(timer)
	set_process(true)
	while _bench.t < secs:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		_bench.t += dt
		if _bench.t > 3.0:
			_bench.frames.append(dt)
			_bench.draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			_bench.prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			_bench.n += 1
	var fr: Array = _bench.frames
	fr.sort()
	var sum := 0.0
	for x in fr:
		sum += x
	var n := maxi(1, fr.size())
	var report := {
		"quality": Settings.QUALITY_NAMES[Settings.quality], "scale_3d": Settings.current_scale,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"avg_fps": n / maxf(sum, 0.0001), "avg_frame_ms": sum / n * 1000.0,
		"p95_frame_ms": fr[int(n * 0.95)] * 1000.0 if fr.size() > 0 else 0.0,
		"p99_frame_ms": fr[int(n * 0.99)] * 1000.0 if fr.size() > 0 else 0.0,
		"avg_draw_calls": float(_bench.draws) / n, "avg_primitives": float(_bench.prims) / n,
		"logic_avg_us": float(_match.logic_usec_total) / maxf(1, _match.stats.ticks), "logic_max_us": _match.logic_usec_max,
		"static_mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"viewport": get_viewport().get_visible_rect().size,
		"geometry_nodes": _count_geometry(_match),
		"objects_3d": get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"draw_calls_3d": get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"draw_calls_shadows": get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"draw_calls_2d": get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
	}
	print("BENCHMARK ", JSON.stringify(report, "  "))
	get_tree().quit()

func _count_geometry(n: Node) -> Dictionary:
	var c := {"mesh": 0, "multimesh": 0, "particles": 0, "label3d": 0, "lights": 0}
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is MeshInstance3D and (x as MeshInstance3D).is_visible_in_tree():
			c.mesh += 1
		elif x is MultiMeshInstance3D:
			c.multimesh += 1
		elif x is CPUParticles3D:
			c.particles += 1
		elif x is Label3D:
			c.label3d += 1
		elif x is Light3D:
			c.lights += 1
		stack.append_array(x.get_children())
	return c

## --shot=<scène> [--advance=ticks] [--frames=n] [--out=fichier] : captures d'écran.
func _shot_mode(args: PackedStringArray) -> void:
	var what := "fight"
	var out := "user://shot.png"
	var advance := 0
	var frames := 12
	for a in args:
		if a.begins_with("--shot="):
			what = a.split("=")[1]
		elif a.begins_with("--out="):
			out = a.split("=")[1]
		elif a.begins_with("--advance="):
			advance = int(a.split("=")[1])
		elif a.begins_with("--frames="):
			frames = int(a.split("=")[1])
		elif a.begins_with("--quality="):
			Settings.quality = int(a.split("=")[1])
	Settings.adaptive_resolution = false
	Settings.apply()
	match what:
		"menu":
			_show_main_menu()
		"select":
			Game.start_run(Game.Mode.QUICK)
			_show_select()
		_:
			Game.mode = Game.Mode.QUICK
			if what == "touch":
				Settings.force_touch = true
			_start_match(what != "touch")
			_match.set_physics_process(false)
			if what != "intro":
				_match._start_phase(Match.Phase.ROUND_START)
				_match._start_phase(Match.Phase.FIGHT)
			if what == "transform":
				_match.fighters[0].energy = 100.0
				_match.fighters[0].position = Vector3(-1.0, 0, 0)
				_match.fighters[1].position = Vector3(1.0, 0, 0)
				var c := FighterCmd.new()
				c.press(&"ultimate")
				_match.fighters[0].tick(c)
			elif what == "grab":
				_match.fighters[0].position = Vector3(-0.5, 0, 0)
				_match.fighters[1].position = Vector3(0.5, 0, 0)
				_match.fighters[0].face_now()
				_match.fighters[1].face_now()
				_match.try_grab(_match.fighters[0], &"slam")
			elif what == "power":
				_match.fighters[0].energy = 60.0
				var c2 := FighterCmd.new()
				c2.press(&"power")
				_match.fighters[0].tick(c2)
			for i in advance:
				_match.step()
				for ft in _match.fighters:
					if ft.rig:
						ft.rig._physics_process(0.0)
	var t0 := Time.get_ticks_msec()
	for i in frames:
		await get_tree().process_frame
	var ms := float(Time.get_ticks_msec() - t0) / frames
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT saved %s  (%.0f ms/frame, %s)" % [ProjectSettings.globalize_path(out), ms, RenderingServer.get_current_rendering_method()])
	get_tree().quit()
