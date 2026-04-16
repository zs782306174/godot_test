# Godot Gameplay 开发框架设计

## 概览

三个自动加载单例，放在 `res://framework/` 目录下：

| 模块 | 文件 | Autoload 名 |
|------|------|-------------|
| 资源预加载 | `framework/resource_preloader.gd` | `ResourcePreloader` |
| 节点对象池 | `framework/node_pool.gd` | `NodePool` |
| 事件总线 | `framework/event_bus.gd` | `EventBus` |

在 `project.godot` 的 `[autoload]` 段注册：
```ini
ResourcePreloader="*res://framework/resource_preloader.gd"
NodePool="*res://framework/node_pool.gd"
EventBus="*res://framework/event_bus.gd"
```

---

## 1. 资源预加载 `ResourcePreloader`

### 设计目标
- 异步后台加载，不卡主线程
- 支持分组批量加载（如 "level_1" 组）
- 缓存 + 引用计数，自动释放
- 进度查询，用于 Loading 界面

### 文件：`res://framework/resource_preloader.gd`

```gdscript
class_name ResourcePreloaderModule
extends Node

# --- 信号 ---
signal resource_loaded(path: String, resource: Resource)
signal group_loaded(group_name: String)
signal load_progress_changed(group_name: String, progress: float)

# --- 内部数据结构 ---
class _Entry:
    var resource: Resource = null
    var ref_count: int = 0
    var loading: bool = false

var _cache: Dictionary = {}           # path -> _Entry
var _groups: Dictionary = {}          # group_name -> Array[String] (paths)
var _pending: Dictionary = {}         # path -> Array[Callable] (回调队列)

# --- 公开 API ---

## 异步加载单个资源
func load_async(path: String, on_done: Callable = Callable()) -> void

## 同步加载（阻塞，适合小资源）
func load_sync(path: String) -> Resource

## 注册分组
func register_group(group_name: String, paths: Array[String]) -> void

## 异步加载整个分组
func load_group(group_name: String) -> void

## 从缓存获取（必须已加载）
func get_resource(path: String) -> Resource

## 释放引用（引用计数归零时从缓存移除）
func release(path: String) -> void

## 获取分组加载进度 0.0 ~ 1.0
func get_group_progress(group_name: String) -> float

# --- 内部 ---
func _process(_delta: float) -> void:
    # 每帧轮询 ResourceLoader.load_threaded_get_status()
    # 完成后填充 _cache，触发回调和信号
```

### 核心实现要点
1. **异步加载**：`ResourceLoader.load_threaded_request(path)` 发起，`_process` 中用 `load_threaded_get_status(path, progress)` 轮询
2. **引用计数**：`load_async` 时 `ref_count++`，`release` 时 `ref_count--`，归零则 `_cache.erase(path)`
3. **分组进度**：遍历组内所有 path 的 status，计算完成比例
4. **重复请求合并**：同一 path 已在加载中时，将回调追加到 `_pending[path]`，完成后统一触发

---

## 2. 节点对象池 `NodePool`

### 设计目标
- 泛型池，支持任意 PackedScene
- 超出池上限时自动扩容（可配置最大数量）
- 归还节点时隐藏 + 禁用，而非 `queue_free`
- 多场景类型各自维护独立池

### 文件：`res://framework/node_pool.gd`

```gdscript
class_name NodePoolModule
extends Node

# --- 内部数据结构 ---
class _Pool:
    var scene: PackedScene
    var inactive: Array[Node] = []   # 空闲节点
    var active: Array[Node] = []     # 使用中节点
    var max_size: int = 32

var _pools: Dictionary = {}          # scene_path -> _Pool
var _node_to_path: Dictionary = {}   # node -> scene_path（快速反查）

# --- 公开 API ---

## 预热：提前实例化 count 个节点放入池中
func prewarm(scene_path: String, count: int, max_size: int = 32) -> void

## 获取一个节点（自动激活）
func acquire(scene_path: String, parent: Node) -> Node

## 归还节点到池中（自动隐藏）
func release(node: Node) -> void

## 释放整个池（queue_free 所有节点）
func flush(scene_path: String) -> void

## 当前活跃节点数
func active_count(scene_path: String) -> int

# --- 内部 ---
func _activate(node: Node) -> void:
    node.visible = true
    node.process_mode = Node.PROCESS_MODE_INHERIT
    if node.has_method("on_acquired"):
        node.on_acquired()

func _deactivate(node: Node) -> void:
    node.visible = false
    node.process_mode = Node.PROCESS_MODE_DISABLED
    if node.has_method("on_released"):
        node.on_released()
```

### 核心实现要点
1. **acquire 流程**：`inactive` 非空则取出，否则实例化新节点（未超 `max_size`），`add_child` 到 `parent`，调用 `_activate`
2. **release 流程**：`_deactivate` → 从 `active` 移到 `inactive`，节点不离开场景树
3. **回调约定**：池节点可实现 `on_acquired()` / `on_released()` 方法，池自动调用（鸭子类型）
4. **与 ResourcePreloader 协作**：`prewarm` 内部可调用 `ResourcePreloader.load_sync(scene_path)` 获取 PackedScene

---

## 3. 事件总线 `EventBus`

### 设计目标
- 解耦节点间通信，替代直接 `get_node` 调用
- 支持带类型的事件载荷（Dictionary）
- 订阅者自动随节点销毁而清理
- 支持优先级排序、一次性订阅
- 支持通配符匹配（`"gameplay.*"` 匹配 `"gameplay.player_died"`）

### 文件：`res://framework/event_bus.gd`

```gdscript
class_name EventBusModule
extends Node

# --- 内部数据结构 ---
class _Subscriber:
    var callable: Callable
    var priority: int = 0
    var one_shot: bool = false
    var owner: Node = null     # 用于自动取消订阅

var _listeners: Dictionary = {}   # event_name -> Array[_Subscriber]（按 priority 降序）

# --- 公开 API ---

## 订阅事件
## owner 节点销毁时自动取消订阅（传 null 则手动管理）
func subscribe(
    event: String,
    callable: Callable,
    priority: int = 0,
    one_shot: bool = false,
    owner: Node = null
) -> void

## 取消订阅
func unsubscribe(event: String, callable: Callable) -> void

## 发布事件
func emit(event: String, payload: Dictionary = {}) -> void

## 清除某个事件的所有订阅
func clear(event: String) -> void

# --- 内部 ---
func _dispatch(event: String, payload: Dictionary) -> void:
    # 1. 精确匹配 _listeners[event]
    # 2. 通配符匹配：遍历 _listeners，检查 key 是否为 event 的前缀 + ".*"
    # 3. 按 priority 降序调用 callable.call(payload)
    # 4. 移除 one_shot 订阅者

func _on_owner_freed(event: String, callable: Callable) -> void:
    unsubscribe(event, callable)
```

### 核心实现要点
1. **自动清理**：`subscribe` 时若 `owner != null`，连接 `owner.tree_exited` → `_on_owner_freed`
2. **通配符**：`emit("gameplay.player_died")` 时，检查是否有 `"gameplay.*"` 的订阅者，一并触发
3. **优先级**：插入时用二分插入保持 `Array[_Subscriber]` 按 priority 降序排列
4. **一次性**：`_dispatch` 执行后将 `one_shot=true` 的订阅者从列表移除

---

## 模块协作示例

```gdscript
# 关卡加载流程
func load_level(level_id: String) -> void:
    # 1. 注册资源组
    ResourcePreloader.register_group("level_1", [
        "res://scenes/enemy.tscn",
        "res://scenes/bullet.tscn",
        "res://assets/tileset.tres",
    ])
    # 2. 订阅加载完成事件
    EventBus.subscribe("resource.group_loaded", _on_level_assets_ready, 0, true, self)
    # 3. 开始加载
    ResourcePreloader.load_group("level_1")

func _on_level_assets_ready(payload: Dictionary) -> void:
    if payload.get("group") != "level_1":
        return
    # 4. 预热对象池
    NodePool.prewarm("res://scenes/enemy.tscn", 10)
    NodePool.prewarm("res://scenes/bullet.tscn", 30)
    # 5. 通知 UI 加载完成
    EventBus.emit("level.ready", {"level_id": "level_1"})

# 游戏中生成敌人
func spawn_enemy(pos: Vector3) -> void:
    var enemy: Node = NodePool.acquire("res://scenes/enemy.tscn", $EnemyContainer)
    enemy.global_position = pos

# 敌人死亡归还池
func _on_enemy_died(enemy: Node) -> void:
    EventBus.emit("gameplay.enemy_died", {"position": enemy.global_position})
    NodePool.release(enemy)
```

---

## 文件清单

```
res://
└── framework/
    ├── resource_preloader.gd   # 资源预加载
    ├── node_pool.gd            # 节点对象池
    └── event_bus.gd            # 事件总线
```

## 注册 Autoload（project.godot）

```ini
[autoload]
SoundManager="*res://addons/sound_manager/module/SoundManager.tscn"
ResourcePreloader="*res://framework/resource_preloader.gd"
NodePool="*res://framework/node_pool.gd"
EventBus="*res://framework/event_bus.gd"
```

## 验证方法

1. 在测试场景挂载脚本，调用 `ResourcePreloader.load_async("res://icon.svg", func(r): print(r))`，确认回调触发
2. 调用 `NodePool.prewarm("res://node_2d.tscn", 3)`，再 `acquire` / `release`，确认节点复用（不重复实例化）
3. 在两个不相关节点间通过 `EventBus.emit` / `subscribe` 通信，确认解耦传递正常
4. 销毁订阅者节点后再 `emit` 同名事件，确认无报错（自动清理生效）
