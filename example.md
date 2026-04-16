# Framework 使用示例

---

## ResourcePreloader — 资源预加载

### load_async — 异步加载单个资源

```gdscript
# 最简用法：不关心回调，只触发后台加载
ResourcePreloader.load_async("res://assets/tileset.tres")

# 带回调：资源就绪后执行逻辑
ResourcePreloader.load_async("res://scenes/enemy.tscn", func(res: Resource) -> void:
    print("加载完成：", res)
)

# 重复调用同一路径是安全的，不会重复发起请求
# 若资源已在缓存中，回调在当帧同步触发
ResourcePreloader.load_async("res://scenes/enemy.tscn", func(res: Resource) -> void:
    var scene := res as PackedScene
    var enemy := scene.instantiate()
    add_child(enemy)
)
```

### load_sync — 同步加载（阻塞）

```gdscript
# 适合 _ready 初始化阶段、加载小资源
var tileset := ResourcePreloader.load_sync("res://assets/tileset.tres") as TileSet
$TileMap.tile_set = tileset

# 若已被异步加载并缓存，直接命中缓存，不阻塞
var scene := ResourcePreloader.load_sync("res://scenes/bullet.tscn") as PackedScene
```

### register_group / load_group — 分组批量加载

```gdscript
func _ready() -> void:
    # 1. 注册分组（可在游戏启动时统一配置）
    ResourcePreloader.register_group("level_1", [
        "res://scenes/enemy.tscn",
        "res://scenes/bullet.tscn",
        "res://assets/tileset.tres",
    ])

    # 2. 监听信号
    ResourcePreloader.load_progress_changed.connect(_on_progress)
    ResourcePreloader.group_loaded.connect(_on_group_loaded)

    # 3. 开始加载
    ResourcePreloader.load_group("level_1")

func _on_progress(group_name: String, progress: float) -> void:
    if group_name == "level_1":
        $UI/ProgressBar.value = progress * 100      # 0 ~ 100

func _on_group_loaded(group_name: String) -> void:
    if group_name == "level_1":
        $UI/LoadingScreen.hide()
        start_game()
```

### get_group_progress — 轮询进度

```gdscript
# 不用信号，手动在 _process 里轮询
func _process(_delta: float) -> void:
    var p := ResourcePreloader.get_group_progress("level_1")
    $UI/ProgressBar.value = p * 100
    if p >= 1.0:
        set_process(false)
        start_game()
```

### get_resource — 从缓存取资源

```gdscript
# 必须确认已加载完毕再调用，否则返回 null 并打印警告
func _on_group_loaded(group_name: String) -> void:
    if group_name != "level_1":
        return
    var tileset := ResourcePreloader.get_resource("res://assets/tileset.tres") as TileSet
    $TileMap.tile_set = tileset
```

### release — 释放引用

```gdscript
# 离开关卡时释放不再需要的资源，引用计数归零后从缓存移除
func _on_level_exit() -> void:
    ResourcePreloader.release("res://scenes/enemy.tscn")
    ResourcePreloader.release("res://scenes/bullet.tscn")
    ResourcePreloader.release("res://assets/tileset.tres")
```

---

## NodePool — 节点对象池

### prewarm — 预热

```gdscript
# 关卡加载完成后提前实例化节点，避免游戏中途卡顿
# max_size 默认 32，prewarm 数量不会超过该上限
func _on_level_ready() -> void:
    NodePool.prewarm("res://scenes/enemy.tscn", 10)
    NodePool.prewarm("res://scenes/bullet.tscn", 30, 64)  # 最多允许 64 颗子弹同时存在
```

### acquire — 获取节点

```gdscript
# 从池中取出一个节点，挂载到指定父节点下，自动设为 visible=true
func spawn_enemy(spawn_pos: Vector3) -> void:
    var enemy := NodePool.acquire("res://scenes/enemy.tscn", $EnemyContainer)
    if enemy == null:
        return  # 池已满
    enemy.global_position = spawn_pos
    enemy.init(level_data)      # 业务初始化

# 子弹示例
func fire_bullet(from: Vector3, direction: Vector3) -> void:
    var bullet := NodePool.acquire("res://scenes/bullet.tscn", $BulletContainer)
    if bullet:
        bullet.global_position = from
        bullet.direction = direction
```

### release — 归还节点

```gdscript
# 节点不会被 queue_free，而是移回 NodePool 并隐藏，供下次复用
func _on_enemy_died(enemy: Node) -> void:
    EventBus.emit("gameplay.enemy_died", {"position": enemy.global_position})
    NodePool.release(enemy)

func _on_bullet_hit(bullet: Node) -> void:
    NodePool.release(bullet)
```

### 池节点的生命周期钩子

```gdscript
# 在池节点的脚本中实现这两个方法，NodePool 会自动调用
# 无需继承特定基类，鸭子类型即可

# enemy.gd
extends CharacterBody3D

func on_acquired() -> void:
    # acquire 后被调用：重置状态
    health = max_health
    velocity = Vector3.ZERO
    $AnimationPlayer.play("idle")

func on_released() -> void:
    # release 前被调用：停止所有行为
    $AnimationPlayer.stop()
    set_physics_process(false)
```

### flush — 销毁整个池

```gdscript
# 切换关卡时清空不再需要的池
func _on_level_exit() -> void:
    NodePool.flush("res://scenes/enemy.tscn")
    NodePool.flush("res://scenes/bullet.tscn")
```

### active_count — 查询活跃数量

```gdscript
# 调试 UI 显示当前子弹数量
func _process(_delta: float) -> void:
    $UI/DebugLabel.text = "Bullets: %d" % NodePool.active_count("res://scenes/bullet.tscn")
```

---

## EventBus — 事件总线

### subscribe / emit — 基础用法

```gdscript
# 订阅（不绑定 owner，需手动取消）
EventBus.subscribe("player.died", _on_player_died)

func _on_player_died(payload: Dictionary) -> void:
    var pos: Vector3 = payload.get("position", Vector3.ZERO)
    $VFX.spawn_death_effect(pos)

# 发布
func die() -> void:
    EventBus.emit("player.died", {"position": global_position, "score": current_score})
```

### owner 自动清理

```gdscript
# 传入 self 作为 owner：self 离开场景树时自动取消订阅，无需手动清理
func _ready() -> void:
    EventBus.subscribe("gameplay.enemy_died", _on_enemy_died, 0, false, self)
    EventBus.subscribe("ui.pause_requested",  _on_pause,      0, false, self)

func _on_enemy_died(payload: Dictionary) -> void:
    score += 10
```

### one_shot — 一次性订阅

```gdscript
# 只响应一次，触发后自动移除（常用于"等待某事件发生"）
func wait_for_level_ready() -> void:
    EventBus.subscribe("level.ready", func(p: Dictionary) -> void:
        start_cutscene(p.get("level_id", ""))
    , 0, true)  # one_shot = true
```

### priority — 优先级排序

```gdscript
# 数字越大越先执行
# 场景：UI 层要在游戏逻辑层之前响应 pause 事件

# 游戏逻辑（priority=0，默认）
EventBus.subscribe("game.paused", _pause_physics, 0, false, self)

# UI 层（priority=10，先执行）
EventBus.subscribe("game.paused", _show_pause_menu, 10, false, self)

# 发布时按 priority 降序：_show_pause_menu 先于 _pause_physics 调用
EventBus.emit("game.paused", {"timestamp": Time.get_ticks_msec()})
```

### 通配符订阅

```gdscript
# "gameplay.*" 匹配所有以 "gameplay." 开头的事件
# 适合日志、统计、成就系统等需要监听一类事件的场景
func _ready() -> void:
    EventBus.subscribe("gameplay.*", _on_any_gameplay_event, 0, false, self)

func _on_any_gameplay_event(payload: Dictionary) -> void:
    AnalyticsSDK.track(payload)

# 以下三个 emit 都会触发上面的订阅者
EventBus.emit("gameplay.enemy_died",   {"position": pos})
EventBus.emit("gameplay.item_picked",  {"item": "sword"})
EventBus.emit("gameplay.level_cleared",{"time": 120.5})
```

### unsubscribe — 手动取消订阅

```gdscript
func _ready() -> void:
    EventBus.subscribe("debug.toggle", _on_debug_toggle)

# 不再需要时手动移除（没有绑定 owner 时使用）
func _exit_tree() -> void:
    EventBus.unsubscribe("debug.toggle", _on_debug_toggle)
```

### clear — 清除事件的所有订阅者

```gdscript
# 场景切换时清理临时事件频道
func _on_scene_unloaded() -> void:
    EventBus.clear("level.enemy_spawned")
    EventBus.clear("level.checkpoint_reached")
```

---

## UIManager — UI 管理器

### preload_ui — 预加载 UI 场景

```gdscript
# 提前加载，打开时零等待（委托 ResourcePreloader 异步加载）
func _ready() -> void:
    UIManager.preload_ui("res://ui/settings_panel.tscn")
    UIManager.preload_ui("res://ui/inventory_panel.tscn")
```

### push — 打开面板（压栈）

```gdscript
# 最简用法：淡入打开，自动显示遮罩
func _on_settings_btn_pressed() -> void:
    UIManager.push("res://ui/settings_panel.tscn")

# 从左滑入，不显示遮罩
func _on_chat_btn_pressed() -> void:
    UIManager.push(
        "res://ui/chat_panel.tscn",
        UIManager.Transition.SLIDE_RIGHT,
        0.3,
        false   # overlay = false
    )

# 传递数据：通过 data 字典传参
func _on_item_clicked(item_id: String) -> void:
    UIManager.push(
        "res://ui/item_detail.tscn",
        UIManager.Transition.SCALE,
        0.25,
        true,
        false,
        {"item_id": item_id, "from": "inventory"}
    )

# 打开暂停菜单并冻结下层 UI
func _on_pause() -> void:
    UIManager.push(
        "res://ui/pause_menu.tscn",
        UIManager.Transition.FADE,
        0.15,
        true,
        true    # pause_below = true
    )
```

### pop — 关闭栈顶面板

```gdscript
# 默认淡出关闭（用户也可按 ESC 自动触发 pop）
func _on_close_btn_pressed() -> void:
    UIManager.pop()

# 指定动画和时长
func _on_swipe_right() -> void:
    UIManager.pop(UIManager.Transition.SLIDE_RIGHT, 0.3)
```

### pop_to — 关闭到指定面板

```gdscript
# 多层嵌套时直接回退到主菜单（中间面板全部关闭）
func _on_back_to_main() -> void:
    UIManager.pop_to("res://ui/main_menu.tscn")
```

### pop_all — 清空所有面板

```gdscript
# 游戏开始时清除所有 UI
func _on_game_start() -> void:
    UIManager.pop_all()
```

### replace — 替换栈顶面板

```gdscript
# 不增加栈深度，直接用新面板替换当前面板
func _on_tab_switched(tab: String) -> void:
    UIManager.replace(
        "res://ui/%s_tab.tscn" % tab,
        UIManager.Transition.FADE,
        0.15
    )
```

### top / is_empty / depth — 查询栈状态

```gdscript
# 获取当前栈顶面板引用
var current_panel: Control = UIManager.top()
if current_panel != null:
    current_panel.refresh_data()

# 判断 UI 栈是否为空（可用于决定返回键行为）
if UIManager.is_empty():
    get_tree().quit()

# 当前栈深度
print("UI 栈深度：", UIManager.depth())
```

### 面板脚本钩子

```gdscript
# settings_panel.gd
extends Control

func on_panel_opened(data: Dictionary) -> void:
    # push 完成后调用，适合初始化数据
    var tab: String = data.get("tab", "general")
    show_tab(tab)

func on_panel_closed() -> void:
    # pop 动画前调用，适合保存数据
    save_settings()

func on_panel_focused() -> void:
    # 重新成为栈顶（上层被 pop 后）
    refresh_display()

func on_panel_unfocused() -> void:
    # 新面板压入，不再是栈顶
    pause_animations()
```

### 监听信号

```gdscript
func _ready() -> void:
    UIManager.panel_pushed.connect(func(path: String) -> void:
        print("面板打开：", path)
    )
    UIManager.panel_popped.connect(func(path: String) -> void:
        print("面板关闭：", path)
    )
    UIManager.stack_emptied.connect(func() -> void:
        print("UI 栈已清空")
    )

# 也可通过 EventBus 监听（自动发出 ui.panel_pushed / ui.panel_popped / ui.stack_emptied）
EventBus.subscribe("ui.*", func(payload: Dictionary) -> void:
    print("UI 事件：", payload)
, 0, false, self)
```

---

## 四模块协作：关卡完整加载流程

```gdscript
extends Node

const ENEMY_SCENE  := "res://scenes/enemy.tscn"
const BULLET_SCENE := "res://scenes/bullet.tscn"

func _ready() -> void:
    # 0. 预加载暂停菜单 UI（后台异步，不阻塞）
    UIManager.preload_ui("res://ui/pause_menu.tscn")

    # 1. 注册关卡资源分组
    ResourcePreloader.register_group("level_1", [ENEMY_SCENE, BULLET_SCENE])

    # 2. 监听加载进度更新 Loading 条
    ResourcePreloader.load_progress_changed.connect(func(g: String, p: float) -> void:
        if g == "level_1":
            $UI/ProgressBar.value = p * 100
    )

    # 3. 加载完成后预热对象池并启动游戏
    EventBus.subscribe("resource.group_ready", _on_assets_ready, 0, true, self)
    ResourcePreloader.group_loaded.connect(func(g: String) -> void:
        if g == "level_1":
            EventBus.emit("resource.group_ready", {"group": g})
    )

    # 4. 开始异步加载
    ResourcePreloader.load_group("level_1")


func _on_assets_ready(_payload: Dictionary) -> void:
    # 预热对象池
    NodePool.prewarm(ENEMY_SCENE,  10)
    NodePool.prewarm(BULLET_SCENE, 30, 64)

    $UI/LoadingScreen.hide()
    EventBus.emit("level.started", {"level_id": "level_1"})


func spawn_enemy(pos: Vector3) -> void:
    var enemy := NodePool.acquire(ENEMY_SCENE, $EnemyContainer)
    if enemy:
        enemy.global_position = pos


func _on_enemy_died(enemy: Node) -> void:
    EventBus.emit("gameplay.enemy_died", {"position": enemy.global_position})
    NodePool.release(enemy)


func _on_level_exit() -> void:
    UIManager.pop_all()
    NodePool.flush(ENEMY_SCENE)
    NodePool.flush(BULLET_SCENE)
    ResourcePreloader.release(ENEMY_SCENE)
    ResourcePreloader.release(BULLET_SCENE)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and UIManager.is_empty():
        UIManager.push("res://ui/pause_menu.tscn", UIManager.Transition.FADE, 0.15, true, true)
```
