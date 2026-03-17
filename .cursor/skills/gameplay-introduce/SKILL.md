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
- 写法：纯同步，`bot.move` 阻塞直到抵达，不阻塞主循环

## Bot API（玩家可见）

| 属性/方法 | 说明 |
|------|------|
| `cardinal` | 当前朝向，Consts.Cardinal，默认 NORTH |
| `move_forward()` | 沿当前朝向移动一格，返回 true=抵达/false=被取消 |
| `turn_left()` | 左转 90°，返回 true=完成/false=被取消 |
| `turn_right()` | 右转 90°，返回 true=完成/false=被取消 |

后续会扩展：搬运子弹、拾取、建造等。

## 示例

```gdscript
extends RefCounted

func run(bot) -> void:
	bot.move_forward()
	bot.turn_right()
	bot.move_forward()
	bot.turn_right()
	bot.move_forward()
	bot.turn_right()
	bot.move_forward()
```

## 架构要点

- **Bot**：玩家可见封装，暴露 `cardinal`、`move_forward`、`turn_left`、`turn_right`；子线程调用时 call_deferred 交给 BotMain，完成后 semaphore 解除阻塞
- **BotMain**：主线程逻辑，通过 call_deferred 接收请求，委托 MoveForwardState/TurnState 执行
- 玩家脚本无法访问 BotMain，避免窥探内部实现
