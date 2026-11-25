## Thème d'interface généré en code (aucune ressource externe).
class_name UiTheme
extends RefCounted

const YELLOW := Color(0.97, 0.84, 0.1)
const RED := Color(0.82, 0.06, 0.09)
const BLUE := Color(0.0, 0.5, 0.95)
const BG := Color(0.05, 0.04, 0.08, 0.86)

static var _theme: Theme

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	var normal := _box(Color(0.08, 0.07, 0.12, 0.92), Color(1, 1, 1, 0.15))
	var hover := _box(Color(0.16, 0.12, 0.2, 0.95), YELLOW)
	var pressed := _box(Color(0.5, 0.05, 0.08, 0.95), YELLOW)
	var disabled := _box(Color(0.06, 0.06, 0.08, 0.7), Color(1, 1, 1, 0.06))
	var focus := _box(Color(0, 0, 0, 0), YELLOW)
	focus.draw_center = false
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled, "focus": focus}[k]
		t.set_stylebox(k, "Button", sb)
		t.set_stylebox(k, "OptionButton", sb)
	t.set_color("font_color", "Button", Color(0.95, 0.95, 0.95))
	t.set_color("font_hover_color", "Button", YELLOW)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_font_size("font_size", "Button", 24)
	t.set_font_size("font_size", "Label", 22)
	t.set_font_size("font_size", "CheckButton", 22)
	t.set_font_size("font_size", "OptionButton", 22)
	var panel := _box(BG, Color(1, 1, 1, 0.08))
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.2, 0.2, 0.25)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider_bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = YELLOW
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme = t
	return t

static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.skew = Vector2(0.12, 0)
	return s

static func title(text: String, size := 64, color := YELLOW) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 12
	ls.outline_color = Color(0.05, 0.02, 0.05)
	ls.shadow_size = 8
	ls.shadow_color = Color(0, 0, 0, 0.5)
	l.label_settings = ls
	return l

static func button(text: String, cb: Callable, min_w := 360) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 54)
	b.pressed.connect(func():
		Sfx.play(&"ui", 0.0)
		cb.call())
	return b
