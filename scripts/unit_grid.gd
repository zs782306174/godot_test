@tool
class_name UnitGrid
extends Node3D

## 每格世界单位大小
@export var cell_size: float = 1.0:
	set(value):
		cell_size = maxf(0.1, value)
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
@export var grid_color: Color = Color(0.4, 0.7, 1.0, 0.6):
	set(value):
		grid_color = value
		update_gizmos()

## 每个格子的数据
class Cell:
	var flow_dir: Vector2i = Vector2i.ZERO  ## 流场方向（指向下一格）
	var unit                                ## 占用单位（null 表示空格）
	var wall_dir: int = 0                   ## 墙壁位掩码 N=1 E=2 S=4 W=8

# grid[x + z * grid_width]
var grid: Array[Cell] = []


func _ready() -> void:
	_init_grid()


func _init_grid() -> void:
	grid.resize(grid_width * grid_depth)
	for i in grid.size():
		grid[i] = Cell.new()


func _cell_index(grid_pos: Vector2i) -> int:
	return grid_pos.x + grid_pos.y * grid_width


# ── 坐标转换 ──────────────────────────────────────────────────────────────────

## 世界坐标 → 网格坐标
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var local := to_local(world_pos) - grid_offset
	return Vector2i(floori(local.x / cell_size), floori(local.z / cell_size))


## 网格坐标 → 世界坐标（格子中心）
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var local := grid_offset + Vector3(
		(grid_pos.x + 0.5) * cell_size,
		0.0,
		(grid_pos.y + 0.5) * cell_size
	)
	return to_global(local)


# ── 边界检查 ──────────────────────────────────────────────────────────────────

## 检查网格坐标是否在有效范围内
func is_valid_pos(grid_pos: Vector2i) -> bool:
	return (
		grid_pos.x >= 0 and grid_pos.x < grid_width
		and grid_pos.y >= 0 and grid_pos.y < grid_depth
	)


# ── 单位管理 ──────────────────────────────────────────────────────────────────

## 格子是否被占用
func is_occupied(grid_pos: Vector2i) -> bool:
	return is_valid_pos(grid_pos) and grid[_cell_index(grid_pos)].unit != null


## 获取格子上的单位，空格返回 null
func get_unit(grid_pos: Vector2i) -> Variant:
	if not is_valid_pos(grid_pos):
		return null
	return grid[_cell_index(grid_pos)].unit


## 放置单位到指定格子，越界或已占用返回 false
func place_unit(unit: Object, grid_pos: Vector2i) -> bool:
	if not is_valid_pos(grid_pos) or is_occupied(grid_pos):
		return false
	grid[_cell_index(grid_pos)].unit = unit
	return true


## 从指定格子移除单位，格子为空返回 false
func remove_unit(grid_pos: Vector2i) -> bool:
	if not is_occupied(grid_pos):
		return false
	grid[_cell_index(grid_pos)].unit = null
	return true


## 将单位从 from 移动到 to，失败返回 false
func move_unit(from: Vector2i, to: Vector2i) -> bool:
	if not is_occupied(from):
		return false
	if not is_valid_pos(to) or is_occupied(to):
		return false
	var fi := _cell_index(from)
	var ti := _cell_index(to)
	grid[ti].unit = grid[fi].unit
	grid[fi].unit = null
	return true


## 返回所有已占用的格子坐标
func get_occupied_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in grid.size():
		if grid[i].unit != null:
			@warning_ignore("integer_division")
			result.append(Vector2i(i % grid_width, i / grid_width))
	return result


## 清空所有单位（保留 flow_dir/wall_dir 数据）
func clear_units() -> void:
	for cell: Cell in grid:
		cell.unit = null


## 清空整个网格（含 flow_dir/wall_dir）
func clear() -> void:
	_init_grid()


# ── 流场 / 墙壁 ───────────────────────────────────────────────────────────────

## 设置格子流向
func set_flow_dir(grid_pos: Vector2i, dir: Vector2i) -> void:
	if is_valid_pos(grid_pos):
		grid[_cell_index(grid_pos)].flow_dir = dir


## 获取格子流向
func get_flow_dir(grid_pos: Vector2i) -> Vector2i:
	if not is_valid_pos(grid_pos):
		return Vector2i.ZERO
	return grid[_cell_index(grid_pos)].flow_dir


## 设置格子墙壁位掩码（N=1 E=2 S=4 W=8）
func set_wall_dir(grid_pos: Vector2i, mask: int) -> void:
	if is_valid_pos(grid_pos):
		grid[_cell_index(grid_pos)].wall_dir = mask


## 获取格子墙壁位掩码
func get_wall_dir(grid_pos: Vector2i) -> int:
	if not is_valid_pos(grid_pos):
		return 0
	return grid[_cell_index(grid_pos)].wall_dir
