extends RefCounted

# Corte da ponte na ORIGEM do asset (.glb).
#
# Referencia do usuario: no cenario ele girou o HighBridge e posicionou a parte
# a ser DELETADA abaixo do plano do grid (mundo Y < 0).
#
# Mapeamento (transform do HighBridge em level_1.tscn, medido no editor):
#   basis.x -> mundo (0, -1, 0)
#   basis.y -> mundo (1, 0, 0)
#   basis.z -> mundo (0, 0, 1)
#   origin  -> (1209.1804, 621.0194, 198.26114)
#   mundo.y = origin.y - source.x
#
# "mundo Y < 0" (parte a deletar) => source.x > 621.0194
# Portanto mantemos source.x <= 621.0194.

const CUT_X_SOURCE := 621.0194
const SRC_PATH := "res://assets/models/levels/high_bridge.glb"
const OUT_PATH := "res://assets/models/levels/high_bridge_cut.tscn"

const A_SRC := 0      # posicao no espaco de ORIGEM (para decidir o corte)
const A_LOC := 1      # posicao local (para gravar de volta na malha)
const A_NORMAL := 2
const A_UV := 3
const A_COLOR := 4
const A_TANGENT := 5


func run() -> void:
	var src: PackedScene = load(SRC_PATH)
	if src == null:
		push_error("clip_bridge: nao carregou " + SRC_PATH)
		return

	var root: Node = src.instantiate()

	var meshes: Array = []
	_collect_meshes(root, Transform3D.IDENTITY, meshes)
	print("clip_bridge: meshes=", meshes.size())

	var clipped := 0
	for item in meshes:
		var mi: MeshInstance3D = item[0]
		var acc: Transform3D = item[1]
		if _clip_mesh_instance(mi, acc):
			clipped += 1

	print("clip_bridge: clipped=", clipped, " / ", meshes.size())

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	if perr != OK:
		push_error("clip_bridge: pack falhou " + str(perr))
		root.free()
		return

	var serr := ResourceSaver.save(packed, OUT_PATH)
	print("clip_bridge: save=", serr, " -> ", OUT_PATH)
	root.free()


func _collect_meshes(n: Node, acc: Transform3D, out: Array) -> void:
	var t: Transform3D = acc
	if n is Node3D:
		t = acc * n.transform
	if n is MeshInstance3D:
		out.append([n, t])
	for c in n.get_children():
		_collect_meshes(c, t, out)


func _clip_mesh_instance(mi: MeshInstance3D, acc: Transform3D) -> bool:
	var mesh := mi.mesh
	if mesh == null:
		return false

	var inv: Transform3D = acc.affine_inverse()

	var new_mesh := ArrayMesh.new()
	var surf_count := mesh.get_surface_count()
	var any_surface := false

	for s in surf_count:
		var prim: int = mesh.surface_get_primitive_type(s)
		var mat := mesh.surface_get_material(s)

		if prim != Mesh.PRIMITIVE_TRIANGLES:
			var arrs2: Array = mesh.surface_get_arrays(s)
			new_mesh.add_surface_from_arrays(prim, arrs2)
			new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mat)
			any_surface = true
			continue

		var arrs: Array = mesh.surface_get_arrays(s)
		var clipped: Array = _clip_triangles(arrs, acc, inv, CUT_X_SOURCE)
		if clipped.size() == 0:
			continue
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clipped)
		new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mat)
		any_surface = true

	mi.mesh = new_mesh
	return any_surface


func _clip_triangles(arrs: Array, acc: Transform3D, inv: Transform3D, cut_x: float) -> Array:
	var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
	if verts.size() == 0:
		return []

	var normals = arrs[Mesh.ARRAY_NORMAL]
	var uvs = arrs[Mesh.ARRAY_TEX_UV]
	var colors = arrs[Mesh.ARRAY_COLOR]
	var tangents = arrs[Mesh.ARRAY_TANGENT]

	var has_n: bool = normals != null and normals.size() == verts.size()
	var has_uv: bool = uvs != null and uvs.size() == verts.size()
	var has_c: bool = colors != null and colors.size() == verts.size()
	var has_t: bool = tangents != null and tangents.size() == verts.size() * 4

	var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]

	var tris: Array = []
	if idx != null and idx.size() > 0:
		var i := 0
		while i + 2 < idx.size():
			tris.append([idx[i], idx[i + 1], idx[i + 2]])
			i += 3
	else:
		var i := 0
		while i + 2 < verts.size():
			tris.append([i, i + 1, i + 2])
			i += 3

	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_colors := PackedColorArray()
	var out_tangents := PackedFloat32Array()

	for tri in tris:
		var poly: Array = []
		for vi in tri:
			var loc: Vector3 = verts[vi]
			var srcpos: Vector3 = acc * loc
			var vtx: Array = [srcpos, loc, null, null, null, null]
			if has_n:
				vtx[A_NORMAL] = normals[vi]
			if has_uv:
				vtx[A_UV] = uvs[vi]
			if has_c:
				vtx[A_COLOR] = colors[vi]
			if has_t:
				var tt := PackedFloat32Array()
				tt.append(tangents[vi * 4])
				tt.append(tangents[vi * 4 + 1])
				tt.append(tangents[vi * 4 + 2])
				tt.append(tangents[vi * 4 + 3])
				vtx[A_TANGENT] = tt
			poly.append(vtx)

		var clipped_poly: Array = _clip_poly(poly, cut_x, inv)
		if clipped_poly.size() < 3:
			continue

		var k := 1
		while k < clipped_poly.size() - 1:
			_emit(clipped_poly[0], clipped_poly[k], clipped_poly[k + 1], out_verts, out_normals, out_uvs, out_colors, out_tangents)
			k += 1

	if out_verts.size() == 0:
		return []

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_verts
	if has_n:
		out[Mesh.ARRAY_NORMAL] = out_normals
	if has_uv:
		out[Mesh.ARRAY_TEX_UV] = out_uvs
	if has_c:
		out[Mesh.ARRAY_COLOR] = out_colors
	if has_t:
		out[Mesh.ARRAY_TANGENT] = out_tangents
	return out


# Mantem pontos com src.x <= cut_x (lado da torre, acima do grid).
func _clip_poly(poly: Array, cut_x: float, inv: Transform3D) -> Array:
	var out: Array = []
	var n := poly.size()
	if n < 3:
		return out

	var i := 0
	while i < n:
		var cur: Array = poly[i]
		var nxt: Array = poly[(i + 1) % n]
		var pc: Vector3 = cur[A_SRC]
		var pn: Vector3 = nxt[A_SRC]

		var cur_in: bool = pc.x <= cut_x
		var nxt_in: bool = pn.x <= cut_x

		if cur_in:
			out.append(cur)

		if cur_in != nxt_in:
			var d0: float = pc.x - cut_x
			var d1: float = pn.x - cut_x
			var denom: float = d0 - d1
			var t: float = 0.0 if is_zero_approx(denom) else (d0 / denom)
			out.append(_lerp_vtx(cur, nxt, t, inv))

		i += 1

	return out


func _lerp_vtx(a: Array, b: Array, t: float, inv: Transform3D) -> Array:
	var sa: Vector3 = a[A_SRC]
	var sb: Vector3 = b[A_SRC]
	var src_lerp: Vector3 = sa.lerp(sb, t)
	var loc: Vector3 = inv * src_lerp

	var r: Array = [src_lerp, loc, null, null, null, null]

	if a[A_NORMAL] != null:
		var na: Vector3 = a[A_NORMAL]
		var nb: Vector3 = b[A_NORMAL]
		r[A_NORMAL] = na.lerp(nb, t)
	if a[A_UV] != null:
		var ua: Vector2 = a[A_UV]
		var ub: Vector2 = b[A_UV]
		r[A_UV] = ua.lerp(ub, t)
	if a[A_COLOR] != null:
		var ca: Color = a[A_COLOR]
		var cb: Color = b[A_COLOR]
		r[A_COLOR] = ca.lerp(cb, t)
	if a[A_TANGENT] != null:
		var ta: PackedFloat32Array = a[A_TANGENT]
		var tb: PackedFloat32Array = b[A_TANGENT]
		var tt := PackedFloat32Array()
		tt.append(lerp(ta[0], tb[0], t))
		tt.append(lerp(ta[1], tb[1], t))
		tt.append(lerp(ta[2], tb[2], t))
		tt.append(lerp(ta[3], tb[3], t))
		r[A_TANGENT] = tt

	return r


func _emit(a: Array, b: Array, c: Array, out_verts: PackedVector3Array, out_normals: PackedVector3Array, out_uvs: PackedVector2Array, out_colors: PackedColorArray, out_tangents: PackedFloat32Array) -> void:
	var vtxs: Array = [a, b, c]
	for v in vtxs:
		var p: Vector3 = v[A_LOC]
		out_verts.append(p)
		if v[A_NORMAL] != null:
			var nn: Vector3 = v[A_NORMAL]
			out_normals.append(nn)
		if v[A_UV] != null:
			var uu: Vector2 = v[A_UV]
			out_uvs.append(uu)
		if v[A_COLOR] != null:
			var cc: Color = v[A_COLOR]
			out_colors.append(cc)
		if v[A_TANGENT] != null:
			var tt: PackedFloat32Array = v[A_TANGENT]
			out_tangents.append(tt[0])
			out_tangents.append(tt[1])
			out_tangents.append(tt[2])
			out_tangents.append(tt[3])