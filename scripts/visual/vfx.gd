## Effets visuels avec Object Pooling : étincelles d'impact, poussière,
## ondes de choc, explosions d'énergie. Aucun nœud n'est créé pendant le combat.
class_name Vfx
extends Node3D

const FX_SHADER := preload("res://shaders/fx_add.gdshader")

var _sparks: Array[CPUParticles3D] = []
var _dusts: Array[CPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _bursts: Array[MeshInstance3D] = []
var _i_spark := 0
var _i_dust := 0
var _i_ring := 0
var _i_burst := 0
var _active: Array = []  # [node, t, duration, kind, from_scale, to_scale]
var _light: OmniLight3D
var _light_t := 0.0
var _quality := 1.0

func _ready() -> void:
	_quality = Settings.profile().particles
	for i in 6:
		_sparks.append(_make_spark())
	for i in 5:
		_dusts.append(_make_dust())
	for i in 4:
		_rings.append(_make_fx_mesh(0))
	for i in 4:
		_bursts.append(_make_fx_mesh(1))
	if Settings.profile().lights >= 3:
		_light = OmniLight3D.new()
		_light.omni_range = 4.0
		_light.light_energy = 0.0
		_light.shadow_enabled = false
		add_child(_light)

func _quad_mat(tex: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	return m

func _make_spark() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(4, int(16 * _quality))
	p.lifetime = 0.35
	p.direction = Vector3(0, 0, 1)
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = _quad_mat(FxTextures.spark(), true)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.9, 1))
	g.set_color(1, Color(1, 0.5, 0.1, 0))
	p.color_ramp = g
	add_child(p)
	return p

func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = maxi(4, int(14 * _quality))
	p.lifetime = 0.9
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 90.0
	p.flatness = 0.7
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 2.0
	p.damping_max = 3.5
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = _quad_mat(FxTextures.soft_dot(), false)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.68, 0.58, 0.55))
	g.set_color(1, Color(0.6, 0.55, 0.5, 0.0))
	p.color_ramp = g
	add_child(p)
	return p

func _make_fx_mesh(mode: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mode == 0:
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
	else:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 16
		s.rings = 8
		mi.mesh = s
	var m := ShaderMaterial.new()
	m.shader = FX_SHADER
	m.set_shader_parameter("mode", mode)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func spark(pos: Vector3, color := Color(1, 0.8, 0.4), big := false) -> void:
	var p := _sparks[_i_spark]
	_i_spark = (_i_spark + 1) % _sparks.size()
	p.global_position = pos
	p.scale_amount_max = 2.2 if big else 1.4
	p.initial_velocity_max = 8.0 if big else 6.0
	var g := p.color_ramp
	g.set_color(0, color.lightened(0.6))
	g.set_color(1, Color(color, 0.0))
	p.restart()
	p.emitting = true
	if _light:
		_light.global_position = pos
		_light.light_color = color
		_light.light_energy = 3.0 if big else 1.6
		_light_t = 0.12

func dust(pos: Vector3, big := false) -> void:
	var p := _dusts[_i_dust]
	_i_dust = (_i_dust + 1) % _dusts.size()
	p.global_position = Vector3(pos.x, 0.05, pos.z)
	p.initial_velocity_max = 4.0 if big else 2.5
	p.restart()
	p.emitting = true

func ring(pos: Vector3, color: Color, radius := 2.0, duration := 0.45) -> void:
	var mi := _rings[_i_ring]
	_i_ring = (_i_ring + 1) % _rings.size()
	_start(mi, pos, color, 0.15, radius, duration)

func burst(pos: Vector3, color: Color, radius := 1.2, duration := 0.35) -> void:
	var mi := _bursts[_i_burst]
	_i_burst = (_i_burst + 1) % _bursts.size()
	_start(mi, pos, color, 0.2, radius, duration)

func _start(mi: MeshInstance3D, pos: Vector3, color: Color, s0: float, s1: float, dur: float) -> void:
	mi.global_position = pos
	mi.visible = true
	mi.scale = Vector3.ONE * s0
	(mi.material_override as ShaderMaterial).set_shader_parameter("color", color)
	for a in _active:
		if a[0] == mi:
			_active.erase(a)
			break
	_active.append([mi, 0.0, dur, s0, s1])

func _process(dt: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var a: Array = _active[i]
		a[1] += dt
		var t: float = a[1] / a[2]
		var mi: MeshInstance3D = a[0]
		if t >= 1.0:
			mi.visible = false
			_active.remove_at(i)
			continue
		var e := 1.0 - pow(1.0 - t, 3.0)
		mi.scale = Vector3.ONE * lerpf(a[3], a[4], e)
		(mi.material_override as ShaderMaterial).set_shader_parameter("alpha", 1.0 - t)
	if _light and _light_t > 0.0:
		_light_t -= dt
		if _light_t <= 0.0:
			_light.light_energy = 0.0
