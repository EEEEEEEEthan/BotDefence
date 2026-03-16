---
name: gameplay-introduce
description: BotDefence 塔防游戏玩法介绍。玩家用 GDScript 控制机器人移动、搬运子弹等。在编写玩家脚本、设计 Bot API、或讨论游戏玩法时使用。
---

# BotDefence 玩法介绍

## 游戏类型

塔防游戏。玩家编写 GDScript 控制机器人（Bot）完成防守任务。

## 玩家脚本

- 入口：`player_code.gd`，实现 `run(bot) -> void`
- 运行：点 Play 后，玩家脚本在子线程执行，主线程继续跑 Godot 主循环
- 写法：纯同步，`bot.move_to` 阻塞直到抵达，不阻塞主循环

## Bot API（玩家可见）

| 方法 | 说明 |
|------|------|
| `move_to(target_x: float, target_y: float)` | 移动到目标点，阻塞直到抵达 |

后续会扩展：搬运子弹、拾取、建造等。

## 示例

```gdscript
extends RefCounted

func run(bot) -> void:
	bot.move_to(100, 200)
	bot.move_to(400, 300)
	bot.move_to(200, 100)
```

## 架构要点

- **Bot**：玩家可见封装，仅暴露 `move_to`；子线程调用时 call_deferred 交给 BotMain，抵达后 semaphore 解除阻塞
- **BotMain**：主线程移动逻辑，无 Mutex，通过 call_deferred 接收请求
- 玩家脚本无法访问 BotMain，避免窥探内部实现
