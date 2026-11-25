## Rendu d'un combattant : modèle articulé procédural (ou modèle GLB optionnel)
## animé par poses clés. Ne contient AUCUNE logique de combat : il lit l'état
## exposé par Fighter (anim, anim_frame, marks, transformation) et l'affiche.
class_name FighterRig
extends Node3D

const SKIN_SHADER := preload("res://shaders/skin.gdshader")
const CLOTH_SHADER := preload("res://shaders/cloth.gdshader")
const AURA_SHADER := preload("res://shaders/aura.gdshader")
const BLOB_SHADER := preload("res://shaders/blob_shadow.gdshader")
const BLEND_TIME := 0.09

var fighter  # Fighter (non typé pour éviter une dépendance cyclique)
var data: FighterData
var costume: Dictionary
var joints: Dictionary = {}
var _pelvis_base := Vector3(0, 1.0, 0)

var mat_skin: ShaderMaterial
var mat_skin_plain: ShaderMaterial
var mat_trunks: ShaderMaterial
var mat_accent: StandardMaterial3D
var mat_boots: StandardMaterial3D
var mat_eyes: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_aura: ShaderMaterial
var _all_mats: Array[Material] = []

var _cur_anim: StringName = &""
var _blend := 1.0
var _snap: Dictionary = {}
var _snap_pos := Vector3.ZERO
var _flash := 0.0
var _aura_level := 0.0
var _aura_particles: CPUParticles3D
var _blob: MeshInstance3D
var _glb_skeleton: Skeleton3D
var _glb_map: Dictionary = {}
# lissage visuel entre deux ticks logiques (60 Hz) : fluide en ralenti et à >60 FPS
var _xf_prev := Transform3D()
var _xf_cur := Transform3D()

func setup(f, d: FighterData, costume_index: int) -> void:
	fighter = f
	top_level = true
	_xf_prev = f.global_transform
	_xf_cur = _xf_prev
	global_transform = _xf_cur
	data = d
	costume = d.costume(costume_index)
	_make_materials()
	if d.model_scene_path != "" and ResourceLoader.exists(d.model_scene_path):
		_build_glb(d.model_scene_path)
	else:
		_build_procedural()
		# fusion des pièces rigides de chaque articulation (moins de draw calls)
		for j in joints.values():
			MeshFactory.merge_children(j)
	_build_fx()

# ------------------------------------------------------------------ matériaux
func _make_materials() -> void:
	mat_skin = ShaderMaterial.new()
	mat_skin.shader = SKIN_SHADER
	mat_skin.set_shader_parameter("skin_color", data.skin_color)
	mat_skin.set_shader_parameter("paint_color", data.paint_color)
	mat_skin.set_shader_parameter("paint_pattern", data.paint_pattern)
	mat_skin.set_shader_parameter("glow_color", data.aura_color)
	mat_skin_plain = mat_skin.duplicate()
	mat_skin_plain.set_shader_parameter("paint_pattern", 0)
	mat_trunks = ShaderMaterial.new()
	mat_trunks.shader = CLOTH_SHADER
	mat_trunks.set_shader_parameter("col_a", costume.get("trunks", Color.RED))
	mat_trunks.set_shader_parameter("col_b", costume.get("trunks2", Color.YELLOW))
	mat_trunks.set_shader_parameter("col_c", Color(0.06, 0.05, 0.08))
	mat_trunks.set_shader_parameter("pattern", costume.get("pattern", 0))
	mat_accent = _std(costume.get("accent", Color.YELLOW), 0.45, 0.1)
	mat_boots = _std(costume.get("boots", Color(0.1, 0.1, 0.1)), 0.35, 0.0)
	mat_dark = _std(Color(0.05, 0.04, 0.04), 0.7, 0.0)
	mat_gold = _std(Color(0.95, 0.72, 0.2), 0.3, 0.85)
	mat_eyes = StandardMaterial3D.new()
	mat_eyes.albedo_color = Color(0.95, 0.93, 0.9)
	mat_eyes.emission_enabled = true
	mat_eyes.emission = Color(0, 0, 0)
	mat_aura = ShaderMaterial.new()
	mat_aura.shader = AURA_SHADER
	mat_aura.set_shader_parameter("aura_color", data.aura_color)
	mat_aura.set_shader_parameter("intensity", 0.0)
	_all_mats = [mat_skin, mat_skin_plain, mat_trunks]

func _std(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0 - rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.2
	return m

# ------------------------------------------------------------------ squelette
func _joint(name: StringName, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = String(name)
	j.position = pos
	parent.add_child(j)
	joints[name] = j
	return j

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _build_procedural() -> void:
	var h := data.height
	var b := data.bulk
	var root := Node3D.new()
	root.name = "Model"
	add_child(root)
	_pelvis_base = Vector3(0, 1.0 * h, 0)
	var pelvis := _joint(&"pelvis", root, _pelvis_base)
	var spine := _joint(&"spine", pelvis, Vector3(0, 0.12 * h, 0))
	var chest := _joint(&"chest", spine, Vector3(0, 0.2 * h, 0))
	var neck := _joint(&"neck", chest, Vector3(0, 0.36 * h, -0.01))
	var head := _joint(&"head", neck, Vector3(0, 0.08 * h, 0))
	var sh_w := 0.205 * b
	var sh_l := _joint(&"sh_l", chest, Vector3(-sh_w, 0.31 * h, 0))
	var el_l := _joint(&"el_l", sh_l, Vector3(0, -0.29 * h, 0))
	var hd_l := _joint(&"hd_l", el_l, Vector3(0, -0.26 * h, 0))
	var sh_r := _joint(&"sh_r", chest, Vector3(sh_w, 0.31 * h, 0))
	var el_r := _joint(&"el_r", sh_r, Vector3(0, -0.29 * h, 0))
	var hd_r := _joint(&"hd_r", el_r, Vector3(0, -0.26 * h, 0))
	var hip_l := _joint(&"hip_l", pelvis, Vector3(-0.095 * b, -0.06 * h, 0))
	var kn_l := _joint(&"kn_l", hip_l, Vector3(0, -0.45 * h, 0))
	var ft_l := _joint(&"ft_l", kn_l, Vector3(0, -0.44 * h, 0))
	var hip_r := _joint(&"hip_r", pelvis, Vector3(0.095 * b, -0.06 * h, 0))
	var kn_r := _joint(&"kn_r", hip_r, Vector3(0, -0.45 * h, 0))
	var ft_r := _joint(&"ft_r", kn_r, Vector3(0, -0.44 * h, 0))

	# --- Tronc
	_mesh(pelvis, MeshFactory.lathe("pelvis_%.2f_%.2f" % [b, h], [
		Vector3(-0.15 * h, 0.001, 0.001), Vector3(-0.14 * h, 0.12 * b, 0.09 * b), Vector3(-0.08 * h, 0.168 * b, 0.122 * b),
		Vector3(0.0, 0.172 * b, 0.124 * b), Vector3(0.08 * h, 0.16 * b, 0.116 * b), Vector3(0.13 * h, 0.152 * b, 0.11 * b)], 16), mat_trunks)
	_mesh(pelvis, MeshFactory.torus(0.155 * b, 0.016, 1.0, 0.72), mat_accent, Vector3(0, 0.12 * h, 0))
	_mesh(spine, MeshFactory.lathe("abdo_%.2f_%.2f" % [b, h], [
		Vector3(-0.02, 0.15 * b, 0.108 * b), Vector3(0.08 * h, 0.148 * b, 0.11 * b), Vector3(0.2 * h, 0.16 * b, 0.118 * b), Vector3(0.24 * h, 0.168 * b, 0.12 * b)], 16), mat_skin_plain)
	_mesh(chest, MeshFactory.lathe("chest_%.2f_%.2f" % [b, h], [
		Vector3(0.0, 0.165 * b, 0.118 * b), Vector3(0.1 * h, 0.185 * b, 0.13 * b), Vector3(0.22 * h, 0.215 * b, 0.14 * b),
		Vector3(0.3 * h, 0.21 * b, 0.125 * b), Vector3(0.35 * h, 0.15 * b, 0.1 * b), Vector3(0.385 * h, 0.06 * b, 0.05 * b), Vector3(0.39 * h, 0.001, 0.001)], 16), mat_skin_plain)
	# pectoraux, trapèzes, abdominaux
	for s in [-1.0, 1.0]:
		_mesh(chest, MeshFactory.ellipsoid(0.085 * b, 0.068 * b, 0.05 * b), mat_skin_plain, Vector3(s * 0.085 * b, 0.235 * h, -0.105 * b), Vector3(0, 0, s * -8))
		_mesh(chest, MeshFactory.ellipsoid(0.07 * b, 0.05 * b, 0.06 * b), mat_skin_plain, Vector3(s * 0.11 * b, 0.33 * h, 0.01), Vector3(0, 0, s * 25))
	for i in 3:
		for s in [-1.0, 1.0]:
			_mesh(spine, MeshFactory.ellipsoid(0.04 * b, 0.032, 0.02), mat_skin_plain, Vector3(s * 0.042 * b, 0.03 + i * 0.07 * h, -0.105 * b))
	# --- Cou / tête
	_mesh(neck, MeshFactory.limb(0.1 * h, 0.06 * b, 0.065 * b, 0.0), mat_skin_plain, Vector3(0, 0.1 * h, 0))
	_build_head(head, h, b)
	# --- Bras
	for side in [&"l", &"r"]:
		var s := -1.0 if side == &"l" else 1.0
		var sh: Node3D = joints[StringName("sh_" + side)]
		var el: Node3D = joints[StringName("el_" + side)]
		var hd: Node3D = joints[StringName("hd_" + side)]
		_mesh(sh, MeshFactory.ellipsoid(0.08 * b, 0.075 * b, 0.075 * b), mat_skin, Vector3(s * 0.015, -0.01, 0))
		_mesh(sh, MeshFactory.limb(0.29 * h, 0.062 * b, 0.048 * b, 0.02 * b, 0.4), mat_skin)
		_mesh(el, MeshFactory.limb(0.26 * h, 0.05 * b, 0.036 * b, 0.013 * b, 0.25), mat_skin)
		_mesh(el, MeshFactory.limb(0.06, 0.043 * b, 0.043 * b, 0.0), mat_accent, Vector3(0, -0.19 * h, 0))
		_mesh(hd, MeshFactory.ellipsoid(0.046 * b, 0.055, 0.05), mat_skin_plain, Vector3(0, -0.045, -0.005))
		_mesh(hd, MeshFactory.ellipsoid(0.02, 0.03, 0.022), mat_skin_plain, Vector3(s * -0.035, -0.035, -0.035))
		if data.shoulder_pads and side == &"l":
			_mesh(sh, MeshFactory.ellipsoid(0.1 * b, 0.07 * b, 0.1 * b), mat_trunks, Vector3(s * 0.02, 0.02, 0), Vector3(0, 0, s * 20))
			_mesh(sh, MeshFactory.torus(0.085 * b, 0.012, 1.0, 1.0), mat_gold, Vector3(s * 0.01, -0.05, 0), Vector3(0, 0, s * 20))
	# --- Jambes
	for side in [&"l", &"r"]:
		var s := -1.0 if side == &"l" else 1.0
		var hip: Node3D = joints[StringName("hip_" + side)]
		var kn: Node3D = joints[StringName("kn_" + side)]
		var ft: Node3D = joints[StringName("ft_" + side)]
		_mesh(hip, MeshFactory.limb(0.45 * h, 0.098 * b, 0.062 * b, 0.016 * b, 0.3), mat_skin)
		_mesh(hip, MeshFactory.limb(0.16 * h, 0.104 * b, 0.096 * b, 0.0), mat_trunks, Vector3(0, 0.02, 0))
		_mesh(kn, MeshFactory.limb(0.44 * h, 0.064 * b, 0.044 * b, 0.016 * b, 0.25), mat_skin)
		_mesh(kn, MeshFactory.limb(0.24 * h, 0.066 * b, 0.054 * b, 0.008 * b, 0.1), mat_boots, Vector3(0, -0.21 * h, 0))
		_mesh(kn, MeshFactory.ellipsoid(0.07 * b, 0.075, 0.06), mat_accent, Vector3(0, 0.0, -0.035))
		_mesh(ft, MeshFactory.ellipsoid(0.058 * b, 0.05, 0.13), mat_boots, Vector3(0, -0.02, -0.06))
		_mesh(ft, MeshFactory.limb(0.012, 0.06 * b, 0.06 * b, 0.0, 0.5, 2.3), mat_accent, Vector3(0, -0.055, -0.06))
	if data.necklace:
		_mesh(chest, MeshFactory.torus(0.1 * b, 0.014, 1.0, 0.85), mat_gold, Vector3(0, 0.355 * h, -0.02), Vector3(-25, 0, 0))
		_mesh(chest, MeshFactory.ellipsoid(0.025, 0.035, 0.012), mat_gold, Vector3(0, 0.29 * h, -0.135 * b))
		_mesh(chest, MeshFactory.ellipsoid(0.012, 0.012, 0.012), mat_eyes, Vector3(0, 0.29 * h, -0.148 * b))

func _build_head(head: Node3D, h: float, b: float) -> void:
	var cy := 0.12 * h
	_mesh(head, MeshFactory.ellipsoid(0.1, 0.122, 0.112, 18, 12), mat_skin_plain, Vector3(0, cy, 0))
	_mesh(head, MeshFactory.ellipsoid(0.083, 0.06, 0.088), mat_skin_plain, Vector3(0, cy - 0.065, -0.025))
	_mesh(head, MeshFactory.ellipsoid(0.022, 0.032, 0.03), mat_skin_plain, Vector3(0, cy - 0.01, -0.112))
	for s in [-1.0, 1.0]:
		_mesh(head, MeshFactory.ellipsoid(0.018, 0.032, 0.022), mat_skin_plain, Vector3(s * 0.1, cy, 0.0))
		_mesh(head, MeshFactory.ellipsoid(0.019, 0.013, 0.01), mat_eyes, Vector3(s * 0.04, cy + 0.02, -0.1))
		_mesh(head, MeshFactory.ellipsoid(0.03, 0.008, 0.012), mat_dark, Vector3(s * 0.04, cy + 0.045, -0.104), Vector3(0, 0, s * -8))
	_mesh(head, MeshFactory.ellipsoid(0.03, 0.007, 0.01), _std(data.skin_color.darkened(0.35), 0.4, 0.0), Vector3(0, cy - 0.055, -0.105))
	match data.hair_style:
		1:
			_mesh(head, MeshFactory.dome(0.106, 0.13, 0.118, 0.1), mat_dark, Vector3(0, cy + 0.006, 0.004))
		2:
			pass
		_:
			_mesh(head, MeshFactory.dome(0.104, 0.128, 0.116, 0.3), mat_dark, Vector3(0, cy + 0.004, 0.004))
	if data.beard:
		_mesh(head, MeshFactory.ellipsoid(0.07, 0.045, 0.07), mat_dark, Vector3(0, cy - 0.085, -0.04))
	if data.mask:
		var mask_mat := ShaderMaterial.new()
		mask_mat.shader = CLOTH_SHADER
		mask_mat.set_shader_parameter("col_a", costume.get("trunks", Color.BLUE))
		mask_mat.set_shader_parameter("col_b", costume.get("trunks2", Color.YELLOW))
		mask_mat.set_shader_parameter("col_c", costume.get("accent", Color.RED))
		mask_mat.set_shader_parameter("pattern", 2)
		mask_mat.set_shader_parameter("scale", 3.0)
		_all_mats.append(mask_mat)
		_mesh(head, MeshFactory.dome(0.108, 0.13, 0.12, -0.05), mask_mat, Vector3(0, cy + 0.002, 0))
		# ouvertures pour les yeux (contours)
		for s in [-1.0, 1.0]:
			_mesh(head, MeshFactory.torus(0.024, 0.006, 1.0, 0.7), mat_accent, Vector3(s * 0.04, cy + 0.02, -0.108), Vector3(90, 0, 0))
	if data.headband:
		var band := StandardMaterial3D.new()
		band.albedo_color = costume.get("trunks2", Color.YELLOW)
		_mesh(head, MeshFactory.torus(0.108, 0.013, 1.0, 1.08), band, Vector3(0, cy + 0.055, 0.0), Vector3(-6, 0, 0))

# ------------------------------------------------------------------ GLB (optionnel)
## Branche un modèle importé (GLB/FBX avec squelette humanoïde). Les noms d'os
## usuels (Mixamo / Rigify) sont associés aux articulations de AnimLib.
const GLB_BONES := {
	&"pelvis": ["Hips", "mixamorig:Hips", "pelvis"], &"spine": ["Spine", "mixamorig:Spine", "spine_01"],
	&"chest": ["Spine2", "mixamorig:Spine2", "spine_03"], &"neck": ["Neck", "mixamorig:Neck", "neck_01"],
	&"head": ["Head", "mixamorig:Head", "head"],
	&"sh_l": ["LeftArm", "mixamorig:LeftArm", "upperarm_l"], &"el_l": ["LeftForeArm", "mixamorig:LeftForeArm", "lowerarm_l"],
	&"hd_l": ["LeftHand", "mixamorig:LeftHand", "hand_l"],
	&"sh_r": ["RightArm", "mixamorig:RightArm", "upperarm_r"], &"el_r": ["RightForeArm", "mixamorig:RightForeArm", "lowerarm_r"],
	&"hd_r": ["RightHand", "mixamorig:RightHand", "hand_r"],
	&"hip_l": ["LeftUpLeg", "mixamorig:LeftUpLeg", "thigh_l"], &"kn_l": ["LeftLeg", "mixamorig:LeftLeg", "calf_l"],
	&"ft_l": ["LeftFoot", "mixamorig:LeftFoot", "foot_l"],
	&"hip_r": ["RightUpLeg", "mixamorig:RightUpLeg", "thigh_r"], &"kn_r": ["RightLeg", "mixamorig:RightLeg", "calf_r"],
	&"ft_r": ["RightFoot", "mixamorig:RightFoot", "foot_r"],
}

func _build_glb(path: String) -> void:
	var scene: PackedScene = load(path)
	var inst := scene.instantiate()
	add_child(inst)
	_glb_skeleton = _find_skeleton(inst)
	if _glb_skeleton == null:
		push_warning("Modèle %s sans Skeleton3D : rendu statique." % path)
		return
	for j in GLB_BONES:
		for n in GLB_BONES[j]:
			var idx := _glb_skeleton.find_bone(n)
			if idx >= 0:
				_glb_map[j] = idx
				break

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null

# ------------------------------------------------------------------ effets
func _build_fx() -> void:
	_blob = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.orientation = PlaneMesh.FACE_Y
	_blob.mesh = q
	var bm := ShaderMaterial.new()
	bm.shader = BLOB_SHADER
	_blob.material_override = bm
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob.position.y = 0.012
	add_child(_blob)
	_aura_particles = CPUParticles3D.new()
	_aura_particles.emitting = false
	_aura_particles.amount = int(36 * Settings.profile().particles)
	_aura_particles.lifetime = 0.7
	_aura_particles.local_coords = false
	_aura_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_aura_particles.emission_box_extents = Vector3(0.28, 0.75, 0.2)
	_aura_particles.direction = Vector3(0, 1, 0)
	_aura_particles.spread = 15.0
	_aura_particles.gravity = Vector3(0, 2.5, 0)
	_aura_particles.initial_velocity_min = 0.6
	_aura_particles.initial_velocity_max = 1.6
	_aura_particles.scale_amount_min = 0.5
	_aura_particles.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	_aura_particles.scale_amount_curve = curve
	var pm := QuadMesh.new()
	pm.size = Vector2(0.12, 0.2)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.vertex_color_use_as_albedo = true
	pmat.albedo_texture = FxTextures.soft_dot()
	pm.material = pmat
	_aura_particles.mesh = pm
	var grad := Gradient.new()
	grad.set_color(0, data.aura_color.lightened(0.5))
	grad.set_color(1, Color(data.aura_color, 0.0))
	_aura_particles.color_ramp = grad
	_aura_particles.position = Vector3(0, 1.0, 0)
	add_child(_aura_particles)

func flash(amount := 1.0) -> void:
	_flash = maxf(_flash, amount)

# ------------------------------------------------------------------ mise à jour
func _physics_process(_dt: float) -> void:
	if fighter == null:
		return
	_xf_prev = _xf_cur
	_xf_cur = fighter.global_transform
	if _xf_prev.origin.distance_to(_xf_cur.origin) > 1.5:
		_xf_prev = _xf_cur

func _process(dt: float) -> void:
	if fighter == null:
		return
	if fighter is Fighter:
		global_transform = _xf_prev.interpolate_with(_xf_cur, Engine.get_physics_interpolation_fraction())
	else:
		global_transform = fighter.global_transform
	_update_pose(dt)
	_update_effects(dt)

func _mapped_frame(anim: Dictionary, frame: float) -> float:
	var am: Vector3i = anim.marks
	var sm: Vector3i = fighter.anim_marks
	if am == Vector3i.ZERO or sm == Vector3i.ZERO:
		return frame
	if frame <= sm.x:
		return frame / maxf(1.0, sm.x) * am.x
	if frame <= sm.y:
		return am.x + (frame - sm.x) / maxf(1.0, sm.y - sm.x) * (am.y - am.x)
	return am.y + (frame - sm.y) / maxf(1.0, sm.z - sm.y) * (am.z - am.y)

func _update_pose(dt: float) -> void:
	var anim_id: StringName = fighter.anim
	if anim_id != _cur_anim:
		_cur_anim = anim_id
		_snap.clear()
		for j in joints:
			_snap[j] = (joints[j] as Node3D).quaternion
		if joints.has(&"pelvis"):
			_snap_pos = joints[&"pelvis"].position - _pelvis_base
		_blend = 0.0
	var a := AnimLib.get_anim(anim_id)
	var fr: float = fighter.anim_frame
	if not fighter.anim_frozen:
		fr += Engine.get_physics_interpolation_fraction()
	var pose := AnimLib.sample(anim_id, _mapped_frame(a, fr))
	_blend = minf(1.0, _blend + dt / BLEND_TIME)
	var w := _blend * _blend * (3.0 - 2.0 * _blend)
	for j in joints:
		var e: Vector3 = pose.get(j, Vector3.ZERO)
		var q := Quaternion.from_euler(e * (PI / 180.0))
		if w < 1.0 and _snap.has(j):
			q = (_snap[j] as Quaternion).slerp(q, w)
		(joints[j] as Node3D).quaternion = q
	if joints.has(&"pelvis"):
		var p: Vector3 = pose.get(&"pos", Vector3.ZERO)
		if w < 1.0:
			p = _snap_pos.lerp(p, w)
		joints[&"pelvis"].position = _pelvis_base + p * data.height
	if _glb_skeleton:
		for j in _glb_map:
			var e2: Vector3 = pose.get(j, Vector3.ZERO)
			var bi: int = _glb_map[j]
			_glb_skeleton.set_bone_pose_rotation(bi, _glb_skeleton.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion.from_euler(e2 * (PI / 180.0)))

func _update_effects(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt * 6.0)
	var target := 1.0 if fighter.transformed else 0.0
	_aura_level = move_toward(_aura_level, target, dt * 2.0)
	for m in _all_mats:
		(m as ShaderMaterial).set_shader_parameter("flash", _flash)
	mat_skin.set_shader_parameter("glow", _aura_level)
	var use_shell: bool = Settings.profile().aura_shell
	var want_pass: Material = mat_aura if (_aura_level > 0.01 and use_shell) else null
	if mat_skin.next_pass != want_pass:
		mat_skin.next_pass = want_pass
		mat_skin_plain.next_pass = want_pass
		mat_trunks.next_pass = want_pass
	mat_aura.set_shader_parameter("intensity", _aura_level * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.02)))
	var eye_target: Color = data.transform_eye_color * 3.0 if fighter.transformed else Color(0, 0, 0)
	mat_eyes.emission = mat_eyes.emission.lerp(eye_target, minf(1.0, dt * 6.0))
	_aura_particles.emitting = fighter.transformed
	if joints.has(&"pelvis"):
		var pp: Vector3 = joints[&"pelvis"].position
		_aura_particles.position = Vector3(pp.x, pp.y, pp.z)
		# ombre de contact : suit le bassin, se rétracte en hauteur
		var gy: float = fighter.global_position.y
		_blob.position = Vector3(pp.x, 0.012 - gy, pp.z)
		var sc := clampf(1.0 - gy * 0.35, 0.4, 1.0)
		var lying := pp.y < 0.5
		_blob.scale = Vector3(sc * (1.0 if not lying else 1.3), 1, sc * (1.0 if not lying else 1.9))

## Position mondiale d'une articulation (pour les effets).
func joint_global(name: StringName) -> Vector3:
	if joints.has(name):
		return (joints[name] as Node3D).global_position
	return global_position + Vector3(0, 1.2, 0)
