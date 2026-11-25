## Réglages : profils graphiques, FPS, économie d'énergie, contrôles.
## Sauvegardés dans user://settings.cfg.
extends Node

signal changed

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const QUALITY_NAMES := ["Faible", "Moyen", "Élevé", "Ultra"]
const DIFFICULTY_NAMES := ["Facile", "Normal", "Difficile", "Maître"]

## Profils graphiques. scale = résolution interne 3D maximale.
const PROFILES := {
	Quality.LOW: {"scale": 0.6, "min_scale": 0.5, "msaa": Viewport.MSAA_DISABLED, "shadows": false,
		"shadow_size": 1024, "glow": false, "crowd": 140, "particles": 0.4, "fog": false, "lights": 1, "aura_shell": false},
	Quality.MEDIUM: {"scale": 0.8, "min_scale": 0.55, "msaa": Viewport.MSAA_2X, "shadows": true,
		"shadow_size": 1024, "glow": true, "crowd": 320, "particles": 0.7, "fog": false, "lights": 2, "aura_shell": true},
	Quality.HIGH: {"scale": 0.92, "min_scale": 0.65, "msaa": Viewport.MSAA_2X, "shadows": true,
		"shadow_size": 2048, "glow": true, "crowd": 560, "particles": 1.0, "fog": true, "lights": 3, "aura_shell": true},
	Quality.ULTRA: {"scale": 1.0, "min_scale": 0.75, "msaa": Viewport.MSAA_4X, "shadows": true,
		"shadow_size": 4096, "glow": true, "crowd": 900, "particles": 1.25, "fog": true, "lights": 4, "aura_shell": true},
}

const PATH := "user://settings.cfg"

var quality: int = Quality.MEDIUM
var eco_mode := false
var adaptive_resolution := true
var show_fps := false
var show_hitboxes := false
var difficulty := 1
var master_volume := 0.85
var music_volume := 0.55
var sfx_volume := 0.9
var touch_opacity := 0.65
var touch_scale := 1.0
var force_touch := false
var vibration := true

## Échelle 3D courante (ajustée dynamiquement par la résolution adaptative).
var current_scale := 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	quality = _default_quality()
	_load()
	_setup_input_map()
	apply()

func _default_quality() -> int:
	if OS.has_feature("mobile"):
		return Quality.MEDIUM
	return Quality.HIGH

func profile() -> Dictionary:
	return PROFILES[quality]

func target_fps() -> int:
	return 30 if eco_mode else 60

func apply() -> void:
	Engine.max_fps = target_fps()
	var p := profile()
	current_scale = p.scale
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = current_scale
		vp.msaa_3d = p.msaa
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_debanding = false
	RenderingServer.directional_shadow_atlas_set_size(p.shadow_size, true)
	_apply_audio()
	changed.emit()

func set_render_scale(s: float) -> void:
	current_scale = clampf(s, profile().min_scale, profile().scale)
	get_viewport().scaling_3d_scale = current_scale

func _apply_audio() -> void:
	for bus_name in ["Master", "Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var v: float = master_volume if bus_name == "Master" else (music_volume if bus_name == "Music" else sfx_volume)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)

func save() -> void:
	var c := ConfigFile.new()
	for k in ["quality", "eco_mode", "adaptive_resolution", "show_fps", "show_hitboxes", "difficulty",
			"master_volume", "music_volume", "sfx_volume", "touch_opacity", "touch_scale", "force_touch", "vibration"]:
		c.set_value("settings", k, get(k))
	c.save(PATH)

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	for k in c.get_section_keys("settings"):
		if k in self:
			set(k, c.get_value("settings", k))

func touch_enabled() -> bool:
	return force_touch or DisplayServer.is_touchscreen_available()

func vibrate(ms: int) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# --- Commandes clavier / manette (tests) ---
func _setup_input_map() -> void:
	var keys := {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
		&"punch": [KEY_J], &"kick": [KEY_K], &"grab": [KEY_L], &"block": [KEY_I, KEY_SHIFT],
		&"dodge": [KEY_U], &"jump": [KEY_SPACE], &"power": [KEY_O], &"ultimate": [KEY_P],
		&"pause": [KEY_ESCAPE], &"debug_hitbox": [KEY_F3],
	}
	var pads := {
		&"punch": [JOY_BUTTON_X], &"kick": [JOY_BUTTON_Y], &"grab": [JOY_BUTTON_B],
		&"block": [JOY_BUTTON_RIGHT_SHOULDER], &"dodge": [JOY_BUTTON_LEFT_SHOULDER],
		&"jump": [JOY_BUTTON_A], &"pause": [JOY_BUTTON_START],
		&"move_left": [JOY_BUTTON_DPAD_LEFT], &"move_right": [JOY_BUTTON_DPAD_RIGHT],
		&"move_up": [JOY_BUTTON_DPAD_UP], &"move_down": [JOY_BUTTON_DPAD_DOWN],
	}
	var axes := {
		&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0],
		&"move_up": [JOY_AXIS_LEFT_Y, -1.0], &"move_down": [JOY_AXIS_LEFT_Y, 1.0],
		&"power": [JOY_AXIS_TRIGGER_RIGHT, 1.0], &"ultimate": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in pads:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for b in pads[action]:
			var e := InputEventJoypadButton.new()
			e.button_index = b
			InputMap.action_add_event(action, e)
	for action in axes:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		var e := InputEventJoypadMotion.new()
		e.axis = axes[action][0]
		e.axis_value = axes[action][1]
		InputMap.action_add_event(action, e)
