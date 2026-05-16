@tool
extends EditorNode3DGizmoPlugin

var _fill_material: StandardMaterial3D


func _get_gizmo_name() -> String:
	return "UnitGrid"


func _has_gizmo(node: Node3D) -> bool:
	return node is UnitGrid


func _init() -> void:
	create_material("grid", Color.WHITE, false, false, false)
	_fill_material = StandardMaterial3D.new()
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_material.vertex_color_use_as_albedo = true


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node := gizmo.get_node_3d() as UnitGrid
	if not is_instance_valid(node) or not node.show_grid:
		return

	var cs := node.cell_size
	var w := node.grid_width
	var d := node.grid_depth
	var offset := node.grid_offset

	# 网格线
	var lines := PackedVector3Array()
	lines.resize((w + 1 + d + 1) * 2)
	var idx := 0

	for i in range(w + 1):
		var x := i * cs
		lines[idx] = offset + Vector3(x, 0.0, 0.0); idx += 1
		lines[idx] = offset + Vector3(x, 0.0, d * cs); idx += 1

	for i in range(d + 1):
		var z := i * cs
		lines[idx] = offset + Vector3(0.0, 0.0, z); idx += 1
		lines[idx] = offset + Vector3(w * cs, 0.0, z); idx += 1

	gizmo.add_lines(lines, get_material("grid", gizmo), false, node.grid_color)

	# 按类型颜色填充格子
	var fill_verts := PackedVector3Array()
	var fill_colors := PackedColorArray()
	var colors := node.cell_type_colors
	if node.grid.size() != w * d or colors.is_empty():
		return

	for z in d:
		for x in w:
			var type_idx: int = node.grid[x + z * w].type
			if type_idx >= colors.size():
				continue
			var color := colors[type_idx]
			if color.a <= 0.0:
				continue
			var x0 := offset.x + x * cs
			var x1 := offset.x + (x + 1) * cs
			var z0 := offset.z + z * cs
			var z1 := offset.z + (z + 1) * cs
			for v: Vector3 in [
				Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z1), Vector3(x0, 0.0, z1),
			]:
				fill_verts.append(v)
				fill_colors.append(color)

	if fill_verts.is_empty():
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = fill_verts
	arrays[Mesh.ARRAY_COLOR] = fill_colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	gizmo.add_mesh(mesh, _fill_material)

