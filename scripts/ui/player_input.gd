## Entrée du joueur : fusionne clavier, manette et commandes tactiles, puis
## convertit le joystick (repère écran) en direction monde via la caméra.
class_name PlayerInput
extends RefCounted

var camera: FightCamera
var touch: TouchControls
var _cmd := FighterCmd.new()
const ACTIONS := [&"punch", &"kick", &"grab", &"dodge", &"jump", &"power", &"ultimate"]

func next_cmd() -> FighterCmd:
	_cmd.clear()
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", 0.25)
	if touch and touch.joy_vector.length() > v.length():
		v = touch.joy_vector
	if camera:
		var d := camera.screen_right() * v.x - camera.screen_forward() * v.y
		if d.length() > 1.0:
			d = d.normalized()
		_cmd.dir = d
	_cmd.block = Input.is_action_pressed(&"block") or (touch != null and touch.is_held(&"block"))
	for a in ACTIONS:
		if Input.is_action_just_pressed(a):
			_cmd.press(a)
	if touch:
		for a in touch.consume_presses():
			_cmd.press(a)
	return _cmd
