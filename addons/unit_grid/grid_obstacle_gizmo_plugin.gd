@tool
extends EditorNode3DGizmoPlugin

var undo_redo: EditorUndoRedoManager


func _get_gizmo_name() -> String:
	return "GridObstacle"


func _has_gizmo(node: Node3D) -> bool:
	return node is GridObstacle


func _init() -> void:
	create_material("obstacle", Color.RED, false, false, false)
	create_handle_material("handles")


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d() as GridObstacle
	if not is_instance_valid(node) or not node.show_polygon:
		return
	var verts := node.vertices
	var count := verts.size()
	if count < 2:
		return
	var lines := PackedVector3Array()
	lines.resize(count * 2)
	for i in count:
		lines[i * 2] = verts[i]
		lines[i * 2 + 1] = verts[(i + 1) % count]
	gizmo.add_lines(lines, get_material("obstacle", gizmo), false, node.debug_color)
	gizmo.add_handles(verts, get_material("handles", gizmo), [])


func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return "Vertex %d" % handle_id


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	return (gizmo.get_node_3d() as GridObstacle).vertices[handle_id]


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node := gizmo.get_node_3d() as GridObstacle
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	# 转换到节点本地空间后与 y=0 平面求交
	var inv := node.global_transform.affine_inverse()
	var local_origin := inv * ray_origin
	var local_dir := inv.basis * ray_dir
	if absf(local_dir.y) < 1e-4:
		return
	var t := -local_origin.y / local_dir.y
	var hit := local_origin + local_dir * t
	hit.y = 0.0
	var new_verts := node.vertices.duplicate()
	new_verts[handle_id] = hit
	node.vertices = new_verts


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d() as GridObstacle
	var after := node.vertices.duplicate()
	if cancel:
		after[handle_id] = restore as Vector3
		node.vertices = after
		return
	var before := after.duplicate()
	before[handle_id] = restore as Vector3
	undo_redo.create_action("Move GridObstacle Vertex")
	undo_redo.add_do_property(node, "vertices", after)
	undo_redo.add_undo_property(node, "vertices", before)
	undo_redo.commit_action()
