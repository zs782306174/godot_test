class_name ResManagerModule
extends Node

## 资源预加载单例 (Autoload: ResourcePreloader)
## 支持异步后台加载、分组批量加载、引用计数缓存。

signal resource_loaded(path: String, resource: Resource)
signal group_loaded(group_name: String)
signal load_progress_changed(group_name: String, progress: float)


class _Entry:
	var resource: Resource = null
	var ref_count: int = 0
	var loading: bool = false


var _cache: Dictionary = {}           # path -> _Entry
var _groups: Dictionary = {}          # group_name -> Array
var _pending: Dictionary = {}         # path -> Array[Callable]
var _group_remaining: Dictionary = {} # group_name -> int


# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

## 异步加载单个资源。on_done(resource: Resource) 加载完成后回调。
func load_async(path: String, on_done: Callable = Callable()) -> void:
	if _cache.has(path):
		var entry: _Entry = _cache[path]
		entry.ref_count += 1
		if not entry.loading:
			if on_done.is_valid():
				on_done.call(entry.resource)
		else:
			if on_done.is_valid():
				_pending[path].append(on_done)
		return

	var entry := _Entry.new()
	entry.loading = true
	entry.ref_count = 1
	_cache[path] = entry
	_pending[path] = []
	if on_done.is_valid():
		_pending[path].append(on_done)

	ResourceLoader.load_threaded_request(path)


## 同步加载（阻塞主线程，适合小资源或初始化阶段）。
func load_sync(path: String) -> Resource:
	if _cache.has(path):
		var entry: _Entry = _cache[path]
		if not entry.loading:
			entry.ref_count += 1
			return entry.resource

	var res: Resource = ResourceLoader.load(path)
	if res == null:
		push_error("ResourcePreloader: 加载失败 '%s'" % path)
		return null

	if _cache.has(path):
		# 可能同时有异步请求在排队
		var entry: _Entry = _cache[path]
		entry.resource = res
		entry.loading = false
		entry.ref_count += 1
		_flush_pending(path, res)
	else:
		var entry := _Entry.new()
		entry.resource = res
		entry.loading = false
		entry.ref_count = 1
		_cache[path] = entry
		resource_loaded.emit(path, res)

	return res


## 注册资源分组，供 load_group 批量加载。
func register_group(group_name: String, paths: Array) -> void:
	_groups[group_name] = paths.duplicate()


## 异步加载整个分组。全部完成后发出 group_loaded 信号。
func load_group(group_name: String) -> void:
	if not _groups.has(group_name):
		push_error("ResourcePreloader: 分组未注册 '%s'" % group_name)
		return

	var paths: Array = _groups[group_name]
	var remaining: int = 0
	for path in paths:
		if not (_cache.has(path) and not _cache[path].loading):
			remaining += 1

	if remaining == 0:
		load_progress_changed.emit(group_name, 1.0)
		group_loaded.emit(group_name)
		return

	_group_remaining[group_name] = remaining
	for path in paths:
		if _cache.has(path) and not _cache[path].loading:
			continue
		load_async(path, Callable(self, "_on_group_resource_loaded").bind(group_name))


## 从缓存获取已加载资源，未就绪时返回 null。
func get_resource(path: String) -> Resource:
	if _cache.has(path) and not _cache[path].loading:
		return _cache[path].resource
	push_warning("ResourcePreloader: 资源尚未就绪 '%s'" % path)
	return null


## 释放一个引用计数，归零时从缓存移除。
func release(path: String) -> void:
	if not _cache.has(path):
		return
	var entry: _Entry = _cache[path]
	entry.ref_count = max(0, entry.ref_count - 1)
	if entry.ref_count == 0:
		_cache.erase(path)


## 获取分组加载进度（0.0 ~ 1.0）。
func get_group_progress(group_name: String) -> float:
	if not _groups.has(group_name):
		return 0.0
	var paths: Array = _groups[group_name]
	if paths.is_empty():
		return 1.0
	var done: int = 0
	for path in paths:
		if _cache.has(path) and not _cache[path].loading:
			done += 1
	return float(done) / float(paths.size())


# ---------------------------------------------------------------------------
# 内部实现
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var progress_arr: Array = []
	for path in _cache.keys().duplicate():
		var entry: _Entry = _cache.get(path)
		if entry == null or not entry.loading:
			continue
		var status: ResourceLoader.ThreadLoadStatus = \
			ResourceLoader.load_threaded_get_status(path, progress_arr)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var res: Resource = ResourceLoader.load_threaded_get(path)
				entry.resource = res
				entry.loading = false
				_flush_pending(path, res)
				resource_loaded.emit(path, res)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("ResourcePreloader: 异步加载失败 '%s'" % path)
				entry.loading = false
				_pending.erase(path)
			_:
				pass


func _flush_pending(path: String, res: Resource) -> void:
	if not _pending.has(path):
		return
	for cb: Callable in _pending[path]:
		if cb.is_valid():
			cb.call(res)
	_pending.erase(path)


func _on_group_resource_loaded(_res: Resource, group_name: String) -> void:
	if not _group_remaining.has(group_name):
		return
	_group_remaining[group_name] -= 1
	var total: int = _groups[group_name].size()
	var done: int = total - _group_remaining[group_name]
	load_progress_changed.emit(group_name, float(done) / float(total))
	if _group_remaining[group_name] <= 0:
		_group_remaining.erase(group_name)
		group_loaded.emit(group_name)
