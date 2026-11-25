## HUD : barres de vie (avec traînée de dégâts), endurance, énergie mystique,
## chrono, manches, compteur de combo, annonces, données d'entraînement.
class_name Hud
extends Control

signal pause_requested

var match_ref  # Match
var f: Array = [null, null]
var _ghost := [1.0, 1.0]
var _font: Font
var _announce: Label
var _sub: Label
var _ann_t := 0.0
var _sub_t := 0.0
var _combo := [0, 0]
var _combo_t := [0.0, 0.0]
var _side_msgs := [["", 0.0], ["", 0.0]]
var _pause_btn: Button
var info_text := ""
var _fps_label: Label
var _text_reqs: Array = []
var _bars: Array = []
var _bars_rect: ColorRect
var _lbl_pool: Array[Label] = []

const C_HP := Color(0.98, 0.82, 0.15)
const C_HP_LOW := Color(0.95, 0.2, 0.15)
const C_GHOST := Color(0.85, 0.1, 0.1)
const C_STAM := Color(0.3, 0.9, 0.45)
const C_EN := Color(0.7, 0.35, 1.0)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_bars_rect = ColorRect.new()
	_bars_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/hud_bars.gdshader")
	_bars_rect.material = bm
	add_child(_bars_rect)
	_announce = _make_label(84, Color(1, 0.9, 0.3))
	_sub = _make_label(34, Color(1, 1, 1))
	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.custom_minimum_size = Vector2(64, 48)
	_pause_btn.add_theme_font_size_override("font_size", 24)
	_pause_btn.pressed.connect(func(): pause_requested.emit())
	add_child(_pause_btn)
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	add_child(_fps_label)

func _make_label(size: int, col: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = 14
	ls.outline_color = Color(0.05, 0.02, 0.05)
	ls.shadow_size = 6
	ls.shadow_color = Color(0, 0, 0, 0.5)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l

func announce(text: String, duration := 1.2, color := Color(1, 0.9, 0.3)) -> void:
	_announce.text = text
	_announce.label_settings.font_color = color
	_announce.modulate.a = 1.0
	_announce.scale = Vector2.ONE
	_ann_t = duration

func subtitle(text: String, duration := 1.5) -> void:
	_sub.text = text
	_sub.modulate.a = 1.0
	_sub_t = duration

func side_msg(idx: int, text: String) -> void:
	_side_msgs[idx] = [text, 1.1]

func combo(attacker_idx: int, hits: int) -> void:
	if hits >= 2:
		_combo[attacker_idx] = hits
		_combo_t[attacker_idx] = 1.4

func _process(dt: float) -> void:
	var rdt := dt / maxf(Engine.time_scale, 0.05)
	for i in 2:
		if f[i]:
			var r: float = f[i].hp_ratio()
			if _ghost[i] > r:
				_ghost[i] = move_toward(_ghost[i], r, rdt * 0.35)
			else:
				_ghost[i] = r
		_combo_t[i] = maxf(0.0, _combo_t[i] - rdt)
		_side_msgs[i][1] = maxf(0.0, _side_msgs[i][1] - rdt)
	_announce.visible = _ann_t > 0.0
	_sub.visible = _sub_t > 0.0
	if _ann_t > 0.0:
		_ann_t -= rdt
		_announce.pivot_offset = _announce.size / 2
		if _ann_t < 0.3:
			_announce.modulate.a = maxf(0.0, _ann_t / 0.3)
	if _sub_t > 0.0:
		_sub_t -= rdt
		if _sub_t < 0.3:
			_sub.modulate.a = maxf(0.0, _sub_t / 0.3)
	var vs := get_viewport_rect().size
	_pause_btn.position = Vector2(vs.x / 2 - 32, 86)
	_sub.position.y = vs.y * 0.14
	_fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		_fps_label.text = "%d FPS  | 3D x%.2f | %s" % [Engine.get_frames_per_second(), Settings.current_scale, Settings.QUALITY_NAMES[Settings.quality]]
		_fps_label.position = Vector2(12, vs.y - 28)
	_layout()
	_apply_texts()
	_apply_bars(vs)

func _layout() -> void:
	_bars.clear()
	var vs := get_viewport_rect().size
	var margin := 22.0
	var bar_w := vs.x * 0.5 - 80.0 - margin
	for i in 2:
		var ft: Fighter = f[i]
		if ft == null:
			continue
		var left := i == 0
		var x0 := margin if left else vs.x * 0.5 + 80.0
		var y0 := 40.0
		# vie
		_bar(Rect2(x0, y0, bar_w, 24), _ghost[i], ft.hp_ratio(), not left, C_HP_LOW if ft.hp_ratio() < 0.25 else C_HP, C_GHOST)
		# nom
		var name := ft.data.display_name.to_upper()
		var fs := 22
		var nx := x0 if left else x0 + bar_w - _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(Vector2(nx, y0 - 8), name, fs, Color.WHITE)
		# endurance
		_bar(Rect2(x0, y0 + 28, bar_w * 0.55 if left else bar_w * 0.55, 7), ft.stamina / ft.data.max_stamina, ft.stamina / ft.data.max_stamina, not left, C_STAM if not ft.exhausted else Color(0.6, 0.6, 0.6), C_STAM, Vector2(0 if left else bar_w * 0.45, 0))
		# énergie mystique
		var ey := y0 + 42
		var ew := bar_w * 0.62
		var ex := x0 if left else x0 + bar_w - ew
		var ratio: float = ft.transform_ratio() if ft.transformed else ft.energy / 100.0
		var ecol: Color = ft.data.aura_color if ft.transformed else (C_EN if ft.energy < 100.0 else C_EN.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)))
		_bars.append([Rect2(ex, ey, ew, 12), ratio, ratio, not left, ecol, ecol, 4])
		var etxt := ft.data.transform_name.to_upper() if ft.transformed else ("TRANSFORMATION PRÊTE" if ft.energy >= 100.0 else "MYSTIQUE")
		var etw := _font.get_string_size(etxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(Vector2(ex if left else ex + ew - etw, ey + 28), etxt, 14, ecol.lightened(0.3))
		# manches gagnées
		if match_ref:
			for w in match_ref.rounds_to_win:
				var cx: float = (x0 + bar_w - 14 - w * 22) if left else (x0 + 14 + w * 22)
				var won: bool = match_ref.wins[i] > w
				var pc := Color(1, 0.85, 0.2) if won else Color(0.15, 0.15, 0.2)
				_bars.append([Rect2(cx - 6, y0 - 21, 12, 12), 1.0, 1.0, false, pc, pc, 0])
		# combo
		if _combo_t[i] > 0.0:
			var ctxt := "%d COUPS" % _combo[i]
			var cy := vs.y * 0.32
			var cx2 := 40.0 if left else vs.x - 40.0 - _font.get_string_size(ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
			_text(Vector2(cx2, cy), ctxt, 38, Color(1, 0.85, 0.2))
		if _side_msgs[i][1] > 0.0:
			var t: String = _side_msgs[i][0]
			var cx3 := 40.0 if left else vs.x - 40.0 - _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			_text(Vector2(cx3, vs.y * 0.32 + 40), t, 28, Color(0.6, 0.9, 1.0, minf(1.0, _side_msgs[i][1] * 3.0)))
	# chrono
	if match_ref:
		var tt: String = match_ref.timer_text()
		var tw := _font.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		_bars.append([Rect2(vs.x / 2 - 50, 14, 100, 60), 1.0, 1.0, false, Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.45), 0])
		_text(Vector2(vs.x / 2 - tw / 2, 60), tt, 44, Color.WHITE)
	if info_text != "":
		var lines := info_text.split("\n")
		var y := 150.0
		_bars.append([Rect2(16, y - 20, 326, 24 * lines.size() + 6), 1.0, 1.0, false, Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), 0])
		for l in lines:
			_text(Vector2(22, y), l, 17, Color(0.9, 0.95, 1.0))
			y += 24

func _bar(r: Rect2, ghost: float, val: float, rtl: bool, col: Color, ghost_col: Color, off := Vector2.ZERO) -> void:
	r.position += off
	_bars.append([r, val, ghost, rtl, col, ghost_col, 0])

## Toutes les jauges sont rendues par un seul shader (1 draw call).
func _apply_bars(vs: Vector2) -> void:
	var n := mini(_bars.size(), 16)
	var rects := PackedVector4Array()
	var vals := PackedVector4Array()
	var cols := PackedColorArray()
	var gcols := PackedColorArray()
	rects.resize(16)
	vals.resize(16)
	cols.resize(16)
	gcols.resize(16)
	for i in n:
		var b: Array = _bars[i]
		var r: Rect2 = b[0]
		rects[i] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
		vals[i] = Vector4(clampf(b[1], 0, 1), clampf(b[2], 0, 1), 1.0 if b[3] else 0.0, float(b[6]))
		cols[i] = b[4]
		gcols[i] = b[5]
	var m := _bars_rect.material as ShaderMaterial
	m.set_shader_parameter("screen_size", vs)
	m.set_shader_parameter("count", n)
	m.set_shader_parameter("rects", rects)
	m.set_shader_parameter("vals", vals)
	m.set_shader_parameter("cols", cols)
	m.set_shader_parameter("ghost_cols", gcols)

## Les textes passent par des Label recyclés (texte mis en forme une seule fois,
## rendu groupé) ; jauges dans un seul shader : ~500 -> ~13 draw calls 2D.
func _text(p: Vector2, t: String, size: int, col: Color) -> void:
	_text_reqs.append([p, t, size, col])

func _apply_texts() -> void:
	var n := _text_reqs.size()
	while _lbl_pool.size() < n:
		var l := Label.new()
		var ls := LabelSettings.new()
		ls.outline_size = 6
		l.label_settings = ls
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_lbl_pool.append(l)
	for i in _lbl_pool.size():
		var l := _lbl_pool[i]
		if i >= n:
			if l.visible:
				l.visible = false
			continue
		var r: Array = _text_reqs[i]
		var size: int = r[2]
		var col: Color = r[3]
		l.visible = true
		if l.text != r[1]:
			l.text = r[1]
		var ls := l.label_settings
		if ls.font_size != size:
			ls.font_size = size
		if ls.font_color != col:
			ls.font_color = col
			ls.outline_color = Color(0, 0, 0, 0.85 * col.a)
		var pos: Vector2 = r[0] - Vector2(0, size * 1.08)
		if l.position != pos:
			l.position = pos
	_text_reqs.clear()
