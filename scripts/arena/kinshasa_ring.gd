## Arène 1 : Ring populaire de Kinshasa, de nuit. Ring aux couleurs du drapeau,
## tribunes en tôle, foule instanciée, guirlandes, rampe de projecteurs.
## Éclairage : 1 lumière directionnelle (ombres selon profil) + spot + contre-jour.
## Les décors lointains utilisent des matériaux non éclairés (« éclairage précalculé »
## intégré à la couleur) pour limiter le coût GPU.
class_name KinshasaRing
extends ArenaBase

const RING_MAT := preload("res://shaders/ring_mat.gdshader")
const CLOTH := preload("res://shaders/cloth.gdshader")
const CROWD := preload("res://shaders/crowd.gdshader")
const FX := preload("res://shaders/fx_add.gdshader")

const RING := 3.8
const FLAG_BLUE := Color(0.0, 0.5, 0.95)
const FLAG_RED := Color(0.82, 0.06, 0.09)
const FLAG_YELLOW := Color(0.97, 0.84, 0.1)

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 243
	var prof := Settings.profile()
	_build_environment(prof)
	_build_lights(prof)
	_build_ground()
	_build_ring()
	_build_surroundings()
	_build_crowd(prof.crowd)
	_build_truss()
	# décor statique fusionné par matériau : quelques draw calls au lieu de plusieurs centaines
	MeshFactory.merge_children(self, true)

func _build_environment(prof: Dictionary) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.03, 0.09)
	sm.sky_horizon_color = Color(0.32, 0.16, 0.12)
	sm.ground_bottom_color = Color(0.02, 0.02, 0.03)
	sm.ground_horizon_color = Color(0.2, 0.1, 0.08)
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.3, 0.38)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = prof.glow
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# étalonnage colorimétrique « cinéma » : contraste et saturation renforcés
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.18
	if prof.fog:
		env.fog_enabled = true
		env.fog_light_color = Color(0.2, 0.14, 0.2)
		env.fog_density = 0.012
		env.fog_sky_affect = 0.3
	we.environment = env
	environment = env
	add_child(we)

func _build_lights(prof: Dictionary) -> void:
	# Renderer Compatibility (repli OpenGL) : chaque lumière supplémentaire ajoute
	# une passe de rendu par objet -> une seule lumière dynamique.
	var max_lights: int = prof.lights
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		max_lights = 1
		environment.ambient_light_energy = 0.8
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-62, 25, 0)
	key.shadow_enabled = prof.shadows
	key.shadow_blur = 2.0
	key.shadow_opacity = 0.55
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 16.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.2
	add_child(key)
	if max_lights >= 2:
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 7.5, 0)
		spot.rotation_degrees = Vector3(-90, 0, 0)
		spot.spot_range = 12.0
		spot.spot_angle = 42.0
		spot.spot_attenuation = 0.6
		spot.light_energy = 4.0
		spot.light_color = Color(1.0, 0.85, 0.65)
		spot.shadow_enabled = false
		add_child(spot)
	if max_lights >= 3:
		var rim := DirectionalLight3D.new()
		rim.light_color = Color(0.45, 0.55, 1.0)
		rim.light_energy = 0.55
		rim.rotation_degrees = Vector3(-20, 200, 0)
		rim.shadow_enabled = false
		add_child(rim)

func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 70)
	mi.mesh = pm
	mi.position = Vector3(0, -1.1, 0)
	var m := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.04
	nt.noise = n
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.11, 0.08))
	grad.set_color(1, Color(0.33, 0.24, 0.17))
	nt.color_ramp = grad
	m.albedo_texture = nt
	m.uv1_scale = Vector3(14, 14, 1)
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)

func _build_ring() -> void:
	# tapis
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(RING * 2 + 0.4, RING * 2 + 0.4)
	top.mesh = pm
	var rm := ShaderMaterial.new()
	rm.shader = RING_MAT
	top.material_override = rm
	top.position.y = 0.0
	add_child(top)
	# tablier en wax
	var apron := ShaderMaterial.new()
	apron.shader = CLOTH
	apron.set_shader_parameter("col_a", FLAG_RED)
	apron.set_shader_parameter("col_b", FLAG_YELLOW)
	apron.set_shader_parameter("col_c", FLAG_BLUE)
	apron.set_shader_parameter("pattern", 0)
	apron.set_shader_parameter("scale", 10.0)
	_box(Vector3(RING * 2 + 0.45, 1.08, RING * 2 + 0.45), Vector3(0, -0.56, 0), apron)
	_label("CATCH 243", Vector3(0, -0.5, RING + 0.24), 0, 120, FLAG_YELLOW, Color(0.05, 0.05, 0.1))
	_label("KIN LA BELLE", Vector3(0, -0.5, -RING - 0.24), 180, 110, Color.WHITE, FLAG_RED)
	_label("CATCH 243", Vector3(RING + 0.24, -0.5, 0), 90, 120, FLAG_YELLOW, Color(0.05, 0.05, 0.1))
	_label("CATCH 243", Vector3(-RING - 0.24, -0.5, 0), -90, 120, FLAG_YELLOW, Color(0.05, 0.05, 0.1))
	# poteaux, protections et cordes
	var metal := _std(Color(0.75, 0.75, 0.8), 0.35, 0.8)
	var rope_cols := [FLAG_RED, FLAG_YELLOW, FLAG_BLUE]
	var pad_mats := [_std(FLAG_RED, 0.6), _std(FLAG_YELLOW, 0.6), _std(FLAG_BLUE, 0.6)]
	var rope_mats := []
	for c in rope_cols:
		rope_mats.append(_std(c, 0.45))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * RING, 0, sz * RING)
			_cyl(0.07, 0.08, 1.7, p + Vector3(0, 0.75, 0), metal)
			for i in 3:
				_box(Vector3(0.2, 0.18, 0.2), p + Vector3(0, 0.45 + i * 0.4, 0), pad_mats[i])
	for i in 3:
		var y := 0.45 + i * 0.4
		for side in 4:
			var mi := _cyl(0.024, 0.024, RING * 2, Vector3.ZERO, rope_mats[i], Vector3.ZERO, 6)
			match side:
				0: mi.position = Vector3(0, y, RING); mi.rotation_degrees = Vector3(0, 0, 90)
				1: mi.position = Vector3(0, y, -RING); mi.rotation_degrees = Vector3(0, 0, 90)
				2: mi.position = Vector3(RING, y, 0); mi.rotation_degrees = Vector3(90, 0, 0)
				3: mi.position = Vector3(-RING, y, 0); mi.rotation_degrees = Vector3(90, 0, 0)
	# marches
	var step_mat := _std(Color(0.2, 0.2, 0.22), 0.7, 0.4)
	for i in 3:
		_box(Vector3(1.2, 0.33, 0.4), Vector3(RING - 0.8, -0.95 + i * 0.33, RING + 0.45 + (2 - i) * 0.4), step_mat)

func _build_surroundings() -> void:
	# barrières publicitaires (marques fictives)
	var ads := ["RADIO KIN 243", "BOISSON MOKILI", "SAPE & STYLE", "MATONGE FM", "PHARMACIE DU FLEUVE", "LIKEMBE STUDIO", "BOULANGERIE NGOMBE", "TAXI KIN EXPRESS"]
	var cols := [FLAG_BLUE, FLAG_RED, Color(0.1, 0.55, 0.25), Color(0.95, 0.5, 0.1)]
	var d := 6.6
	var idx := 0
	for side in 4:
		for k in 2:
			var off := -2.4 + k * 4.8
			var pos: Vector3
			var ry := 0.0
			match side:
				0: pos = Vector3(off, -0.55, d); ry = 180
				1: pos = Vector3(-off, -0.55, -d); ry = 0
				2: pos = Vector3(d, -0.55, -off); ry = -90
				3: pos = Vector3(-d, -0.55, off); ry = 90
			var b := _box(Vector3(4.6, 1.1, 0.12), pos, _unshaded(cols[idx % cols.size()], 0.8), false)
			b.rotation_degrees.y = ry
			var l := _label(ads[idx % ads.size()], pos + Vector3.UP * 0.0, ry + 180.0, 90, Color.WHITE, Color(0, 0, 0, 0.8))
			l.position += (Vector3.ZERO - Vector3(pos.x, 0, pos.z)).normalized() * 0.08
			idx += 1
	# tribunes en gradins
	var tier_mat := _std(Color(0.22, 0.2, 0.2), 0.9)
	for side in 4:
		for t in 4:
			var dist := 8.0 + t * 1.1
			var h := -0.9 + t * 0.55
			var size := Vector3(18.0 + t * 2.2, 0.5, 1.1)
			var pos := Vector3(0, h, dist)
			var mi := _box(size, Vector3.ZERO, tier_mat, false)
			var a := side * 90.0
			mi.position = pos.rotated(Vector3.UP, deg_to_rad(a))
			mi.rotation_degrees.y = a
	# murs en tôle, bâtiments et fenêtres éclairées (non éclairés = coût minimal)
	var wall := _unshaded(Color(0.16, 0.13, 0.12))
	var win := _unshaded(Color(1.0, 0.7, 0.32), 0.95)
	var win2 := _unshaded(Color(0.55, 0.75, 1.0), 0.8)
	var facade := _unshaded(Color(0.16, 0.13, 0.17))
	var facade2 := _unshaded(Color(0.2, 0.15, 0.12))
	for side in 4:
		var a := deg_to_rad(side * 90.0)
		var w := _box(Vector3(28, 3.0, 0.3), Vector3(0, 0.6, 13.6).rotated(Vector3.UP, a), wall, false)
		w.rotation.y = a
		for bi in 5:
			var bh := _rng.randf_range(5.0, 11.0)
			var bx := -12.0 + bi * 6.0 + _rng.randf_range(-1, 1)
			var bpos := Vector3(bx, bh * 0.5 - 1.0, 17.0 + _rng.randf_range(0, 3)).rotated(Vector3.UP, a)
			var bm := _box(Vector3(4.5, bh, 3.5), bpos, facade if bi % 2 == 0 else facade2, false)
			bm.rotation.y = a
			# toit-terrasse et fenêtres en grille (immeubles de Kinshasa la nuit)
			var roof := _box(Vector3(4.7, 0.25, 3.7), bpos + Vector3.UP * (bh * 0.5), _unshaded(Color(0.1, 0.08, 0.09)), false)
			roof.rotation.y = a
			for wy in int(bh / 1.4):
				for wx in 3:
					if _rng.randf() < 0.4:
						var wp := bpos + Vector3(-1.4 + wx * 1.4, -bh * 0.5 + 1.0 + wy * 1.4, -1.76).rotated(Vector3.UP, a)
						var wm := _box(Vector3(0.55, 0.6, 0.05), wp, win if _rng.randf() < 0.7 else win2, false)
						wm.rotation.y = a
	# palmiers (silhouettes)
	var trunk := _unshaded(Color(0.12, 0.09, 0.07))
	var leaf := _unshaded(Color(0.04, 0.09, 0.05))
	for i in 6:
		var ang := TAU * i / 6.0 + 0.4
		var p := Vector3(sin(ang), 0, cos(ang)) * 15.5
		_cyl(0.12, 0.2, 7.0, p + Vector3(0, 2.5, 0), trunk, Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), 6)
		for k in 6:
			var lm := _box(Vector3(0.5, 0.05, 2.6), p + Vector3(0, 6.0, 0), leaf, false)
			lm.rotation_degrees = Vector3(25, k * 60.0, 0)
			lm.translate_object_local(Vector3(0, 0, 1.1))
	# guirlandes lumineuses (MultiMesh)
	var bulbs := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 6
	sphere.rings = 3
	mm.mesh = sphere
	var count := 160
	mm.instance_count = count
	var bulb_cols := [FLAG_YELLOW, FLAG_RED, FLAG_BLUE, Color(0.3, 1.0, 0.4), Color(1, 0.6, 0.2)]
	for i in count:
		var s := i / 40
		var t := float(i % 40) / 39.0
		var a0 := deg_to_rad(s * 90.0 + 45.0)
		var a1 := deg_to_rad(s * 90.0 + 135.0)
		var p0 := Vector3(sin(a0), 0, cos(a0)) * 10.5
		var p1 := Vector3(sin(a1), 0, cos(a1)) * 10.5
		var p := p0.lerp(p1, t)
		p.y = 4.2 - sin(t * PI) * 0.9
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		var c: Color = bulb_cols[i % bulb_cols.size()]
		mm.set_instance_color(i, c * 2.5)
	bulbs.multimesh = mm
	var bm2 := StandardMaterial3D.new()
	bm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm2.vertex_color_use_as_albedo = true
	bulbs.material_override = bm2
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulbs)

## Foule : un seul MultiMesh, une seule draw call, animation dans le shader.
func _build_crowd(count: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skin := Color(0.3, 0.18, 0.11, 0.0)
	var shirt := Color(1, 1, 1, 1.0)
	_add_box(st, Vector3(0, 0.75, 0), Vector3(0.42, 0.62, 0.24), shirt)
	_add_box(st, Vector3(0, 0.25, 0), Vector3(0.36, 0.5, 0.22), Color(0.12, 0.12, 0.16, 0.0))
	_add_box(st, Vector3(0, 1.2, 0), Vector3(0.22, 0.25, 0.22), skin)
	_add_box(st, Vector3(-0.27, 1.25, 0), Vector3(0.1, 0.5, 0.1), skin)
	_add_box(st, Vector3(0.27, 1.25, 0), Vector3(0.1, 0.5, 0.1), skin)
	st.generate_normals()
	var mesh := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	var shirt_cols := [FLAG_BLUE, FLAG_RED, FLAG_YELLOW, Color(0.95, 0.95, 0.95), Color(0.1, 0.6, 0.3), Color(0.9, 0.4, 0.1), Color(0.5, 0.2, 0.6), Color(0.15, 0.15, 0.2)]
	var per_side := maxi(1, count / 4)
	for i in count:
		var side := i % 4
		var k := i / 4
		var tier := k % 4
		var slot := k / 4
		var slots := maxi(1, per_side / 4)
		var width := 16.0 + tier * 2.2
		var x := -width * 0.5 + (float(slot) + 0.5) / slots * width + _rng.randf_range(-0.15, 0.15)
		var pos := Vector3(x, -0.65 + tier * 0.55, 8.0 + tier * 1.1 + _rng.randf_range(-0.1, 0.1))
		var a := deg_to_rad(side * 90.0)
		pos = pos.rotated(Vector3.UP, a)
		var b := Basis(Vector3.UP, a + PI + _rng.randf_range(-0.3, 0.3)).scaled(Vector3.ONE * _rng.randf_range(0.9, 1.1))
		mm.set_instance_transform(i, Transform3D(b, pos))
		var c: Color = shirt_cols[_rng.randi() % shirt_cols.size()]
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	crowd_material = ShaderMaterial.new()
	crowd_material.shader = CROWD
	mmi.material_override = crowd_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _add_box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var center := c + n * h
		var uu := u * h
		var vv := v * h
		var p0 := center - uu - vv
		var p1 := center + uu - vv
		var p2 := center + uu + vv
		var p3 := center - uu + vv
		st.set_color(col)
		# sens horaire vu de l'extérieur
		for p in [p0, p2, p1, p0, p3, p2]:
			st.set_color(col)
			st.add_vertex(p)

func _build_truss() -> void:
	var metal := _std(Color(0.3, 0.3, 0.33), 0.5, 0.7)
	var y := 6.2
	var s := 4.2
	for i in 4:
		var a := deg_to_rad(i * 90.0)
		var b := _box(Vector3(s * 2, 0.18, 0.18), Vector3(0, y, s).rotated(Vector3.UP, a), metal, false)
		b.rotation.y = a
	var bulb := _unshaded(Color(1.0, 0.92, 0.75), 2.2)
	var housing := _std(Color(0.08, 0.08, 0.09), 0.5, 0.6)
	var cone_mat := ShaderMaterial.new()
	cone_mat.shader = FX
	cone_mat.set_shader_parameter("mode", 2)
	cone_mat.set_shader_parameter("color", Color(1.0, 0.85, 0.6))
	cone_mat.set_shader_parameter("alpha", 0.25)
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.15
	cone_mesh.bottom_radius = 1.6
	cone_mesh.height = 6.0
	cone_mesh.radial_segments = 12
	cone_mesh.cap_top = false
	cone_mesh.cap_bottom = false
	for i in 4:
		var a := deg_to_rad(i * 90.0 + 45.0)
		var p := Vector3(sin(a), 0, cos(a)) * s * 1.35 + Vector3.UP * (y - 0.15)
		var lamp := _box(Vector3(0.3, 0.3, 0.3), p + Vector3.UP * 0.2, housing, false)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if Settings.quality >= Settings.Quality.MEDIUM:
			var cone := MeshInstance3D.new()
			cone.mesh = cone_mesh
			cone.material_override = cone_mat
			cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cone)
			var dir := (Vector3(0, 0, 0) - p).normalized()
			cone.position = p + dir * 3.0
			var basis := Basis()
			var up := -dir
			var side := up.cross(Vector3.FORWARD).normalized()
			if side.length() < 0.1:
				side = Vector3.RIGHT
			basis = Basis(side, up, side.cross(up)).orthonormalized()
			cone.basis = basis
