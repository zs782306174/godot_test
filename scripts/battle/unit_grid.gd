@tool

extends Node3D
class_name UnitGrid
enum CellType{
	EMPTY,
	WALL,

}
## 每格世界单位大小
@export var cell_size: float = 1.0:
	set(value):
		cell_size = maxf(0.1, value)
		_update_obstacle_edges()
		update_gizmos()

## X 方向格子数
@export var grid_width: int = 10:
	set(value):
		grid_width = maxi(1, value)
		_init_grid()
		update_gizmos()

## Z 方向格子数
@export var grid_depth: int = 10:
	set(value):
		grid_depth = maxi(1, value)
		_init_grid()
		update_gizmos()

## 编辑器内显示网格
@export var show_grid: bool = true:
	set(value):
		show_grid = value
		update_gizmos()

## 网格原点在本地空间的偏移量
@export var grid_offset: Vector3 = Vector3.ZERO:
	set(value):
		grid_offset = value
		update_gizmos()

## 网格线颜色
@export var grid_color: Color = Color(0.0, 1.0, 0.0, 1.0):
	set(value):
		grid_color = value
		update_gizmos()

## 各格子类型的填充颜色，索引与 CellType 枚举一致
@export var cell_type_colors: Array[Color] = [
	Color(0.0, 0.0, 0.0, 0.0),       # EMPTY  — 透明不绘制
	Color(1.0, 0.2, 0.2, 0.4),        # WALL   — 半透明红
]:
	set(value):
		cell_type_colors = value
		update_gizmos()

## 每个格子的数据
class Cell:
	var type: CellType = CellType.EMPTY
	var flow_dir: Vector2 = Vector2.ZERO
	var units: Dictionary[BattleUnit, bool] = {}
	## edges 存储格内线段端点对：[p0, p1, p2, p3, …]，每两个元素为一条线段
	var edges: Array[Vector2]

# grid[x + z * grid_width]
var grid: Array[Cell] = []


func _ready() -> void:
	_init_grid()
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	for child in get_children():
		if child is GridObstacle:
			(child as GridObstacle).vertices_changed.connect(_update_obstacle_edges)
	_update_obstacle_edges()


func _on_child_entered_tree(node: Node) -> void:
	if node is GridObstacle:
		(node as GridObstacle).vertices_changed.connect(_update_obstacle_edges)
		_update_obstacle_edges()


func _on_child_exiting_tree(node: Node) -> void:
	if node is GridObstacle:
		var obs := node as GridObstacle
		if obs.vertices_changed.is_connected(_update_obstacle_edges):
			obs.vertices_changed.disconnect(_update_obstacle_edges)
		_update_obstacle_edges()


func _init_grid() -> void:
	grid.resize(grid_width * grid_depth)
	for i in grid.size():
		grid[i] = Cell.new()


func _cell_index(x: int, y:int) -> int:
	return x + y * grid_width

## 世界坐标 → 网格坐标
func world_to_grid(world_pos: Vector3) -> Cell:
	var x = floori(world_pos.x / cell_size)
	var y = floori(world_pos.z / cell_size)
	if(is_valid_pos(x, y)):
		return null
	return grid[_cell_index(x, y)]

## 检查网格坐标是否在有效范围内
func is_valid_pos(x: int,y: int) -> bool:
	return (x >= 0 and x < grid_width and y >= 0 and y < grid_depth)

## 清空所有单位（保留 flow_dir/wall_dir 数据）
func clear_units() -> void:
	for cell: Cell in grid:
		cell.units.clear()


## 清空整个网格（含 flow_dir/wall_dir）
func clear() -> void:
	_init_grid()


# ── 障碍管理 ────────────────────────────────────────────────

## 根据子节点中的 GridObstacle 重新计算每个格子的 edges 和 type
func _update_obstacle_edges() -> void:
	if not is_node_ready():
		return
	for cell: Cell in grid:
		cell.edges.clear()
		cell.type = CellType.EMPTY

	var inv := global_transform.affine_inverse()
	var go := Vector2(grid_offset.x, grid_offset.z)

	for child in get_children():
		if not child is GridObstacle:
			continue
		var verts := _obstacle_to_local_2d(child as GridObstacle, inv)
		var count := verts.size()
		if count < 2:
			continue
		for i in count:
			_distribute_segment(verts[i], verts[(i + 1) % count])

	# 边界格（有截线段）标记为 WALL
	for cell: Cell in grid:
		if not cell.edges.is_empty():
			cell.type = CellType.WALL

	# 内部格（中心点在多边形内）标记为 WALL
	for child in get_children():
		if not child is GridObstacle:
			continue
		var verts := _obstacle_to_local_2d(child as GridObstacle, inv)
		if verts.size() < 3:
			continue
		for z in grid_depth:
			for x in grid_width:
				var cell := grid[_cell_index(x, z)]
				if cell.type == CellType.WALL:
					continue
				var center := Vector2((x + 0.5) * cell_size, (z + 0.5) * cell_size)
				if Geometry2D.is_point_in_polygon(center, verts):
					cell.type = CellType.WALL

	var wall_count := 0
	for cell: Cell in grid:
		if cell.type == CellType.WALL:
			wall_count += 1
	update_gizmos()

## 将障碍物顶点转换到格子索引空间（UnitGrid 本地 XZ，再减去 grid_offset）
func _obstacle_to_local_2d(obstacle: GridObstacle, inv: Transform3D) -> PackedVector2Array:
	var result: PackedVector2Array = []
	var go := Vector2(grid_offset.x, grid_offset.z)
	for v: Vector3 in obstacle.vertices:
		var local_v := inv * (obstacle.global_transform * v)
		result.append(Vector2(local_v.x, local_v.z) - go)
	return result

## 将线段 a→b（世界 XZ 坐标）按网格线切割，把每段的端点对写入对应格子的 edges
func _distribute_segment(a: Vector2, b: Vector2) -> void:
	var d := b - a

	# 收集线段被所有网格线切割的 t 参数值
	var ts: Array[float] = [0.0, 1.0]

	if absf(d.x) > 1e-6:
		var xi_lo := ceili(minf(a.x, b.x) / cell_size)
		var xi_hi := floori(maxf(a.x, b.x) / cell_size)
		for xi in range(xi_lo, xi_hi + 1):
			var t := (xi * cell_size - a.x) / d.x
			if t > 0.0 and t < 1.0:
				ts.append(t)

	if absf(d.y) > 1e-6:
		var zi_lo := ceili(minf(a.y, b.y) / cell_size)
		var zi_hi := floori(maxf(a.y, b.y) / cell_size)
		for zi in range(zi_lo, zi_hi + 1):
			var t := (zi * cell_size - a.y) / d.y
			if t > 0.0 and t < 1.0:
				ts.append(t)

	ts.sort()

	# 每段中点确定所在格子，存入端点对
	for i in range(ts.size() - 1):
		var mid := a + d * ((ts[i] + ts[i + 1]) * 0.5)
		var ix := floori(mid.x / cell_size)
		var iz := floori(mid.y / cell_size)
		if not is_valid_pos(ix, iz):
			continue
		var cell := grid[_cell_index(ix, iz)]
		cell.edges.append(a + d * ts[i])
		cell.edges.append(a + d * ts[i + 1])
