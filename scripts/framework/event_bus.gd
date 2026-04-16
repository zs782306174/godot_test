class_name EventBusModule
extends Node

## 事件总线单例 (Autoload: EventBus)
## 提供中心化的事件发布/订阅机制，解耦节点间通信。
## 支持优先级排序、一次性订阅、通配符匹配、owner 自动清理。


class _Subscriber:
	var callable: Callable
	var priority: int = 0
	var one_shot: bool = false
	var owner_ref: WeakRef = null

	func _init(
		p_callable: Callable,
		p_priority: int,
		p_one_shot: bool,
		p_owner: Node
	) -> void:
		callable = p_callable
		priority = p_priority
		one_shot = p_one_shot
		if p_owner != null:
			owner_ref = weakref(p_owner)


var _listeners: Dictionary = {}  # event_name -> Array[_Subscriber]


# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

## 订阅事件。
## priority: 越高越先执行。
## one_shot: 触发一次后自动移除。
## owner: 传入节点后，节点离开场景树时自动取消订阅。
func subscribe(
	event: String,
	callable: Callable,
	priority: int = 0,
	one_shot: bool = false,
	owner: Node = null
) -> void:
	if not _listeners.has(event):
		_listeners[event] = []

	var sub := _Subscriber.new(callable, priority, one_shot, owner)

	if owner != null:
		var cleanup := func() -> void:
			unsubscribe(event, callable)
		owner.tree_exited.connect(cleanup, CONNECT_ONE_SHOT)

	# 按 priority 降序二分插入（相同 priority 时，后注册排后面）
	var arr: Array = _listeners[event]
	var lo := 0
	var hi := arr.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if arr[mid].priority >= priority:
			lo = mid + 1
		else:
			hi = mid
	arr.insert(lo, sub)


## 取消指定 callable 对某事件的订阅。
func unsubscribe(event: String, callable: Callable) -> void:
	if not _listeners.has(event):
		return
	var arr: Array = _listeners[event]
	for i in range(arr.size() - 1, -1, -1):
		if arr[i].callable == callable:
			arr.remove_at(i)
			return


## 发布事件，携带可选的载荷字典。
func emit(event: String, payload: Dictionary = {}) -> void:
	_dispatch(event, payload)


## 清除某事件的所有订阅者。
func clear(event: String) -> void:
	_listeners.erase(event)


# ---------------------------------------------------------------------------
# 内部实现
# ---------------------------------------------------------------------------

func _dispatch(event: String, payload: Dictionary) -> void:
	# 收集精确匹配 + 通配符匹配的所有监听键
	var matched: Array[String] = []
	if _listeners.has(event):
		matched.append(event)
	for key in _listeners.keys():
		if key == event:
			continue
		if key.ends_with(".*"):
			var prefix: String = key.left(key.length() - 2)
			if event.begins_with(prefix + "."):
				matched.append(key)

	for key in matched:
		if not _listeners.has(key):
			continue
		var arr: Array = _listeners[key]
		var i := 0
		while i < arr.size():
			var sub: _Subscriber = arr[i]
			# 安全检查：owner 已被释放则惰性清理
			if sub.owner_ref != null and sub.owner_ref.get_ref() == null:
				arr.remove_at(i)
				continue
			if sub.callable.is_valid():
				sub.callable.call(payload)
			if sub.one_shot:
				arr.remove_at(i)
			else:
				i += 1
