@tool
extends Node3D
class_name GridObstacle
## 多边形障碍，可在编辑器中拖动顶点，标记网格中的阻挡区域。
## 顶点定义在本地空间的 XZ 平面上（y 始终为 0）。

signal vertices_changed

## 多边形顶点（本地空间，XZ 平面）
@export var vertices: PackedVector3Array:
	set(value):
		vertices = value
		vertices_changed.emit()
		update_gizmos()

## 是否在编辑器中显示多边形轮廓
@export var show_polygon: bool = true:
	set(value):
		show_polygon = value
		update_gizmos()

## 编辑器调试颜色
@export var debug_color: Color = Color(1.0, 0.3, 0.3, 1.0):
	set(value):
		debug_color = value
		update_gizmos()


## 获取所有顶点的世界坐标（3D）
func get_world_vertices() -> PackedVector3Array:
	var result: PackedVector3Array = []
	for v: Vector3 in vertices:
		result.append(global_transform * v)
	return result


## 获取所有顶点的世界坐标并投影为 2D（XZ 平面，x→x，z→y）
func get_world_vertices_2d() -> PackedVector2Array:
	var result: PackedVector2Array = []
	for v: Vector3 in vertices:
		var w: Vector3 = global_transform * v
		result.append(Vector2(w.x, w.z))
	return result


## 检查 XZ 坐标点是否在多边形障碍内
func contains_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, get_world_vertices_2d())

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		vertices_changed.emit()
