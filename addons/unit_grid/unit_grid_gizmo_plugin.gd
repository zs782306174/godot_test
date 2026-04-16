@tool
extends EditorNode3DGizmoPlugin


func _get_gizmo_name() -> String:
	return "UnitGrid"


func _has_gizmo(node: Node3D) -> bool:
	return node is UnitGrid


func _init() -> void:
	# 使用白色基础材质，绘制时通过 modulate 传入节点颜色
	create_material("grid", Color.GREEN, false, false, false)


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node := gizmo.get_node_3d() as UnitGrid
	if not is_instance_valid(node) or not node.show_grid:
		return

	var cell := node.cell_size
	var w := node.grid_width
	var d := node.grid_depth
	var offset := node.grid_offset

	var lines := PackedVector3Array()
	lines.resize((w + 1 + d + 1) * 2)
	var idx := 0

	# 平行于 Z 轴的线
	for i in range(w + 1):
		var x := i * cell
		lines[idx] = offset + Vector3(x, 0.0, 0.0); idx += 1
		lines[idx] = offset + Vector3(x, 0.0, d * cell); idx += 1

	# 平行于 X 轴的线
	for i in range(d + 1):
		var z := i * cell
		lines[idx] = offset + Vector3(0.0, 0.0, z); idx += 1
		lines[idx] = offset + Vector3(w * cell, 0.0, z); idx += 1

	gizmo.add_lines(lines, get_material("grid", gizmo), false, node.grid_color)
