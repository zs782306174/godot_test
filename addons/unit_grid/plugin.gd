@tool
extends EditorPlugin

var _gizmo_plugin: EditorNode3DGizmoPlugin
var _obstacle_gizmo_plugin: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_gizmo_plugin = preload("res://addons/unit_grid/unit_grid_gizmo_plugin.gd").new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)
	_obstacle_gizmo_plugin = preload("res://addons/unit_grid/grid_obstacle_gizmo_plugin.gd").new()
	_obstacle_gizmo_plugin.undo_redo = get_undo_redo()
	add_node_3d_gizmo_plugin(_obstacle_gizmo_plugin)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmo_plugin)
	_gizmo_plugin = null
	remove_node_3d_gizmo_plugin(_obstacle_gizmo_plugin)
	_obstacle_gizmo_plugin = null
