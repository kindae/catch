## Commandes tactiles multi-touch : joystick flottant + 9 boutons.
## Dessinées en 2D (une seule Control, aucune texture externe).
class_name TouchControls
extends Control

const BUTTONS := [
	# id, libellé, position relative au coin bas-droit (x, y), rayon, couleur
	[&"punch", "POING", Vector2(-245, -105), 56, Color(0.95, 0.3, 0.2)],
	[&"kick", "PIED", Vector2(-112, -175), 56, Color(0.98, 0.75, 0.15)],
	[&"grab", "PRISE", Vector2(-262, -245), 50, Color(0.3, 0.8, 0.4)],
	[&"jump", "SAUT", Vector2(-118, -315), 44, Color(0.55, 0.6, 0.7)],
	[&"block", "GARDE", Vector2(-382, -110), 48, Color(0.25, 0.55, 0.95)],
	[&"dodge", "ESQUIVE", Vector2(-395, -240), 44, Color(0.6, 0.45, 0.9)],
	[&"power", "MYSTIQUE", Vector2(-258, -385), 46, Color(0.75, 0.35, 1.0)],
	[&"ultimate", "TRANSFO", Vector2(-108, -455), 52, Color(1.0, 0.55, 0.1)],
]

var fighter: Fighter
var joy_vector := Vector2.ZERO
var _joy_touch := -1
var _joy_center := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _joy_radius := 95.0
var _touches: Dictionary = {}   # index -> id bouton
var _held: Dictionary = {}
var _presses: Array[StringName] = []
var _font: Font
var _pad: ColorRect
var _labels: Array[Label] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_joy_center = _default_joy_center()

func _scale() -> float:
	var s := get_viewport_rect().size
	return Settings.touch_scale * clampf(s.y / 720.0, 0.75, 1.6)

func _default_joy_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(190, s.y - 175) * Vector2(1, 1)

func _btn_pos(b: Array) -> Vector2:
	var s := get_viewport_rect().size
	return s + (b[2] as Vector2) * _scale()

func is_held(id: StringName) -> bool:
	return _held.get(id, false)

func consume_presses() -> Array[StringName]:
	var out := _presses.duplicate()
	_presses.clear()
	return out

func _button_at(p: Vector2) -> StringName:
	var best: StringName = &""
	var best_d := 1e9
	for b in BUTTONS:
		var d := p.distance_to(_btn_pos(b))
		var r: float = b[3] * _scale() * 1.25
		if d < r and d < best_d:
			best = b[0]
			best_d = d
	return best

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			var id := _button_at(t.position)
			if id != &"":
				_touches[t.index] = id
				_held[id] = true
				if id != &"block":
					_presses.append(id)
				Settings.vibrate(12)
				get_viewport().set_input_as_handled()
			elif t.position.x < get_viewport_rect().size.x * 0.45 and t.position.y > get_viewport_rect().size.y * 0.25:
				_joy_touch = t.index
				_joy_center = t.position
				_joy_knob = t.position
				joy_vector = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			if t.index == _joy_touch:
				_joy_touch = -1
				joy_vector = Vector2.ZERO
				_joy_center = _default_joy_center()
				_joy_knob = _joy_center
			elif _touches.has(t.index):
				_held[_touches[t.index]] = false
				_touches.erase(t.index)
	elif e is InputEventScreenDrag:
		var dr := e as InputEventScreenDrag
		if dr.index == _joy_touch:
			var r := _joy_radius * _scale()
			var off := dr.position - _joy_center
			if off.length() > r:
				# le joystick suit le doigt (confort sur petits écrans)
				_joy_center += off - off.normalized() * r
				off = off.normalized() * r
			_joy_knob = _joy_center + off
			var v := off / r
			joy_vector = v if v.length() > 0.18 else Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif _touches.has(dr.index):
			# glisser d'un bouton à l'autre (enchaînements rapides)
			var id := _button_at(dr.position)
			var cur: StringName = _touches[dr.index]
			if id != &"" and id != cur:
				_held[cur] = false
				_touches[dr.index] = id
				_held[id] = true
				if id != &"block":
					_presses.append(id)

func _process(_dt: float) -> void:
	_update_visuals()

## Rendu : un ColorRect + shader pour tous les cercles (1 draw call) et des
## Label statiques pour les libellés (mis à jour seulement s'ils changent).
func _update_visuals() -> void:
	if _pad == null:
		_pad = ColorRect.new()
		_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/touch_pad.gdshader")
		_pad.material = m
		add_child(_pad)
		for b in BUTTONS:
			var l := Label.new()
			var ls := LabelSettings.new()
			ls.outline_size = 4
			ls.outline_color = Color(0, 0, 0, 0.7)
			l.label_settings = ls
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)
			_labels.append(l)
	var a := Settings.touch_opacity
	var sc := _scale()
	if _joy_touch < 0:
		_joy_center = _default_joy_center()
		_joy_knob = _joy_center
	var r := _joy_radius * sc
	var discs := PackedVector4Array()
	var extras := PackedVector4Array()
	var cols := PackedColorArray()
	discs.resize(12)
	extras.resize(12)
	cols.resize(12)
	discs[0] = Vector4(_joy_center.x, _joy_center.y, r, 0.0)
	extras[0] = Vector4(0, 0, 3, 0)
	cols[0] = Color(0.1, 0.1, 0.12, 0.8)
	discs[1] = Vector4(_joy_knob.x, _joy_knob.y, r * 0.42, 1.0)
	extras[1] = Vector4(0, 0, 2.5, 0)
	cols[1] = Color(1, 1, 1, 0.8)
	var i := 2
	for bi in BUTTONS.size():
		var b: Array = BUTTONS[bi]
		var id: StringName = b[0]
		var p := _btn_pos(b)
		var rr: float = b[3] * sc
		var col: Color = b[4]
		var label: String = b[1]
		var avail := true
		var cd_ratio := 0.0
		var pulse := 0.0
		if fighter:
			if id == &"power":
				avail = fighter.energy >= fighter.data.power.energy_cost and fighter.power_cd == 0
				cd_ratio = float(fighter.power_cd) / float(maxi(1, fighter.data.power.cooldown))
			elif id == &"ultimate":
				label = "ULTIME" if fighter.transformed else "TRANSFO"
				avail = fighter.transformed or fighter.energy >= 100.0
				if avail:
					pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			elif id == &"dodge":
				avail = not fighter.exhausted
		var state := 1.0 if is_held(id) else (0.0 if avail else 2.0)
		discs[i] = Vector4(p.x, p.y, rr, state)
		extras[i] = Vector4(cd_ratio, pulse, 5.0 if state == 1.0 else 3.0, 0)
		cols[i] = col
		i += 1
		var l: Label = _labels[bi]
		var fs := int((15 if label.length() > 5 else 18) * sc)
		if l.text != label:
			l.text = label
		if l.label_settings.font_size != fs:
			l.label_settings.font_size = fs
		l.size = Vector2(rr * 2, rr * 2)
		l.position = p - Vector2(rr, rr)
		l.modulate.a = a * (1.0 if avail else 0.5)
	var m := _pad.material as ShaderMaterial
	m.set_shader_parameter("screen_size", get_viewport_rect().size)
	m.set_shader_parameter("count", i)
	m.set_shader_parameter("opacity", a)
	m.set_shader_parameter("disc", discs)
	m.set_shader_parameter("extra", extras)
	m.set_shader_parameter("cols", cols)
