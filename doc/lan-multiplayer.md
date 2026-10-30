# 局域网联机设计方案（含 CPU 玩家）

> 目标：给现有的 Godot 重制版加**局域网联机**，最多 **4 人**。
> **CPU 玩家是可选的**：既可以 4 个全是人类，也可以在空位放 CPU（2 人类 + 2 CPU 等）；
> CPU 默认不添加，由房主显式选择。
> 本文回答三个问题：要不要用第三方插件、怎么改、CPU 在联机里怎么处理。
>
> 引用路径相对 `box-head-remake/`；行号为当前工作副本。

---

## 0. 一句话结论

**不需要第三方插件**：Godot 4 自带的 `ENetMultiplayerPeer` + `@rpc` + `SceneMultiplayer` 就能做局域网。
**纯人类局和人类+CPU 混编走同一套逻辑**：CPU 只是"由主机控制的座位"，不参与时不产生任何额外开销。
推荐 **"主机权威（listen server）"**：主机跑全部逻辑（人类、CPU、敌人、波次、流场、随机数），客户端只发输入、收快照、做插值渲染。

**最小改动只有两处必须做**：

1. **把玩家输入抽象成"意图"**：目前 `Player.updateIdle()` 直接轮询 `Input`（[player.gd:702](file:///F:/boxHead-remake/box-head-remake/script/character/player.gd#L702)），要改成"从统一的 intent 结构取输入"；本地人类、远程人类、CPU 三种来源都往同一个结构里写。
2. **给所有玩法脚本加权威门**：客户端不跑敌人 AI/状态机/物理决策，只接收快照并插值；主机不信任客户端位置，只接受输入。

其余都是围绕这两点的外围（生成同步、事件广播、HUD、相机、暂停）。

---

## 1. 现状盘点（决定改动范围）

| 现状 | 位置 | 对联网的影响 |
|---|---|---|
| 玩家输入直接读 `Input` | `player.gd:702-763` | 远程玩家没有本地输入，必须改成 intent |
| CPU 用行为树写 intent | `player.gd` `cpuMoveDir/cpuAimDir/cpuWantFire` + `CpuBrain` | **正好可以复用**：CPU 和远程人类都走"intent" |
| 玩家按槽位生成 | `map.gd:150-168` | 槽位会变成"主机分配的人类/CPU" |
| 敌人 FSM + 流场 | `zombie.gd`/`devil.gd`、`MapData` | 只能主机跑 |
| 波次/难度/随机数 | `map.gd` | 只能主机跑 |
| 贴花/特效/音效 | `decal_layer.gd`、`fx/*` | 主机烘焙，客户端收事件 |
| 设置 | `settings.gd` | 玩法项主机权威，视觉项各端本地 |
| 项目里没有任何网络代码 | — | 全新模块，不影响现有逻辑 |

---

## 2. 架构选型

| 方案 | 说明 | 结论 |
|---|---|---|
| **主机权威（推荐）** | 主机模拟世界，客户端发输入、收快照 | LAN 延迟低，最容易做对，改动可控 |
| 确定性锁步 | 各端用相同输入跑相同模拟 | Godot 物理/浮点/`random()` 跨机不一致，要重写大量逻辑，**不采用** |
| 纯 P2P 状态同步 | 每个端只同步自己 | 敌人/CPU 仍需权威，复杂且易作弊 |

### 2.1 拓扑

```
主机（Host，同时是 1P）
 ├─ 模拟：人类玩家、CPU 玩家、僵尸/恶魔、油桶/墙、波次、流场、RNG
 ├─ 每 50~66ms 广播快照（位置/血量/状态/武器/敌人列表）
 └─ 事件：开火、爆炸、命中、贴花、拾取、波次、结算

客户端（Client，2P/3P/4P，每台机器 1 人）
 ├─ 每帧发输入（20~30Hz，只发"意图"）
 ├─ 不跑 AI/波次/流场/物理决策
 └─ 用快照插值渲染 + 本地表现（贴花、特效可本地重放）
```

### 2.2 延迟预算（LAN）

- 输入 → 主机：1~3ms；快照间隔 50ms；客户端插值缓冲 100ms。
- 本地玩家不做预测时，操作反馈约 **60~110ms**；LAN 下可接受，V1 不做预测，V3 再加。

---

## 3. 同步什么、不同步什么

| 类别 | 内容 | 处理 |
|---|---|---|
| **必须同步** | 玩家/CPU/敌人位置、朝向、血量、状态（Idle/Hurt/Dead）、武器与弹药、是否开火 | 快照 |
| **必须同步** | 波次、分数、连杀、难度、友伤等玩法设置、复活/结算 | 主机事件 |
| **可本地推导** | 动画帧（由状态+速度推导）、相机、HUD 布局 | 本地 |
| **纯表现** | 贴花、烟雾、枪口火焰、音效 | 主机发"事件"，客户端本地重放（或干脆由状态推导） |
| **不需要** | 流场、寻路、AI 决策、随机数 | 主机内部 |

---

## 4. 座位模型：全人类 / 人类+CPU 混编（CPU 可选）

现有的 `MapData.playerSlots` 是"角色"模型（0 关 / 1 = 1P / 2 = 2P / 3 = CPU），
1P/2P 唯一。它适合单机，但**联机时"1P/2P"只是本地键盘方案，不是玩家身份**，
所以联机层要换成**座位（seat）模型**，单机界面再映射到它。

### 4.1 座位定义（4 个）

```gdscript
# 座位 0..3；playerId = seat + 1（只用于颜色/HUD 编号）
{ controller: 0=OFF | 1=LOCAL_HUMAN | 2=REMOTE_HUMAN | 3=CPU,
  peer_id:   0(本地/CPU) 或 远程 peer 的 id,
  character: 0..3（角色/皮肤）}
```

| 场景 | 座位示例 |
|---|---|
| 单机 1 人 | `[LOCAL, OFF, OFF, OFF]` |
| 单机 1 人 + 2 CPU | `[LOCAL, CPU, CPU, OFF]` |
| 联机 4 人类 | 主机 1 个 `LOCAL` + 3 个 `REMOTE` |
| 联机 3 人类 + 1 CPU | 3 个 `LOCAL/REMOTE` + 1 个 `CPU` |
| 联机 2 人类 + 2 CPU | 2 个人类 + 2 个 `CPU` |

- **`playerId` 不再决定按键**：按键只跟"本机本地座位"有关（本机第 1 个本地人类用 `p1_*`，
  第 2 个才用 `p2_*`，用于将来的同机双人）；远程/CPU 玩家的 `keyMap` 直接不用。
- 单机界面里的"1P/2P/CPU"下拉 → 映射成座位（1P/2P = 本地人类，CPU = CPU）；
  联机时由主机按 roster 生成座位，客户端只接收结果。
- 上限始终是 **4 个座位**；"4 人类"就是 4 个座位全给人类（**不含任何 CPU**），
  "混编"只是在房主愿意时把空位填成 CPU。
- **CPU 默认关闭**：不勾选"CPU 补满空位"、也没有座位被手动设成 CPU 时，整局就是纯人类，
  主机不需要创建任何 `CpuBrain`（和单机 1 人开局一致）。

### 4.2 CPU 只在主机上跑

客户端连 `CpuBrain` 都不挂：

1. **座位分配（主机权威）**：主机维护 4 个 seat；每个客户端连入时占一个 `REMOTE` 座位，
   主机自己占 `LOCAL`；剩余空位默认 `OFF`（纯人类局），只有房主显式开启"CPU 补满空位"
   或把某个座位设成 `CPU` 时才生成 CPU。
2. 主机按座位生成玩家（沿用 `map.gd` 的出生点逻辑）；人类的 intent 来自输入/RPC，
   CPU 的 intent 来自 `CpuBrain`；敌人、波次、流场、随机数全部只在主机跑。
3. CPU 的"网络身份"：和远程人类一样按 `netId`（座位号）同步；客户端把它当远程玩家渲染，
   **不重复跑 AI**（客户端上 `cpus` 不应有行为树）。
4. **断线接管（可选，P3）**：客户端掉线后，主机把该座位从 `REMOTE` 切成 `CPU`（挂 `CpuBrain`），
   游戏继续；重连再换回人类（或保持 CPU、由玩家选择）。
5. 客户端本地玩家死亡/复活：由主机判定并广播状态，客户端只播表现。

> 关键点：CPU 和远程人类共用同一套"intent"消费路径（见 §5），所以 CPU 联机几乎不用额外逻辑。

---

## 5. 最小改动设计

### 5.1 输入抽象（改动 1，必须）

在 `Player` 里引入统一的意图结构：

```gdscript
# 每帧由"输入源"写入
var intentMove: Vector2 = Vector2.ZERO     # 8 向，远程/CPU 直接写
var intentFire: bool = false               # 是否按住开火
var intentFirePressed: bool = false        # 本帧按下（单发武器）
var intentFireReleased: bool = false       # 本帧松开（手雷）
var intentNextWeapon: bool = false
var intentPrevWeapon: bool = false
```

`updateIdle()` 改为只消费 intent：

```gdscript
# 原：inputDir = Input.get_vector(...) / Input.is_action_pressed(...)
if isCpu:
    ...  # CpuBrain 已经写 cpuMoveDir/cpuAimDir/cpuWantFire
elif isLocalHuman:
    _fillIntentFromInput()     # 本地人类：把 Input 翻译成 intent
else:
    pass                       # 远程人类：intent 由网络 RPC 写入
var inputDir := intentMove
```

- **本地人类**：新增 `_fillIntentFromInput()`，内容就是现在 `updateIdle` 里的那几行 `Input.*`；
  按键映射按"本机本地座位"选（第 1 个本地人类 `p1_*`，第 2 个 `p2_*`），**不再按全局 playerId**。
- **CPU**：`CpuBrain` 继续写 `cpuMoveDir/cpuWantFire`，在 `updateIdle` 里映射到 intent（或直接保留现分支）。
- **远程人类**：主机收到 RPC 后写入 intent。

> 这是全项目**唯一必须动玩家脚本**的地方，改动约 40~60 行。

### 5.2 权威门（改动 2，必须）

在基类 / 各玩法脚本入口加判断：

```gdscript
func _physics_process(delta):
    if Network.isClient():      # 客户端不跑玩法模拟
        return                  # 只做插值与表现
    ...原有逻辑...
```

需要加门的位置：

| 文件 | 处理 |
|---|---|
| `zombie.gd` / `devil.gd` `_physics_process`、FSM 状态脚本 | 客户端直接 return（位置由快照写） |
| `shot/*`、`fx/explosion.gd`、`item/*` | 客户端不自行生成/不结算伤害；表现由事件驱动 |
| `map.gd` 波次/计时器/刷怪 | 只在主机跑 |
| `player.gd` | 主机跑模拟；客户端本地玩家 = 输入采集 + 表现，远程玩家 = 纯表现 |
| `decal_layer.gd` | 主机烘焙；客户端收 `decal` 事件本地画 |
| `MapData.computeFieldMulti` / `updateFlowField` | 只在主机跑 |

### 5.3 生成与销毁同步

建议**自建 `NetRegistry`（netId → 节点）**，而不是全靠 `MultiplayerSpawner`：

- 动态敌人很多（同屏 60），`MultiplayerSpawner` 的节点路径复制开销大、顺序难控；
- 自建只需一个 `spawn_entity(netId, kind, pos, extra)` RPC + 本地注册表，客户端按 kind 实例化对应场景并登记。

### 5.4 快照（主机 → 客户端）

- 频率 15~20Hz（LAN 足够），客户端用 100ms 缓冲做位置/朝向插值。
- 内容（示例）：

```
tick, wave, score
players[]: netId, x, y, angle, hp, state, weaponType, ammo, dead
enemies[]: netId, type, x, y, angle, hp, state
```

- 数量级：4 玩家 + 60 敌人 × ~16 字节 × 20Hz ≈ **22~28 KB/s**（4 人类时用上限），LAN 完全无压力。
- V1 用 `var_to_bytes`/`PackedByteArray`；不够再上按位量化。

### 5.5 事件（可靠通道）

| 事件 | 内容 | 说明 |
|---|---|---|
| `fire` | 玩家 netId、方向、武器类型 | 客户端播放枪口火焰/曳光/音效 |
| `explosion` | 位置、类型 | 客户端播特效 + 抖动（本地设置决定） |
| `decal` | 位置、kind(blood/scorch)、size | 客户端本地贴花层画 |
| `hit` | 目标 netId、方向 | 命中反馈 |
| `pickup` / `barrel` / `wall` | netId / 位置 | 物品状态 |
| `wave` / `score` / `gameover` | 数值 | HUD |
| `settings` | friendlyFire、difficulty、Devils、collision | 开局同步一次 |

### 5.6 大厅/关卡选择

最小版本（大厅窗口与房间流程见 §5.9）：

- 主菜单加"网络对战"按钮 → `AppShell.open_lobby()`；大厅窗口承载"房间列表 / 创建房间 / 加入房间"；建房时在 `map_select` 里选地图、难度，并为 4 个座位设置"人类 / CPU / 关闭"
  （单机沿用的 1P/2P 下拉映射成"本地人类"）；点 "创建房间"。主场景全程保留，不替换。
  - **默认是纯人类**：空位保持关闭，不生成 CPU；
  - 想要混编再勾"CPU 补满空位"，或单独把某几个座位设成 CPU。
- 客户端填 IP（可选 UDP 广播发现）点 "Join"；主机把它放到第一个空闲的人类座位。
- 座位满了（4 人类）→ 后来者进入观战/等待；有空位且开了"CPU 补满"时，空位由 CPU 顶上。
- 开局前广播一次 roster（座位表）与玩法设置；游戏中断线后座位变为 CPU（P3）。

### 5.7 相机 / HUD / 暂停

- 相机：`game_camera` 的目标改成"本机玩家"（`playerId` 与本地 peer 绑定），CPU/远程玩家不作为本地相机目标。
- HUD：血条/武器挂在角色上（现状如此），远程角色也显示；分数/波次走全局 HUD。
- 暂停：只有主机能暂停，客户端显示"等待主机"。

### 5.8 对局窗口与生命周期（独立进程模式，可选加固）

> 默认不启用：大厅房间流程走 §5.9（同进程多窗口）。本节适用于需要崩溃隔离、多显示器或双实例调试的场景。

**结论**：对局跑在**独立子进程 + 独立 OS 窗口**里；大厅窗口只负责建房/加入/名单，对局退出（自己退或主机关）只关子进程，大厅窗口及其状态不受影响。

```gdscript
# 大厅侧：MatchRunner.launch_process()
var exe := OS.get_executable_path()
var args := PackedStringArray(["--", "--match", "--host", "--port=%d" % port, "--map=%s" % map_id])
var pid := OS.create_process(exe, args)   # 编辑器里 exe 是编辑器本体，需再传 "--path", 项目目录
# 轮询 OS.is_process_running(pid) 更新"对局中/已结束"，退出后恢复大厅按钮

# 对局侧：match_main.gd
func _ready() -> void:
    get_tree().auto_accept_quit = false
    var a := OS.get_cmdline_user_args()   # 解析 --host / --join / --port / --map / --slots

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if multiplayer.multiplayer_peer:
            multiplayer.multiplayer_peer.close()   # ENet 会发断开通知，比等超时快
        get_tree().quit()
```

| 事件 | 对局子进程 | 大厅窗口 | 其他人 |
|---|---|---|---|
| 客户端关对局窗口 | 关闭 | 不受影响 | 主机 `peer_disconnected`，释放座位 |
| 主机关对局窗口 | 关闭（服务器随之销毁） | 不受影响 | `server_disconnected` → 提示后关窗回大厅 |
| 对局内点"退出到大厅" | 关闭 | 恢复按钮/刷新 | 同上一行 |
| 对局进程崩溃 | 只有它挂 | 不受影响 | 按主机/客户端断开处理 |

约束：

- **大厅进程不持有 ENet peer**：服务器只跑在主机的对局子进程里，否则关大厅就等于关服；大厅可以另外连中心服/房间列表服，互不干扰。
- 参数只走命令行（`OS.get_cmdline_user_args()`）或临时配置文件；两个进程不共享单例/内存。
- `user://` 存档与设置：大厅负责写，对局进程只读，避免两边同时改 `settings.cfg`；对局结果可选写 `user://last_match.json` 供大厅展示。
- 平台差异：Android/iOS/Web 不允许起子进程，用 `MatchRunner` 接口实现"内嵌模式"（同窗口切场景），对局代码不改。
- 代价：两套引擎 ≈ 内存翻倍（百 MB 级）、两套音频；对局期间可把大厅窗口最小化。

### 5.9 大厅/对局窗口与房间功能（默认：同进程多窗口）

**结论**：主菜单是常驻主窗口；点"网络对战"开**大厅窗口**；建房/加入后开**对局窗口**。三个窗口同进程、共用一个 ENet peer；房间列表、建房、加入都在大厅完成，对局窗口只负责战斗。与 §5.8 的差别只在进程边界，窗口与生命周期管理不变。

**窗口分工**：

| 窗口 | 内容 | 创建时机 | 关闭语义 |
|---|---|---|---|
| **W0 主菜单**（主窗口） | 单机 / 网络对战 / 设置 / 退出 | 启动即存在，**从不销毁** | 退出应用；W1/W2 开着时先确认并走离开/结束流程 |
| **W1 大厅** | 房间列表、建房、加入、roster/ready/聊天 | 点"网络对战" | 离开房间（销毁 peer）→ 回主菜单 |
| **W2 对局** | 地图、HUD、结算 | 主机广播 `start_match` | 玩家退出/对局结束 → 回大厅房间面板，**peer 保留** |

窗口由新增的 `autoload/app_shell.gd` 统一管理（窗口栈、单实例复用、`close_requested`、焦点、`process_mode`）；网络生命周期绑定 **W1**：建房/加入时创建 peer，离开大厅时关闭，W2 只复用。

```gdscript
# autoload/app_shell.gd（示意）：窗口复用不重建
var lobby_win: Window
var match_win: Window

func open_lobby() -> void:
    if lobby_win == null:
        lobby_win = _make_window("大厅", Vector2i(960, 600), preload("res://scene/ui/lobby.tscn"))
        lobby_win.close_requested.connect(close_lobby)
    lobby_win.show()
    lobby_win.grab_focus()

func open_match(map_id: String) -> void:
    if match_win == null:
        match_win = _make_window("对局", Vector2i(1280, 800), preload("res://scene/map.tscn"))
        match_win.close_requested.connect(close_match)
    match_win.get_child(0).start_match(map_id)   # 实际用 signal/方法传参
    match_win.show()
    match_win.grab_focus()

func _make_window(title: String, size: Vector2i, scene: PackedScene) -> Window:
    var w := Window.new()
    w.title = "Boxhead 2Play - " + title
    w.size = size
    get_tree().root.add_child(w)                 # Window 本身就是 Viewport
    w.add_child(scene.instantiate())
    return w
# 项目设置 display/window/subwindows/embed_subwindows = false，才是独立系统窗口
```

一个 SceneTree 只有**一个** `multiplayer` peer，所以：

- `autoload/network.gd` 持有唯一 ENet peer；大厅里"创建房间"= `create_server`，"加入房间"= `create_client`。
- 对局窗口**复用**这个 peer，不新建连接——房间和对局本来就是同一个会话。
- W1/W2 之间只是开/关/隐藏窗口，不断线，可以直接"再来一局"。

大厅功能拆解：

| 功能 | 实现 |
|---|---|
| 入口 | 主菜单加"网络对战"按钮 → `AppShell.open_lobby()`；主场景保持加载，不替换 |
| 房间列表 | 主机每秒向 `47801` UDP 广播 `{name, map, players, max, port, ver}`；客户端监听，列表按 3 秒 TTL 清理；零插件，约 60 行 |
| 创建房间 | 选地图/难度/座位（人类或 CPU，CPU 默认关）→ `host()` → 进入房间面板，显示 roster 与"开始" |
| 加入房间 | 点列表或手输 IP → `join()` → 拉取 roster / ready 状态 |
| 准备/开始 | 客户端 `ready`；主机开局广播 `start_match(map, slots, settings)`，各端 `open_match()` |
| 对局中 | 大厅窗口保持存活（可隐藏/最小化），房间状态不断 |
| 结束/再来一局 | 关 W2 → 回 W1 房间面板，peer 保留；主机可再次开局 |

生命周期（同进程多窗口）：

| 事件 | W2 对局 | W1 大厅 | W0 主菜单 / 其他人 |
|---|---|---|---|
| 客户端关 W2 | 释放 | 显示房间面板（"已离开 / 再来一局"） | 主机收 `match_leave`，释放座位（P3 可转 CPU） |
| 主机关 W2 | 释放并广播 `match_end` | 回房间面板 | 客户端收 `match_end` → 关 W2 回房间 |
| 对局正常结束 | 释放（结算后） | 房间面板 | 同上，reason=finished |
| 客户端关 W1 | 若有则一并关 | 离开房间、销毁 peer | 主机 `peer_disconnected`，释放座位 |
| 客户端关 W0 | 一起关 | 一起关 | 退出应用；对端按断线处理 |
| 主机关 W1/W0 | 一起关 | 关服 | 客户端 `server_disconnected` → 回房间列表/主菜单 |
| 对局崩溃 | 整个进程挂 | 一起挂 | 需要隔离用 §5.8 |

注意事项：

- **输入门控**：`Input.is_action_pressed` 是全局轮询，不看焦点窗口。对局侧按 `Window.has_focus()`（或 `focus_entered/exited`）门控，否则在大厅窗口按键角色也会动；鼠标点击只会发给被点的窗口。
- **焦点**：开/关窗口后调用 `grab_focus()`，否则全屏对局窗口关掉后，焦点可能还停在隐藏窗口上。
- **暂停**：`get_tree().paused` 是全局的；大厅/主菜单根节点设 `process_mode = ALWAYS`，对局暂停时它们仍可操作；W2 隐藏时顺手禁用对局场景的 `process_mode`，省 CPU。
- **关闭主窗口**：W0 是主窗口，关它等于退出应用；有 W1/W2 时先弹确认，主机要先广播/关服。
- **平台**：Android/iOS/Web 没有真正的多窗口（`Window` 会嵌进主窗口），用同窗口切场景兜底；桌面端不受影响。
- **与 §5.8 的取舍**：同进程改动小、房间连接直接复用；独立进程隔离性好但房间要二次连接、内存翻倍。默认选本节。

---

## 6. 网络模块接口（建议）

新增 `autoload/network.gd`：

```gdscript
extends Node

const PORT := 47800
const MAX_CLIENTS := 3

var peer_to_slot: Dictionary = {}   # peer_id -> slot index
var local_slot: int = 0

func host() -> void:
    var p := ENetMultiplayerPeer.new()
    p.create_server(PORT, MAX_CLIENTS)
    multiplayer.multiplayer_peer = p
    # 监听 peer_connected / peer_disconnected，分配槽位并广播 roster

func join(ip: String) -> void:
    var p := ENetMultiplayerPeer.new()
    p.create_client(ip, PORT)
    multiplayer.multiplayer_peer = p

func isHost() -> bool:
    return multiplayer.is_server()
```

RPC 草案：

```gdscript
# 客户端 → 主机（不可靠有序，20~30Hz）
@rpc("any_peer", "call_remote", "unreliable_ordered")
func c2s_intent(move_x: float, move_y: float, buttons: int) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()
    # 写入该 peer 对应玩家的 intent；buttons 位掩码：1=fire 2=firePressed 4=fireReleased 8=nextWeapon 16=prevWeapon

# 主机 → 客户端（不可靠有序，15~20Hz）
@rpc("authority", "call_remote", "unreliable_ordered")
func s2c_snapshot(bytes: PackedByteArray) -> void: ...
```

> 输入必须做**限幅/校验**（move 长度 ≤1、buttons 只认已知位），主机永远不接受客户端发来的坐标。

---

## 7. 第三方插件需要吗？

| 需求 | 是否需要插件 |
|---|---|
| 局域网主机/客户端 | **不需要**，`ENetMultiplayerPeer` 内置 |
| RPC / 状态同步 | **不需要**，`@rpc`、`SceneMultiplayer` 内置 |
| 局域网房间发现（自动搜主机） | 不自带，需自己写 **UDP 广播**（约 50 行）或手动输 IP；不需要插件 |
| 公网 NAT 穿透 / 中继 | 需要额外服务（非 LAN 范畴） |
| 确定性回滚联机 | 可用社区 rollback 插件，但本项目**不采用**（见 §2） |
| Steam 联机 | 需要 Steam Multiplayer Peer（非 LAN 需求） |

结论：**LAN + CPU 这套用引擎自带就够，零插件**。

---

## 8. 分阶段落地

| 阶段 | 内容 | 验收 |
|---|---|---|
| **P0** | NetworkManager、主机/加入、座位模型、输入 intent 抽象、**2 人**移动/开火/相机 | 两台机器能看到对方移动/开火，位置不漂 |
| **P1** | 敌人/波次/物品/爆炸/贴花/音效同步；血量/死亡/复活/结算 | 两人共同清一波，双方敌人数量/血量/分数一致 |
| **P2** | 扩到 **4 人**：roster/座位分配、加入/离开、观战等待 | **4 台机器 4 人类（无 CPU）**可同局；中途加入不炸局 |
| **P2b** | **CPU 可选**：房主按需填 CPU，CPU 只在主机跑 | 开启时 3 人类 + 1 CPU / 2 人类 + 2 CPU 正常；关闭时纯人类不受影响 |
| **P3** | 断线接管（座位转 CPU）、插值优化、本地预测、重连、局域网发现 | 掉线游戏继续；重连恢复 |
| **P4** | 主菜单"网络对战"入口 + `AppShell` 窗口栈（大厅/对局）、房间列表/建房/加入、设置同步、延迟显示、异常处理（独立进程为可选加固） | 完整可玩的联机流程 |

---

## 9. 风险与注意事项

1. **不要做确定性锁步**：Godot 物理与 `random()` 跨机不一致；主机权威最稳。
2. **客户端不要跑 AI/波次**：否则会出现"两份敌人"、双倍伤害。
3. **输入只传意图**：绝不接受客户端上报坐标，防作弊也防漂移。
4. **快照插值**：客户端位置用缓冲插值，否则 15Hz 会明显卡顿。
5. **贴花/特效重复**：主机烘焙 + 客户端本地重放，注意别在客户端再跑一次 AI 触发的贴花。
6. **暂停语义**：只有主机能停世界。
7. **设置分两类**：玩法（友伤/难度/Devils/碰撞/速度）主机同步；视觉（血迹/抖动/语言/音量）各端本地。
8. **防火墙/端口**：ENet 走 UDP 47800，Windows 首次会弹授权；两台机器需在同一网段。
9. **主机退出**：V1 直接结束对局；主机迁移留到后续。
10. **Godot 版本**：项目 4.7.2，`SceneMultiplayer`/`@rpc` 语义稳定；`MultiplayerSynchronizer` 可用但敌人多时自建快照更可控。
11. **同机双人（分屏）不在 V1**：4 人类指"4 台机器各 1 人"；同机 2 人需要分屏/双相机，属于后续扩展（座位模型已经预留 `LOCAL` 多个座位的可能）。
12. **peer 归 NetworkManager 所有**：同进程多窗口下大厅与对局共用一个 peer（大厅建房/加入，对局复用），不要在对局里再建一个；只有采用 §5.8 独立进程加固时，peer 才跟随对局子进程。关窗时主动 `close()` 或广播 `match_end`，别让对端等 ENet 超时。
13. **多窗口输入**：`Input` 轮询是全局的，必须按窗口焦点门控，否则大厅窗口的按键会驱动对局角色。

---

## 10. 测试建议（沿用 TestBridge）

- 同一台机器开两个 headless 实例（不同端口/不同 `--test-bridge` 端口）做 loopback 测试；
- 给 TestBridge 增加 `net_host` / `net_join` / `net_stats`（RTT、快照序号、丢包）命令；
- 断言：
  - 双方 `players` / `enemies` 数量、血量、分数在 1 秒内一致；
  - 客户端移动 100 次，主机看到的位置误差 < 1 格；
  - **4 人类（无 CPU）**：4 个座位分别连 4 个实例，每端相机跟自己的角色，互不串台；
    快照里不应出现 `cpus` 条目（或全为空），主机不创建 `CpuBrain`；
  - **混编（可选）**：3 人类 + 1 CPU、2 人类 + 2 CPU，CPU 只在主机有 `branch` 更新；
  - 座位满后再加入 → 进入观战/等待，不生成第 5 个玩家；
  - 掉线后（P3）主机能把座位切成 CPU，游戏继续。
  - **大厅多窗口**：主菜单 → 大厅 → 对局三级窗口，关对局窗口进程不退出、peer 保留、可再次开局；关大厅窗口回到主菜单并断线；关主菜单窗口退出应用；两个窗口只有焦点窗口的按键驱动角色（TestBridge 可用 `input` 命令 + 焦点切换验证）。

---

## 11. 改动量估计

| 模块 | 估计 |
|---|---|
| `autoload/network.gd` + 快照编解码 | ~250 行 |
| `player.gd` intent 抽象 | ~60 行 |
| 权威门（敌人/物品/特效/map） | ~80 行 |
| 生成/事件同步 + NetRegistry | ~200 行 |
| `AppShell` 窗口栈 + 大厅窗口（UDP 房间列表）/槽位/相机/暂停 | ~300 行 |
| 合计（P0~P2b，含 4 人/混编） | **~950~1050 行，零插件** |
