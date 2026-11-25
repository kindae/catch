## Base commune des arènes : limites de combat, environnement, éclairage.
class_name ArenaBase
extends Node3D

## Demi-largeur de la zone de combat (m).
var half_extent := 3.45
var crowd_material: ShaderMaterial
var environment: Environment

func clamp_position(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -half_extent, half_extent)
	p.z = clampf(p.z, -half_extent, half_extent)
	return p

func set_excitement(v: float) -> void:
	if crowd_material:
		crowd_material.set_shader_parameter("excitement", clampf(v, 0.0, 1.0))

func _std(c: Color, rough := 0.8, metal := 0.0, emissive := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	return m

func _unshaded(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * energy, c.g * energy, c.b * energy, c.a)
	return m

func _box(size: Vector3, pos: Vector3, mat: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	mi.mesh = c
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	add_child(mi)
	return mi

func _label(text: String, pos: Vector3, rot_y: float, size := 96, color := Color.WHITE, outline := Color.BLACK) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = outline
	l.outline_size = 14
	l.position = pos
	l.rotation_degrees = Vector3(0, rot_y, 0)
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = false
	add_child(l)
	return l
