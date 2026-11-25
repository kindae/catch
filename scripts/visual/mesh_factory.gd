## Génération de maillages organiques (tours / lathe à section elliptique).
## Les maillages sont mis en cache et partagés entre combattants.
class_name MeshFactory
extends RefCounted

static var _cache: Dictionary = {}

## profile : Array de Vector3(y, rx, rz). Génère une surface de révolution
## à section elliptique, normales lisses, UV (u = angle, v = position le long).
static func lathe(key: String, profile: Array, segments := 14, z_shift := 0.0) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := profile.size()
	var y0: float = profile[0].x
	var y1: float = profile[rings - 1].x
	var span := absf(y1 - y0)
	for r in rings:
		var pr: Vector3 = profile[r]
		for s in segments + 1:
			var a := TAU * float(s) / segments
			var x := cos(a) * pr.y
			var z := sin(a) * pr.z + z_shift * pr.z
			st.set_uv(Vector2(float(s) / segments, absf(pr.x - y0) / maxf(span, 0.001)))
			st.add_vertex(Vector3(x, pr.x, z))
	for r in rings - 1:
		for s in segments:
			var i0 := r * (segments + 1) + s
			var i1 := i0 + 1
			var i2 := i0 + segments + 1
			var i3 := i2 + 1
			# Godot : faces avant dans le sens horaire
			if y1 < y0:
				st.add_index(i0); st.add_index(i2); st.add_index(i1)
				st.add_index(i1); st.add_index(i2); st.add_index(i3)
			else:
				st.add_index(i0); st.add_index(i1); st.add_index(i2)
				st.add_index(i1); st.add_index(i3); st.add_index(i2)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

## Membre effilé le long de -Y (de 0 à -length) avec renflement musculaire
## et extrémités arrondies.
static func limb(length: float, r0: float, r1: float, bulge := 0.0, bulge_at := 0.4, flat := 1.0, segments := 12, rings := 10) -> ArrayMesh:
	var key := "limb_%.3f_%.3f_%.3f_%.3f_%.2f_%.2f" % [length, r0, r1, bulge, bulge_at, flat]
	if _cache.has(key):
		return _cache[key]
	var prof := []
	var cap := 4
	# calotte supérieure
	for i in cap:
		var a := PI * 0.5 * (1.0 - float(i) / cap)
		prof.append(Vector3(sin(a) * r0 * 0.8, cos(a) * r0, cos(a) * r0 * flat))
	for i in rings + 1:
		var t := float(i) / rings
		var r := lerpf(r0, r1, t) + bulge * exp(-pow((t - bulge_at) / 0.22, 2.0))
		prof.append(Vector3(-t * length, r, r * flat))
	for i in range(1, cap + 1):
		var a := PI * 0.5 * float(i) / cap
		prof.append(Vector3(-length - sin(a) * r1 * 0.8, cos(a) * r1 + 0.0005, (cos(a) * r1 + 0.0005) * flat))
	return lathe(key, prof, segments)

static func ellipsoid(rx: float, ry: float, rz: float, segments := 14, rings := 10) -> ArrayMesh:
	var key := "ell_%.3f_%.3f_%.3f_%d" % [rx, ry, rz, segments]
	if _cache.has(key):
		return _cache[key]
	var prof := []
	for i in rings + 1:
		var a := PI * float(i) / rings
		prof.append(Vector3(cos(a) * ry, sin(a) * rx + 0.0005, sin(a) * rz + 0.0005))
	return lathe(key, prof, segments)

## Calotte (haut d'ellipsoïde) : cheveux, masques.
static func dome(rx: float, ry: float, rz: float, cut: float, segments := 16) -> ArrayMesh:
	var key := "dome_%.3f_%.3f_%.3f_%.2f" % [rx, ry, rz, cut]
	if _cache.has(key):
		return _cache[key]
	var prof := []
	var rings := 8
	var a_max := acos(clampf(cut, -1.0, 1.0))
	for i in rings + 1:
		var a := a_max * float(i) / rings
		prof.append(Vector3(cos(a) * ry, sin(a) * rx + 0.0005, sin(a) * rz + 0.0005))
	prof.reverse()
	return lathe(key, prof, segments)

static func torus(r: float, thick: float, sx := 1.0, sz := 1.0) -> ArrayMesh:
	var key := "torus_%.3f_%.3f_%.2f_%.2f" % [r, thick, sx, sz]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 20
	var sides := 6
	for i in seg + 1:
		var a := TAU * i / seg
		for j in sides + 1:
			var b := TAU * j / sides
			var c := Vector3(cos(a) * sx, 0, sin(a) * sz) * r
			var n := Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b))
			st.set_normal(n)
			st.set_uv(Vector2(float(i) / seg, float(j) / sides))
			st.add_vertex(c + n * thick)
	for i in seg:
		for j in sides:
			var i0 := i * (sides + 1) + j
			var i1 := i0 + 1
			var i2 := i0 + sides + 1
			var i3 := i2 + 1
			st.add_index(i0); st.add_index(i2); st.add_index(i1)
			st.add_index(i1); st.add_index(i2); st.add_index(i3)
	var m := st.commit()
	_cache[key] = m
	return m

## Fusionne des MeshInstance3D partageant le même matériau en un seul maillage
## (réduction des draw calls). Les transformations locales sont conservées.
## Retourne le nombre d'instances supprimées.
static func merge_children(parent: Node3D, only_primitive := false) -> int:
	var groups := {}
	for c in parent.get_children():
		if not (c is MeshInstance3D) or c.get_child_count() > 0:
			continue
		var mi := c as MeshInstance3D
		if mi.mesh == null or mi.material_override == null or mi.mesh.get_surface_count() != 1:
			continue
		if only_primitive and not (mi.mesh is PrimitiveMesh):
			continue
		var k := "%d_%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
		if not groups.has(k):
			groups[k] = []
		groups[k].append(mi)
	var removed := 0
	for k in groups:
		var list: Array = groups[k]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			st.append_from(mi.mesh, 0, mi.transform)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = list[0].material_override
		merged.cast_shadow = list[0].cast_shadow
		merged.name = "Merged"
		parent.add_child(merged)
		for mi in list:
			parent.remove_child(mi)
			mi.free()
			removed += 1
	return removed
