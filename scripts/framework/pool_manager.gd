class_name PoolMnanagerModule
extends Node

## 节点对象池单例 (Autoload: NodePool)
## 按场景路径分类管理节点池，归还节点时隐藏并禁用，而非 queue_free。


class _Pool:
	var scene: PackedScene = null
	var inactive: Array = []  # Array[Node] 空闲节点
	var active: Array = []    # Array[Node] 使用中节点
	var max_size: int = 32


var _pools: Dictionary = {}        # scene_path -> _Pool
var _node_to_path: Dictionary = {} # instance_id -> scene_path


# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

## 预热：提前实例化 count 个节点放入空闲池。
func prewarm(scene_path: String, count: int, max_size: int = 32) -> void:
	var pool := _get_or_create_pool(scene_path, max_size)
	if pool == null:
		return
	var existing: int = pool.inactive.size() + pool.active.size()
	var to_create: int = mini(count, pool.max_size) - existing
	for i in to_create:
		var node: Node = pool.scene.instantiate()
		add_child(node)
		_node_to_path[node.get_instance_id()] = scene_path
		_deactivate(node)
		pool.inactive.append(node)


## 从池中获取一个节点，挂载到 parent 下并激活。池耗尽时返回 null。
func acquire(scene_path: String, parent: Node) -> Node:
	var pool := _get_or_create_pool(scene_path)
	if pool == null:
		return null

	var node: Node
	if pool.inactive.size() > 0:
		node = pool.inactive.pop_back() as Node
		pool.active.append(node)
		node.reparent(parent)
	else:
		var total: int = pool.inactive.size() + pool.active.size()
		if total >= pool.max_size:
			push_warning("NodePool: 池已满 '%s' (max: %d)" % [scene_path, pool.max_size])
			return null
		node = pool.scene.instantiate()
		parent.add_child(node)
		_node_to_path[node.get_instance_id()] = scene_path
		pool.active.append(node)

	_activate(node)
	return node


## 将节点归还到池中（移回 NodePool 节点下，隐藏并禁用）。
func release(node: Node) -> void:
	var id: int = node.get_instance_id()
	if not _node_to_path.has(id):
		push_warning("NodePool: 释放了未被池管理的节点，将执行 queue_free")
		node.queue_free()
		return

	var scene_path: String = _node_to_path[id]
	var pool: _Pool = _pools[scene_path]
	pool.active.erase(node)
	pool.inactive.append(node)
	node.reparent(self)
	_deactivate(node)


## 销毁某个场景路径对应的整个池（queue_free 所有节点）。
func flush(scene_path: String) -> void:
	if not _pools.has(scene_path):
		return
	var pool: _Pool = _pools[scene_path]
	for node in pool.inactive:
		_node_to_path.erase(node.get_instance_id())
		node.queue_free()
	for node in pool.active:
		_node_to_path.erase(node.get_instance_id())
		node.queue_free()
	pool.inactive.clear()
	pool.active.clear()
	_pools.erase(scene_path)


## 返回某池当前活跃节点数量。
func active_count(scene_path: String) -> int:
	if not _pools.has(scene_path):
		return 0
	return _pools[scene_path].active.size()


# ---------------------------------------------------------------------------
# 内部实现
# ---------------------------------------------------------------------------

func _get_or_create_pool(scene_path: String, max_size: int = 32) -> _Pool:
	if _pools.has(scene_path):
		return _pools[scene_path]

	var packed_scene: PackedScene
	# 优先通过 ResourcePreloader 加载，以复用缓存
	if has_node("/root/ResourcePreloader"):
		packed_scene = get_node("/root/ResourcePreloader").load_sync(scene_path) as PackedScene
	else:
		packed_scene = load(scene_path) as PackedScene

	if packed_scene == null:
		push_error("NodePool: 无法加载场景 '%s'" % scene_path)
		return null

	var pool := _Pool.new()
	pool.scene = packed_scene
	pool.max_size = max_size
	_pools[scene_path] = pool
	return pool


## 激活节点：显示、恢复处理、调用 on_acquired 钩子。
func _activate(node: Node) -> void:
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node.has_method("on_acquired"):
		node.on_acquired()


## 停用节点：隐藏、禁用处理、调用 on_released 钩子。
func _deactivate(node: Node) -> void:
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.has_method("on_released"):
		node.on_released()
