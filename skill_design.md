# 技能系统设计文档

## 概述

技能系统基于**有限状态机 (FSM)** 构建，采用**组合模式**将一个技能拆分为多个子技能 (SubSkill) 按序执行。系统支持输入检测、连招衔接、打断机制和冷却管理。

---

## 架构总览

```
┌─────────────────────────────────────────────┐
│                 数据层 (Resource)              │
│                                             │
│  SkillData                                  │
│  ├── id / name / desc                       │
│  ├── cooldown                               │
│  ├── wait_next_input_duration               │
│  ├── interrupt_flags                        │
│  └── sub_skills: Array[SubSkillData]        │
│       ├── OneShotSubSkillData               │
│       └── MultiTriggerSubSkillData          │
├─────────────────────────────────────────────┤
│                 逻辑层 (Runtime)              │
│                                             │
│  Skill (extends FSM)                        │
│  ├── sub_skills: Array[SubSkill]            │
│  ├── 5 个状态: Empty/Input/Execute/         │
│  │   Interrupt/Cooldown                     │
│  └── SkillInput                              │
│       └── 处理不同类型的输入采集              │
├─────────────────────────────────────────────┤
│                 框架层 (Framework)            │
│                                             │
│  FSM                                        │
│  └── FSM.State (enter / update / exit)      │
└─────────────────────────────────────────────┘
```

---

## 核心类

### FSM — 通用状态机框架

文件: `scripts/framework/fsm.gd`

提供状态的注册、切换与每帧更新。所有状态继承自内部类 `FSM.State`，需重写 `enter()`、`update(delta)` 和 `exit()` 生命周期方法。

| 方法 | 说明 |
|------|------|
| `add_state(state_name, state)` | 注册状态 |
| `remove_state(state_name)` | 移除状态 |
| `set_state(state_name)` | 切换状态，自动调用 exit/enter |
| `update(delta)` | 驱动当前状态的 update |
| `get_current_state_name()` | 获取当前状态标识 |

### Skill — 技能主体

文件: `scripts/battle/skill/skill.gd`

继承自 FSM，是整个技能的运行容器。构造时根据 `SkillData` 创建所有 `SubSkill` 实例并注册 5 个状态。

| 属性 | 类型 | 说明 |
|------|------|------|
| `skill_data` | SkillData | 技能配置数据 |
| `sub_skills` | Array[SubSkill] | 子技能实例列表 |
| `current_skill_index` | int | 当前执行到第几个子技能 |
| `skill_count` | int | 子技能总数 |
| `current_cooldown` | float | 剩余冷却时间 |
| `wait_count_down` | float | 连招等待输入的倒计时 |

### SubSkill — 子技能

文件: `scripts/battle/skill/sub_skill.gd`

技能的最小执行单元，由 `SubSkillData.skill_type` 指定的脚本实例化。基类提供以下接口：

| 方法 | 说明 |
|------|------|
| `start()` | 开始执行，重置 finished 标记 |
| `update(delta)` | 每帧更新（基类为空实现） |
| `interrupt()` | 被打断，立即标记为 finished |
| `is_finished()` | 返回是否执行完毕 |

每个 SubSkill 持有一个 `SkillInput` 实例用于输入采集。

### SkillInput — 输入处理器

文件: `scripts/battle/skill/skill_input.gd`

作为子技能的输入采集器，是一个独立基类（不继承 FSM）。基类提供默认实现：

| 方法 | 默认返回 | 说明 |
|------|---------|------|
| `is_active()` | false | 输入是否处于激活状态 |
| `is_complete()` | true | 输入是否采集完成 |

具体技能需继承此类实现不同的输入逻辑（如方向、目标点等）。

### SkillState — 技能状态基类

文件: `scripts/battle/skill/states/skill_state.gd`

继承自 `FSM.State`，提供 `skill` 属性以便各状态直接访问 Skill 实例。

---

## 状态机详解

### 状态枚举

```gdscript
enum StateName {
    EMPTY     = 0,  # 空闲 / 等待输入
    INPUT     = 1,  # 输入采集中
    EXECUTE   = 2,  # 执行子技能
    INTERRUPT = 3,  # 被打断
    COOLDOWN  = 4,  # 冷却中
}
```

### 状态转换图

```
                    ┌──────────────────────────────────┐
                    │          (任意状态可被打断)         │
                    ▼                                  │
              ┌──────────┐                             │
              │ INTERRUPT │──────────┐                  │
              └──────────┘          │                  │
                                    ▼                  │
┌───────┐  input.is_active  ┌───────┐  input.is_complete  ┌─────────┐
│ EMPTY │──────────────────▶│ INPUT │─────────────────────▶│ EXECUTE │
└───────┘                   └───────┘                      └─────────┘
    ▲           !is_active      │                              │
    │◀──────────────────────────┘                              │
    │                                                          │
    │  还有下一个子技能                                          │
    │◀─────────────────────────────────────────────────────────┘
    │                                                          │
    │                    所有子技能执行完毕                       │
    │              ┌──────────┐◀────────────────────────────────┘
    │              │ COOLDOWN │
    └──────────────┤          │  cooldown <= 0
                   └──────────┘
```

### 各状态行为

#### EmptyState（空闲）

- **enter**: 若 `current_skill_index > 0`（连招中），启动 `wait_count_down` 倒计时等待下一次输入；否则调用 `skill.reset()` 重置技能。
- **update**: 连招中时递减倒计时，超时则转入 COOLDOWN。检测当前子技能的 input，若 `is_active()` 则转入 INPUT。
- **exit**: 重置 `wait_count_down`。

#### InputState（输入采集）

- **update**: 若 input 不再活跃 (`!is_active()`) 则回退到 EMPTY；若输入完成 (`is_complete()`) 则转入 EXECUTE。

#### ExecuteState（执行）

- **enter**: 获取当前子技能并调用 `start()`。
- **update**: 调用子技能的 `update(delta)`。当子技能完成时，`current_skill_index + 1`。若所有子技能已执行完则转入 COOLDOWN，否则回到 EMPTY 等待下一个子技能的输入。
- **exit**: 清除 `current_sub_skill` 引用。

#### InterruptState（打断）

- **enter**: 调用当前子技能的 `interrupt()`，然后立即转入 COOLDOWN。
- **exit**: 重置 `current_skill_index` 为 0。

#### CooldownState（冷却）

- **enter**: 设置 `current_cooldown` 为 `skill_data.cooldown`。
- **update**: 递减冷却时间，归零后转入 EMPTY。
- **exit**: 重置 `current_skill_index` 和 `current_cooldown`。

---

## 数据层

### SkillData

文件: `scripts/base/skill_data.gd`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int | 技能唯一标识 |
| `name` | String | 技能名称 |
| `desc` | String | 技能描述 |
| `cooldown` | float | 冷却时间（秒） |
| `wait_next_input_duration` | float | 连招等待输入时长（秒） |
| `interrupt_flags` | int | 打断标记（位掩码） |
| `sub_skills` | Array[SubSkillData] | 子技能数据列表 |

### SubSkillData

文件: `scripts/base/sub_skill_data.gd`

| 字段 | 类型 | 说明 |
|------|------|------|
| `input_type` | SkillInputType | 输入类型枚举 |
| `prefab` | String | 预制体路径（视觉表现） |
| `view_delay` | float | 视觉延迟 |
| `logic_delay` | float | 逻辑延迟 |
| `skill_type` | Script | 子技能运行脚本 |

#### SkillInputType 枚举

```gdscript
enum SkillInputType {
    NoParam,      # 无需参数
    Dir,          # 需要方向
    StartPoint,   # 需要起始点
    StartAndDir,  # 需要起始点和方向
}
```

### OneShotSubSkillData

文件: `scripts/base/sub_skills/one_shot_sub_skill_data.gd`

继承 SubSkillData，用于单次触发型子技能。

| 字段 | 类型 | 说明 |
|------|------|------|
| `damage` | float | 伤害值 |

### MultiTriggerSubSkillData

文件: `scripts/base/sub_skills/multi_trigger_sub_skill_data.gd`

继承 SubSkillData，用于多段触发型子技能。

| 字段 | 类型 | 说明 |
|------|------|------|
| `trigger_count` | int | 触发次数 |
| `trigger_interval` | float | 触发间隔（秒） |

---

## 连招机制

技能通过 `sub_skills` 数组实现连招。执行流程：

1. 第一个子技能的 input 激活 → 进入 INPUT → 输入完成 → 进入 EXECUTE
2. 子技能执行完毕 → `current_skill_index` 递增 → 回到 EMPTY
3. 在 EMPTY 状态启动 `wait_next_input_duration` 倒计时
4. 倒计时内若下一个子技能的 input 激活 → 继续连招
5. 倒计时耗尽 → 进入 COOLDOWN → 连招中断

```
子技能1 Input → 子技能1 Execute → [等待输入] → 子技能2 Input → 子技能2 Execute → ... → Cooldown
                                      │
                                      └─ 超时 → Cooldown
```

---

## 战斗单位集成

文件: `scripts/battle/battle_unit_attributes.gd`

每个战斗单位通过属性系统可持有最多 4 个技能：

```gdscript
SKILL1_ID = 28,
SKILL2_ID = 29,
SKILL3_ID = 30,
SKILL4_ID = 31,
```

---

## 扩展指南

### 添加新的子技能类型

1. 在 `scripts/base/sub_skills/` 下创建新的数据类，继承 `SubSkillData`，添加该类型特有的导出属性。
2. 在 `scripts/battle/skill/` 下创建对应的运行时类，继承 `SubSkill`，重写 `start()` 和 `update(delta)` 实现具体逻辑。
3. 在 Godot 编辑器中创建 `.tres` 资源文件，设置 `skill_type` 指向新的运行时脚本。

### 添加新的输入类型

1. 在 `SubSkillData.SkillInputType` 枚举中添加新类型。
2. 创建新类继承 `SkillInput`，重写 `is_active()` 和 `is_complete()` 实现具体的输入判定逻辑。

### 文件结构

```
scripts/
├── framework/
│   └── fsm.gd                          # 通用状态机框架
├── base/
│   ├── skill_data.gd                    # 技能数据
│   ├── sub_skill_data.gd                # 子技能数据基类
│   └── sub_skills/
│       ├── one_shot_sub_skill_data.gd   # 单次触发数据
│       └── multi_trigger_sub_skill_data.gd # 多段触发数据
└── battle/
    ├── battle_unit_attributes.gd        # 战斗单位属性（含技能槽位）
    └── skill/
        ├── skill.gd                     # 技能主体（FSM）
        ├── sub_skill.gd                 # 子技能基类
        ├── skill_input.gd               # 输入处理器基类
        └── states/
            ├── skill_state.gd           # 技能状态基类
            ├── empty_state.gd           # 空闲状态
            ├── input_state.gd           # 输入状态
            ├── execute_state.gd         # 执行状态
            ├── interrupt_state.gd       # 打断状态
            └── cooldown_state.gd        # 冷却状态
```
