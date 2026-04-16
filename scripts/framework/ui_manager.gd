class_name UIManagerModule
extends CanvasLayer

## UI 管理器单例 (Autoload: UIManager)
## 层级栈管理、过渡动画。

signal panel_pushed(scene_path: String)
signal panel_popped(scene_path: String)
signal stack_emptied


enum Transition {
	NONE,
	FADE,
	SLIDE_LEFT,
	SLIDE_RIGHT,
	SLIDE_UP,
	SLIDE_DOWN,
	SCALE,
}


class _PanelEntry:
	var node: Control
	var scene_path: String
	var overlay: bool
	var pause_below: bool


var _root: Control
var _overlay: ColorRect
var _stack: Array = []       # Array[_PanelEntry]
var _transitioning: bool = false


# ---------------------------------------------------------------------------
# 生命周期
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 100
	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _stack.is_empty() and not _transitioning:
		get_viewport().set_input_as_handled()
		pop()


# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

## 打开面板并压栈。返回面板实例，过渡动画完成前即返回。
func push(
	scene_path: String,
	transition: Transition = Transition.FADE,
	duration: float = 0.2,
	overlay: bool = true,
	pause_below: bool = false,
	data: Dictionary = {}
) -> Control:
	if _transitioning:
		push_warning("UIManager: 过渡动画进行中，忽略 push")
		return null

	# 通知当前栈顶失焦
	if not _stack.is_empty():
		var current: _PanelEntry = _stack.back()
		if current.node.has_method("on_panel_unfocused"):
			current.node.on_panel_unfocused()

	# 获取面板节点（优先从 NodePool 获取）
	var panel: Control = _acquire_panel(scene_path)
	if panel == null:
		return null

	# 构建栈条目
	var entry := _PanelEntry.new()
	entry.node = panel
	entry.scene_path = scene_path
	entry.overlay = overlay
	entry.pause_below = pause_below
	_stack.append(entry)

	# 遮罩
	if overlay:
		_overlay.visible = true
		_root.move_child(_overlay, _root.get_child_count() - 1)
	_root.add_child(panel)

	# 暂停下层
	if pause_below:
		_set_below_process(false)

	# 过渡动画
	_transitioning = true
	var tween := _tween_in(panel, transition, duration)
	if tween != null:
		await tween.finished
	_transitioning = false

	# 钩子 & 信号
	if panel.has_method("on_panel_opened"):
		panel.on_panel_opened(data)
	panel_pushed.emit(scene_path)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").emit("ui.panel_pushed", {"scene_path": scene_path})

	return panel


## 关闭栈顶面板。
func pop(
	transition: Transition = Transition.FADE,
	duration: float = 0.2
) -> void:
	if _stack.is_empty() or _transitioning:
		return

	var entry: _PanelEntry = _stack.pop_back()
	var panel: Control = entry.node

	# 钩子
	if panel.has_method("on_panel_closed"):
		panel.on_panel_closed()

	# 过渡动画
	_transitioning = true
	var tween := _tween_out(panel, transition, duration)
	if tween != null:
		await tween.finished
	_transitioning = false

	# 归还面板
	_release_panel(panel, entry.scene_path)

	# 更新遮罩 & 下层处理
	_update_overlay()
	if entry.pause_below:
		_set_below_process(true)

	# 通知新栈顶获焦
	if not _stack.is_empty():
		var new_top: _PanelEntry = _stack.back()
		if new_top.node.has_method("on_panel_focused"):
			new_top.node.on_panel_focused()

	# 信号
	panel_popped.emit(entry.scene_path)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").emit("ui.panel_popped", {"scene_path": entry.scene_path})
	if _stack.is_empty():
		stack_emptied.emit()
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").emit("ui.stack_emptied", {})


## 关闭到指定面板（保留该面板，其上全部关闭）。
func pop_to(
	scene_path: String,
	transition: Transition = Transition.FADE,
	duration: float = 0.2
) -> void:
	# 找到目标在栈中的位置
	var target_idx: int = -1
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i].scene_path == scene_path:
			target_idx = i
			break
	if target_idx < 0:
		push_warning("UIManager: 栈中未找到 '%s'" % scene_path)
		return

	# 从栈顶逐层关闭到 target_idx + 1
	var count: int = _stack.size() - target_idx - 1
	for i in count:
		if i == count - 1:
			await pop(transition, duration)
		else:
			await pop(Transition.NONE, 0.0)


## 清空所有面板。
func pop_all(
	transition: Transition = Transition.NONE,
	duration: float = 0.1
) -> void:
	var count: int = _stack.size()
	for i in count:
		if i == 0:
			await pop(transition, duration)
		else:
			await pop(Transition.NONE, 0.0)


## 替换栈顶面板。
func replace(
	scene_path: String,
	transition: Transition = Transition.FADE,
	duration: float = 0.2,
	overlay: bool = true,
	data: Dictionary = {}
) -> Control:
	if not _stack.is_empty():
		await pop(Transition.NONE, 0.0)
	return await push(scene_path, transition, duration, overlay, false, data)


## 当前栈顶面板。栈为空时返回 null。
func top() -> Control:
	if _stack.is_empty():
		return null
	return _stack.back().node


## 栈是否为空。
func is_empty() -> bool:
	return _stack.is_empty()


## 当前栈深度。
func depth() -> int:
	return _stack.size()


# ---------------------------------------------------------------------------
# 面板获取 & 归还
# ---------------------------------------------------------------------------

func _acquire_panel(scene_path: String) -> Control:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("UIManager: 无法加载面板场景 '%s'" % scene_path)
		return null
	var node: Node = scene.instantiate()
	var panel := node as Control
	if panel == null:
		push_error("UIManager: 面板根节点必须是 Control '%s'" % scene_path)
		node.queue_free()
		return null
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	return panel


func _release_panel(panel: Control, _scene_path: String) -> void:
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	panel.queue_free()


# ---------------------------------------------------------------------------
# 遮罩
# ---------------------------------------------------------------------------

func _update_overlay() -> void:
	var show_overlay: bool = false
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i].overlay:
			show_overlay = true
			break
	_overlay.visible = show_overlay
	if show_overlay:
		# 遮罩放在最顶面板的正下方
		var top_panel: Control = _stack.back().node
		var panel_idx: int = top_panel.get_index()
		_root.move_child(_overlay, max(0, panel_idx))


# ---------------------------------------------------------------------------
# 下层暂停
# ---------------------------------------------------------------------------

func _set_below_process(enabled: bool) -> void:
	for i in range(_stack.size() - 1):
		var entry: _PanelEntry = _stack[i]
		entry.node.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


# ---------------------------------------------------------------------------
# 过渡动画
# ---------------------------------------------------------------------------

func _tween_in(node: Control, transition: Transition, duration: float) -> Tween:
	if transition == Transition.NONE or duration <= 0.0:
		return null

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	match transition:
		Transition.FADE:
			node.modulate.a = 0.0
			tween.tween_property(node, "modulate:a", 1.0, duration)
		Transition.SLIDE_LEFT:
			node.position.x = vp_size.x
			tween.tween_property(node, "position:x", 0.0, duration)
		Transition.SLIDE_RIGHT:
			node.position.x = -vp_size.x
			tween.tween_property(node, "position:x", 0.0, duration)
		Transition.SLIDE_UP:
			node.position.y = vp_size.y
			tween.tween_property(node, "position:y", 0.0, duration)
		Transition.SLIDE_DOWN:
			node.position.y = -vp_size.y
			tween.tween_property(node, "position:y", 0.0, duration)
		Transition.SCALE:
			node.modulate.a = 0.0
			node.scale = Vector2(0.8, 0.8)
			node.pivot_offset = vp_size * 0.5
			tween.set_parallel(true)
			tween.tween_property(node, "modulate:a", 1.0, duration)
			tween.tween_property(node, "scale", Vector2.ONE, duration)

	return tween


func _tween_out(node: Control, transition: Transition, duration: float) -> Tween:
	if transition == Transition.NONE or duration <= 0.0:
		return null

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	match transition:
		Transition.FADE:
			tween.tween_property(node, "modulate:a", 0.0, duration)
		Transition.SLIDE_LEFT:
			tween.tween_property(node, "position:x", -vp_size.x, duration)
		Transition.SLIDE_RIGHT:
			tween.tween_property(node, "position:x", vp_size.x, duration)
		Transition.SLIDE_UP:
			tween.tween_property(node, "position:y", -vp_size.y, duration)
		Transition.SLIDE_DOWN:
			tween.tween_property(node, "position:y", vp_size.y, duration)
		Transition.SCALE:
			tween.set_parallel(true)
			tween.tween_property(node, "modulate:a", 0.0, duration)
			tween.tween_property(node, "scale", Vector2(0.8, 0.8), duration)

	return tween
