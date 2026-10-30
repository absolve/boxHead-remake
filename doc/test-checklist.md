# AI 自动化测试清单（运行时验证）

> 目标：让 AI（或 CI）能**真实运行游戏**、读取运行时状态、注入操作，并按清单断言。
>
> 本文分三部分：
> 1. **工具选型**：用什么跑、用什么取运行时数据；
> 2. **测试清单**：项目中需要覆盖的功能、断言与优先级；
> 3. **驱动脚本生成规格**（§7）：把"怎么生成 `run_bridge_tests.py`"写成可复制的规格与提示词，
>    任何 AI 都能据此重新生成驱动，不依赖仓库里的某一份实现。
>
> 引用约定：路径相对 `box-head-remake/`；行号为当前工作副本。

---

## 1. 工具选型

### 1.1 结论：两层组合

| 层 | 工具 | 用途 |
|---|---|---|
| 断言层 | **[GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4)**（推荐）或 **[GUT](https://github.com/bitwes/Gut)** | 无头运行场景/脚本级测试，`assert_*` + 退出码，适合 CI |
| 黑盒驱动层 | **自建 `TestBridge` autoload**（JSON over TCP/WebSocket） | AI 真正的"眼睛和手"：读快照、注入输入、生成敌人、截图、暂停/单步 |
| 辅助 | Godot CLI（`--headless` / `--quit-after` / `--write-movie` / `--fixed-fps`） | 批处理、录像、固定步长复现 |

**为什么不用现成的 MCP 就够**：社区有 Godot MCP（如 [yanhuifair/Godot-MCP](https://github.com/yanhuifair/Godot-MCP)、"Open Godot MCP"），能编辑场景、跑游戏、模拟输入，但它们面向"编辑器自动化"、依赖第三方协议与许可证（部分 AGPL），且拿不到本项目内部的业务状态（策略、目标、弹药、贴花数）。**自建一个 100 行左右的 TestBridge 最确定、零依赖、可进 CI**。

### 1.2 方案对比

| 方案 | 能读业务状态 | 能注入输入 | 无头运行 | 依赖/风险 |
|---|---|---|---|---|
| **GdUnit4** | 能（直接访问节点/脚本） | 能（驱动 InputMap/调用方法） | 能 | 需安装插件；测试代码与实现强耦合 |
| GUT | 同上 | 同上 | 能 | 同上，社区更老牌 |
| **自建 TestBridge** | 能（自定义快照） | 能（Input.action_press / 直接调用） | 能 | 需要写代码；注意只在调试构建启用 |
| 社区 Godot MCP | 部分 | 能 | 视实现 | 第三方、AGPL、接口不稳定 |
| browser-use（本机已有） | 不能（只能看原生窗口像素） | 不能（原生窗口） | 否 | 只适合网页版，不适合本项目 |

> 建议：**GdUnit4 管"确定性的规则断言"，TestBridge 管"AI 探索式/长跑测试"**。两者可共用同一套场景与快照结构。

### 1.3 TestBridge 设计（建议实现，约 120 行）

启用方式（默认关闭，避免进正式包）：

```gdscript
# autoload/test_bridge.gd
func _ready() -> void:
    if not OS.get_cmdline_user_args().has("--test-bridge"):
        queue_free()
        return
    # TCPServer 监听 127.0.0.1:8765，按行收发 JSON
```

**命令（客户端 → 游戏）**

| cmd | 参数 | 说明 |
|---|---|---|
| `snapshot` | — | 返回 1.1 节的全部状态 |
| `input` | action, pressed | `Input.action_press/release`（p1_fire / p1_left …） |
| `spawn` | kind, pos, hp? | 生成僵尸 / 恶魔 / 箱子 / 油桶 |
| `clear_enemies` | — | 清空敌人 |
| `set_hp` | target, hp | 指定玩家/敌人血量 |
| `set_setting` | key, value | friendlyFire / screenShake / blood / difficulty |
| `pause` | bool | `get_tree().paused` |
| `step` | frames | 暂停下逐帧推进（固定步长复现） |
| `screenshot` | path | `get_viewport().get_texture().get_image().save_png()` |
| `select_strategy` | cpu, strategy | 强制 CPU 策略（测试用） |
| `quit` | code | 退出并带退出码 |

**快照字段（游戏 → 客户端）**

```
game:   mode, wave, paused, fps, process_ms, physics_ms,
        enemy_count, decal_count, node_count, orphan_count
players[]: id, isCpu, hp/maxHp, pos, state, invincible, weapon{type,ammo,maxAmmo,delay,range}
enemies[]: type(zombie/devil), hp, pos, state, target, dir, speed,
           reserved_cell, occupied_cell
enemy_metrics: min_pair_dist, overlap_pairs, max_enemies_per_cell,
               stuck_count, avg_speed, dir_flip_per_sec
cpu[]:  strategy, running_branch, target{id,dist}, want_fire,
        stuck_ms, last_switch_ms, rescue_state, box_target
items[]: type(barrel/wall/box/mine), pos, hp
settings: friendlyFire, screenShake, blood, difficulty, gameSpeed
```

> 安全：只监听 `127.0.0.1`、只在 `--test-bridge` 时加载、不要打进正式发行包。

### 1.4 运行方式

```bash
# 1) 无头跑场景 + 桥接（AI 驱动）
Godot_v4.7.2-stable_win64_console.exe --headless --path . \
    res://scene/test/test_cpu.tscn --quit-after 3600 -- --test-bridge

# 2) 需要截图/看渲染时：普通窗口 + 桥接
Godot_v4.7.2-stable_win64_console.exe --path . res://scene/map.tscn -- --test-bridge

# 3) 固定步长复现（录像/回归）
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . \
    res://scene/test/test_cpu.tscn --quit-after 1800

# 4) GdUnit4（装好后）
gdunit4 -a res://test --headless
```

注意：`--headless` 不渲染，**截图/FPS 无意义**；性能测试用窗口模式并保持焦点（失焦时 Godot 会限速，读数不可信）。

**已落地（2026-10-30）**

- `autoload/test_bridge.gd`：TCP JSON 桥，只在 `--test-bridge` 时启动；支持 snapshot / spawn / clear_enemies / set_hp / grant_weapons / teleport / set_setting / pause / input / screenshot / quit；调试日志加 `--test-bridge-verbose`。
- `doc/tools/run_bridge_tests.py`：自动选空闲端口、启动 Godot、跑断言、输出报告。
- 一键跑：

```bash
# 功能回归（test_cpu + test_flow_field）
python doc/tools/run_bridge_tests.py --scene both

# 长跑：map 场景、2 人类 + 2 CPU、全队无敌、引擎 3 倍速、每 5 秒采样
python doc/tools/run_bridge_tests.py --longrun --minutes 5 --time-scale 3
```

长跑模式做的事：

- 启动参数：`--time-scale <n>` 加速、`--slots=1,2,3,3` 指定槽位（桥在场景加载前写入 `MapData.playerSlots`）；
- 连接后自动 `god`（每秒刷新全队无敌，覆盖复活）；
- 每 5 秒采样：`wave / score / nodeCount / orphanCount / memMb / decalCount / 敌人指标`；
- 自动断言：响应正常、波次/分数有进展、节点数稳定、无孤儿节点、贴花 ≤400、无穿墙、卡死比例 ≤15%、
  重叠（>8 对）比例 ≤10%、内存增长受限、日志无 `SCRIPT ERROR`。

> 注意：`--time-scale` 会同时缩放物理 delta，但 AI 里用 `Time.get_ticks_msec()` 的冷却/驻留仍是真实时间，
> 所以加速后的 CPU 行为节奏会偏慢 —— 长跑用于**稳定性/泄漏**，不要用它评价 AI 手感。
> 穿墙统计会排除"出生/从场外走进来"的敌人（那时坐标本来就在地图外）。

### 首轮结果（2026-10-30）

`test_cpu` 14/14、`test_flow_field` 7/7，共 **21/21 通过**：

- CPU：生成/行为树、感知索敌、击杀、同点 8 只散开（`maxPerCell` 3→1、重叠 2→0）、低血求生分支并捡箱回血、暂停冻结、友伤开关。
- 敌人：50 只全部生成并收敛（50/50 进 300px）、`minPairDist` 31.2（无 <26 重叠）、无穿墙、无卡死、玩家瞬移后重新收敛（平均距离 141→117）。
- 发现并记录：低血求生阈值被改成"单人 40%"后，**回血（30 秒回满）会在 6 秒左右把血量顶过阈值**，箱子较远时求生可能提前结束；当前用例（96px 箱子）在时限内完成，暂未失败。建议后续给求生加"退出滞回"（例如 40% 进入、55% 退出）。

---

## 2. 测试清单

> 优先级：**P0** 核心玩法/回归必测；**P1** 重要体验；**P2** 边界与观感。
> 自动化：🤖 = 可用 TestBridge/GdUnit4 全自动断言；👁 = 需要人看一眼（或用截图对比）。

### A. 玩家 ↔ 敌人交互

| # | 用例 | 断言 / 观察 | 优先级 | 自动化 |
|---|---|---|---|---|
| A1 | 僵尸近战命中玩家 | 玩家掉 50 HP；进入 Hurt；有击退；血条同步 | P0 | 🤖 |
| A2 | 玩家出生无敌 | 出生 8s 内不掉血；Hurt 不触发 | P0 | 🤖 |
| A3 | 复活无敌 | 复活后 5s 内不掉血 | P0 | 🤖 |
| A4 | 玩家 30 秒回满血 | `hp` 随时间线性回升，无脱战要求 | P1 | 🤖 |
| A5 | 命中僵尸出血 | 命中后贴花数 +1；死亡时再叠若干张 | P1 | 🤖 |
| A6 | 僵尸死亡流程 | 掉血至 0 → Dying → Dead → 2 秒后消失；分数/连杀 +1 | P0 | 🤖 |
| A7 | 恶魔火球命中玩家 | 掉 50；火球消失；命中点有烟 | P0 | 🤖 |
| A8 | 火球打墙/油桶 | 墙/油桶碎裂（objectDamage 10000）；火球消失 | P1 | 🤖 |
| A9 | 僵尸寻路 | 玩家换位后，僵尸沿流场接近；不在墙里抖动 | P0 | 🤖 + 👁 |
| A10 | 僵尸互相挤压/分离 | 同格不重叠；不出现持续抖动的"互相推" | P1 | 👁 |
| A11 | 恶魔保持距离攻击 | 5 格内才丢火球；距离外靠近 | P1 | 🤖 |
| A12 | 玩家死亡/复活/全灭 | 单人死亡→复活点；多人全灭→5 秒后 GameOver | P0 | 🤖 |
| A13 | 友伤开关 | 关闭：玩家互射/爆炸都不掉血；开启：会掉血 | P0 | 🤖 |
| A14 | 爆炸伤害衰减 | 距离 ≤50% 半径 100%、≤75% 75%、≤100% 50% | P1 | 🤖 |

### B. CPU 玩家运行状态

| # | 用例 | 断言 / 观察 | 优先级 | 自动化 |
|---|---|---|---|---|
| B1 | 4 槽位生成 | 选了 CPU 的槽位生成 `isCpu=true` 的玩家，playerId 3/4/5，颜色不同 | P0 | 🤖 |
| B2 | 行为树启动 | `cpu[].running_branch` 有值；无 `BeehaveGlobalDebugger` 报错 | P0 | 🤖 |
| B3 | 感知 Area2D | 范围内敌人 → `target` 非空；重叠数 `ov` > 0 | P0 | 🤖 |
| B4 | 策略切换 | 无敌人→巡逻/跟随；有敌人→按性格进入战斗；血量 <25% → 放风筝 | P0 | 🤖 |
| B5 | 策略滞回 | 30 秒内策略切换 ≤ 3 次（强制切换除外） | P1 | 🤖 |
| B6 | 巡逻节奏 | 走 4~7 格 → 停 1.5~3.5s；不贴着墙抖动 | P1 | 🤖 |
| B7 | 占格/障碍识别 | 巡逻/走位不会进入障碍格、不会走进其他角色所在格 | P0 | 🤖 |
| B8 | 按武器交战距离 | 霰弹贴脸、UZI ~168、手枪 ~208、轨道炮 ~300、火箭 ~240（±20） | P1 | 🤖 |
| B9 | 站定开火 | 距离带内且射线通 → 位移≈0、持续开火；走动中不乱晃 | P1 | 🤖 |
| B10 | 挡枪停火 | 队友站在射线上 → 不开火；侧移后能恢复 | P0 | 🤖 |
| B11 | 换枪滞回 | 30 秒内换枪 ≤ 3 次；空弹才强制换；只换枪械 | P1 | 🤖 |
| B12 | 躲火球 | 火球朝自己飞来 → 分支变 `dodge` 并侧移 | P1 | 🤖 |
| B13 | 救援 | 队友 HP<35% 且 ≤12 格 → `rescue`；>12 格不去；8s 上限 + 5s 冷却 | P1 | 🤖 |
| B14 | 低血求生 | HP<25% → 优先奔向 14 格内箱子；无箱子则后退并开火 | P1 | 🤖 |
| B15 | 拆物判断 | 墙挡射线→打墙；油桶旁有敌人且爆区无自己人→打爆；队友在爆区→不打 | P1 | 🤖 |
| B16 | 受伤/死亡停摆 | Hurt 期间不下发移动/开火；死亡后复活流程正常 | P0 | 🤖 |
| B17 | 多 CPU 协同 | 3 CPU 同时存在，目标尽量分散；无相互卡死 | P1 | 👁 |
| B18 | CPU 接入 map（P4） | 关卡选择选 CPU 后，map 里正常生成并可战斗 | P0 | 🤖 |

### C. 武器

| # | 用例 | 断言 | 优先级 | 自动化 |
|---|---|---|---|---|
| C1 | 手枪 | 26 伤害 / 8 格 / 0.32s / 无限弹药 | P0 | 🤖 |
| C2 | UZI | 35 / 8 格 / 0.16s / 100 发，按住连发、弹药递减 | P0 | 🤖 |
| C3 | 霰弹 | 51×弹丸数，射程 7 格；**重制版 4 发（原版 3 发）——按现状断言，别当 bug** | P0 | 🤖 |
| C4 | 轨道炮 | 100 / 10 格 / 0.20s / 15 发；穿透一条线 | P0 | 🤖 |
| C5 | 火箭 | 250；命中有爆炸；射程按弹丸；**近距自炸会击退玩家**（友伤开时） | P0 | 🤖 |
| C6 | 手雷 | 150；投掷距离约 6 格；延时爆炸 | P1 | 🤖 |
| C7 | 地雷/油桶/炸药包 | 放置后可被引爆；爆炸半径符合伤害公式 | P1 | 🤖 |
| C8 | 假墙 | 可放置、阻挡寻路与子弹；被打碎后障碍移除 | P1 | 🤖 |
| C9 | 弹药与空仓 | 弹药为 0 不能开火；切枪后弹药独立 | P0 | 🤖 |
| C10 | 升级生效 | Double/Quad Damage、Fast Fire、Double Ammo、Wide Shot、Big Bang、Cluster 均能改变数值/行为 | P1 | 🤖 |
| C11 | 拾取武器/补弹 | 捡同类武器补满弹药；新武器进入背包 | P0 | 🤖 |
| C12 | 音效/动画 | 每把枪有开火音与枪口/弹道表现，无缺失资源警告 | P2 | 👁 |

### D. 地形、道具与爆炸

| # | 用例 | 断言 | 优先级 | 自动化 |
|---|---|---|---|---|
| D1 | 油桶爆炸 | 半径 2.25 格；伤害 150；可连锁 | P0 | 🤖 |
| D2 | 墙可被打碎 | 10 HP；碎后格子障碍移除、流场刷新 | P0 | 🤖 |
| D3 | 爆炸焦痕 | 爆炸后贴花 +1；"血迹/印记"关闭时不再新增 | P1 | 🤖 |
| D4 | 屏幕抖动 | 爆炸触发相机 offset 抖动；`screenShake` 关闭后为 0 | P1 | 🤖 |
| D5 | 贴花上限/清理 | 贴花数 ≤ 400；换关卡清空 | P1 | 🤖 |
| D6 | 补给箱 | HP≤50% 开箱回血；否则给已解锁武器 | P0 | 🤖 |
| D7 | 障碍与寻路联动 | 放置/破坏后 `obstacleVersion` 变化，敌人/CPU 路径更新 | P1 | 🤖 |
| D8 | 地图边界 | 玩家/敌人不越界；相机夹取不出房间 | P1 | 🤖 |

### E. 关卡、流程与 UI

| # | 用例 | 断言 | 优先级 | 自动化 |
|---|---|---|---|---|
| E1 | 关卡选择 4 槽位 | 1P/2P 唯一；至少一个人类；CPU 可选；角色选择保存 | P0 | 👁 + 🤖 |
| E2 | 按槽位生成玩家 | 人数/颜色/按键对应正确 | P0 | 🤖 |
| E3 | 波次与难度 | 起始等级/倍率符合难度表；每波配额随关卡增长、同屏上限生效 | P1 | 🤖 |
| E4 | 分数/连杀/升级列表 | 击杀加分、连杀衰减、升级按表解锁 | P1 | 🤖 |
| E5 | 暂停/恢复 | 暂停时物理与行为树停摆，恢复后继续 | P0 | 🤖 |
| E6 | 场景切换 | 主菜单→关卡选择→游戏→结算，无残留节点/定时器 | P1 | 🤖 |
| E7 | 语言/文案 | 中英切换后 HUD/设置文案正确 | P2 | 👁 |
| E8 | 房间切换 | 不同房间尺寸、出生点、障碍加载正确 | P1 | 🤖 |

### F. 设置与持久化

| # | 用例 | 断言 | 优先级 | 自动化 |
|---|---|---|---|---|
| F1 | settings.cfg 读写 | 改完重启后设置保留；"恢复默认"生效 | P0 | 🤖 |
| F2 | 按键重映射 | 改键后游戏内立即生效；重置恢复 | P1 | 🤖 |
| F3 | 友伤/Devils/碰撞/速度 | 开关立即影响生成与伤害 | P0 | 🤖 |
| F4 | 血迹/抖动/血迹开关 | 关闭后不生成、界面立即清空 | P1 | 🤖 |
| F5 | 音频开关 | 音乐/音效开关生效 | P2 | 👁 |
| F6 | 设置面板打开时游戏暂停 | 打开设置不误触开火/移动 | P1 | 👁 |

### G. 性能与长跑

| # | 用例 | 断言 / 指标 | 优先级 | 自动化 |
|---|---|---|---|---|
| G1 | 基准帧率 | 640×480 拉伸窗口、焦点保持：1 CPU 无敌人 ≈ 57~60 FPS（vsync） | P0 | 🤖 |
| G2 | 压力帧率 | 3 CPU + 60 敌人：≥ 55 FPS（vsync 下），无 >100ms 卡顿 | P0 | 🤖 |
| G3 | 节点/内存稳定 | 30 分钟：`node_count` 波动 <10%，无持续增长；`orphan_count` 不增长 | P0 | 🤖 |
| G4 | 贴花/烟雾上限 | 贴花 ≤400；烟雾/爆炸节点会被释放 | P1 | 🤖 |
| G5 | 敌人卡死检测 | 任何敌人"有目标但 10 秒未移动"次数 = 0 | P1 | 🤖 |
| G6 | 坐标合法性 | 无 NaN/越界位置；无 INVALIDPOSITION 计数增长 | P0 | 🤖 |
| G7 | 长跑通关流程 | 连续 20+ 波：升级、复活、箱子刷新、连杀都正常 | P1 | 🤖 |
| G8 | 日志干净 | 无 SCRIPT ERROR；已知噪音（UID 警告、Beehave "No active debugger"）白名单 | P0 | 🤖 |

### H. 敌人 AI：逻辑判断、寻路与拥挤

> 背景：原版靠**格子预订**防重叠；重制里 `zombie.gd` 的每帧分离推力 `resolveOverlap()`
> **被注释掉了**（`zombie.gd:977`，避免不重叠时也轻微漂移），圆-圆分离只在**受击位移**
> （`zombie_hurt.gd` → `creatureCollide()` → `resolveCreatureOverlap`）时执行；
> 平时只靠 `MapData.reserveCell()/getZombieAt()` 让僵尸**不瞄准同一格**。
> 所以围攻、同点刷怪时身体仍可能重叠 —— 必须用数据测，不能只看"能动"。
>
> 敌人身体半径：僵尸 **14.4px**、恶魔约 **13~14px**；两圆相切距离约 **28.8px**，
> 这里把"中心距 < 26px（留 10% 容差）"判定为视觉重叠。

| # | 用例 | 断言 / 指标 | 优先级 | 自动化 |
|---|---|---|---|---|
| H1 | 空旷房间追击 | 玩家静止：僵尸 15s 内进入攻击范围（≤35px）；恶魔 10s 内进入 160px 并开始丢火球 | P0 | 🤖 |
| H2 | **绕障寻路** | 玩家与僵尸之间放一堵内墙：20s 内绕到攻击范围；全程位置不在障碍格；不出现"贴着墙原地抖" | P0 | 🤖 |
| H3 | 流场跟随 | 玩家瞬移到房间另一侧：5s 内敌人改向并绕行；方向突变后不再朝旧目标走 | P0 | 🤖 |
| H4 | 转向稳定性 | 贴墙/窄口时方向切换 ≤ 2 次/秒；位置在两点间来回 < 8px 持续 3s → 判失败（来回抖） | P0 | 🤖 |
| H5 | 不穿墙 | 所有敌人 `occupied_cell` / 位置格 ≠ 障碍格（`Spawn` 从场外进入阶段除外） | P0 | 🤖 |
| H6 | **不互相挤** | 任意两敌中心距 < 26px 的**持续时长 ≤ 0.5s**；同一格内敌人中心 ≥ 2 个的持续时长 ≤ 1s | P0 | 🤖 |
| H7 | 同点批量生成 | 同一出生点连刷 10 只：10s 后重叠对数 ≤ 1、全部离开出生点周围 1 格；不出现两只互顶卡死 | P1 | 🤖 |
| H8 | 围攻玩家 | 玩家被 8 只僵尸包围：停在攻击距离外沿，不全部压在同一点；`max_enemies_per_cell` ≤ 2（>2 持续 1s 判失败） | P1 | 🤖 |
| H9 | 恶魔距离控制 | 恶魔稳定保持 3~5 格；玩家贴近时恶魔后撤，不是站着被贴脸 | P1 | 🤖 |
| H10 | 状态机合法性 | 命中→hurt→恢复；死亡→尸体→2s 后消失；无非法跳转/卡在 hurt | P0 | 🤖 |
| H11 | 卡死检测 | 有目标时 10s 内累计位移 < 16px → 记一次卡死；整轮卡死次数必须为 0 | P0 | 🤖 |
| H12 | 敌人间提速/难度 | 难度/关卡提升后速度倍率生效（不改变寻路正确性） | P2 | 🤖 |
| H13 | 压力帧率 | 50 僵尸 + 5 恶魔同屏：FPS ≥ 55（vsync、窗口保持焦点），无 >100ms 卡顿 | P1 | 🤖 |

**如果 H6/H7 不通过，优先查这两层**（不要先动寻路）：

1. 格子预订：`MapData.reserveCell()/getZombieAt()` 是否只预订目标格、没预订"下一格"；
2. 身体分离：`zombie.gd:977` 的 `resolveOverlap()` 目前是注释掉的 —— 可以按"每 N 帧 + 死区"重新启用
   （只在中心距 < 26px 时推，避免不重叠也漂移），而不是恢复成每帧强推。

**推荐场景**

- 现有 `scene/test/test_flow_field.tscn`：50 僵尸压力 + 流场可视化，直接用来跑 H1/H3/H5/H7/H13；
- 建议新增 `scene/test/test_enemy_ai.tscn`：小房间 + 一堵内墙 + 窄口，专门跑 H2/H4/H8/H9（可复用 `test_rooms` 的房间加载）。

**判定用的采样**

每 0.2s 采一次敌人列表，计算：

```
min_pair_dist        = min 所有敌人两两中心距
overlap_pairs        = 中心距 < 26px 的对数
same_cell_pairs      = 同一格内敌人对
max_enemies_per_cell = 单格敌人中心数最大值
stuck_count          = 有目标且 10s 位移 < 16px 的敌人数
dir_flip_per_sec     = 敌人单位方向每秒翻转次数（>2 视为抖动）
path_progress        = 到目标的距离随时间是否单调下降（允许短暂绕路）
```

---

## 3. 长跑监控（建议每 10 秒采样一次）

```
t, fps, process_ms, physics_ms, enemy_count, player_count, cpu_count,
node_count, orphan_count, decal_count, memory_mb, wave, score,
stuck_enemies, invalid_pos_count, nan_positions,
min_pair_dist, overlap_pairs, max_enemies_per_cell, dir_flip_per_sec
```

判红条件（任一）：

- 连续 5 次采样 FPS < 45（焦点状态）；
- `node_count` 30 分钟内单调上涨 > 10%；
- 出现 SCRIPT ERROR 或 NaN 位置；
- 任一敌人 `stuck > 10s`；
- 玩家/CPU 卡在障碍里超过 2 秒；
- 敌人两两中心距 < 26px 持续超过 0.5s（挤在一起）；
- 任一敌人位置落在障碍格（穿墙）。

---

## 4. 已知偏差（别当 bug 断言）

- 霰弹枪：重制 4 发（`-15/-7.5/0/+7.5` 再随机），原版 3 发对称；对同一目标一枪最多 1 发伤害（`excludeObj` 共用）。
- 击退模型：枪械走 `hitFeedback` 正数（跳过伤害×质量公式）、恶魔质量 1.0、硬直固定 0.5/0.4s、60Hz 结算。详见 `doc/future-improvements.md` §射击与击退。
- 火箭 `wRange = 0`（弹丸武器），CPU 用 `effectiveRange()` 按 320px 估算。
- 血量/贴花密度按 60Hz 计算，比原版 25Hz 密，属预期。
- CPU：受击 Hurt 期间行为树停摆（标签会停在受伤前状态）。

---

## 5. 测试记录模板

```markdown
## 2026-MM-DD 第 N 轮
- 版本/提交:
- 场景: test_cpu / map / 关卡选择
- 环境: Godot 4.7.2, GL Compatibility, 窗口 960×720, 焦点保持
- 用例: A1 ✅ A2 ✅ ...（失败项截图/快照）
- 失败详情:
  - 用例 / 期望 / 实际 / 快照字段 / 复现步骤
- 性能采样: 见 §3 表
```

---

## 6. 分阶段落地

| 阶段 | 内容 |
|---|---|
| T0 | 实现 `TestBridge`（快照 + input + spawn + screenshot + quit），只在 `--test-bridge` 启用 |
| T1 | 写 Python/Node 驱动脚本：跑 A/B/C 组的 P0 用例，生成报告 |
| T2 | 安装 GdUnit4，把确定性规则（伤害/半径/弹药/设置读写）下沉成单元测试，进 CI |
| T3 | 长跑脚本（30 分钟）+ 指标看板（FPS/节点数/贴花数/卡死计数） |
| T4 | 截图回归（视觉）：关键界面/特效存档对比 |

---

## 7. 测试驱动脚本生成规格（给其他 AI）

> §1.4 里的 `doc/tools/run_bridge_tests.py` 只是**参考实现**。下面这份规格足够让另一个 AI 从零生成等价脚本；
> 生成时不要改 `TestBridge` 的协议，否则两边对不上。

### 7.1 前置条件

- 项目：`F:oxHead-remakeox-head-remake`（Godot 4.7.2）。
- `autoload/test_bridge.gd` 已注册在 `project.godot`，**只有带 `--test-bridge` 时才启动**。
- 可用场景：`res://scene/test/test_cpu.tscn`、`res://scene/test/test_flow_field.tscn`、`res://scene/map.tscn`。
- 引擎可执行文件随机器而定（参考：`F:\Godot_v4.7.2-stable_win64_console.exe`），生成脚本时要求从常量/参数读取，不要写死多处。

### 7.2 启动命令模板

```bash
# 功能回归
<GODOT> --headless --path <PROJ> <SCENE> -- --test-bridge --test-bridge-port=<PORT>

# 长跑（map + 4 槽位 + 加速 + 全队无敌）
<GODOT> --headless --path <PROJ> --time-scale <N> res://scene/map.tscn         -- --test-bridge --test-bridge-port=<PORT> --slots=1,2,3,3
```

要求：

- `<PORT>` 由脚本用 `bind(("127.0.0.1", 0))` 选空闲端口后传入（**不要写死 8765**，本机可能被占用）；
- 连接最多重试 30 秒（冷启动 + 导入可能 8~10 秒）；
- 每次运行结束：先发 `{"cmd":"quit"}`，超时再 `terminate`，最后按快照里的 `pid` 精确 `taskkill /PID`（不要按进程名杀，避免误伤编辑器）。

### 7.3 协议（行分隔 JSON，UTF-8）

**命令**

| cmd | 参数 | 返回 |
|---|---|---|
| `ping` | — | `{ok:true}` |
| `snapshot` | — | 见 7.4 |
| `spawn` | `kind`(zombie/devil/box/barrel), `x`, `y`, `hp?`, `speed?` | `{ok,id}` |
| `clear_enemies` | — | `{ok,cleared}` |
| `set_hp` | `playerId`, `hp` | `{ok}` |
| `grant_weapons` | `playerId?`（缺省=所有 CPU） | `{ok,cpus}` |
| `teleport` | `playerId`, `x`, `y` | `{ok}` |
| `set_setting` | `key`, `value` | `{ok}` |
| `pause` | `paused` | `{ok,paused}` |
| `god` | `on` | `{ok,god}`（每秒为所有玩家续无敌） |
| `input` | `action`, `pressed` | `{ok}` |
| `screenshot` | `path` | headless 下返回 `{ok:false}` |
| `quit` | `code?` | `{ok}` |

**7.4 快照字段（生成脚本必须按这些键取值）**

```
ok, pid, scene, mapSize[2], paused, fps
players[]: id, isCpu, hp, maxHp, dead, state, pos[2], weapon, weaponName, ammo
cpus[]:    id, strategy, branch, hasTarget, targetDist, wantFire, boxTarget, props, stuckMs
enemies[]: type, hp, state, pos[2], id
metrics:   count, minPairDist, overlapPairs, maxPerCell, obstacleCount, stuckCount
decalCount, boxCount, nodeCount, orphanCount, memMb, ticks, simTimeSec, wave, score
settings:  friendlyFire, blood, screenShake
```

### 7.5 必须实现的用例（P0/P1）

参考 §2 的编号，最小集：

| 组 | 用例（判定方式） |
|---|---|
| 基础 | 快照可读、场景路径匹配、玩家数正确 |
| CPU | CPU 存在且有策略；刷僵尸后 5s 内 `hasTarget`；20s 内敌人清空；低血+放箱子 10s 内出现 `branch=="survive"` 且接近/捡起；暂停后 1s 内位移 <1.5px；`set_setting` 读写生效 |
| 敌人 | 同点刷 8 只后 8s 内 `overlapPairs<=5` 且 `maxPerCell<=2`；50 只压力场景 40s 内生成、20s 后 ≥25 只进入玩家 300px；`obstacleCount==0`、`stuckCount==0`；瞬移玩家后 8s 平均距离下降 |
| 长跑 | `--longrun`：map + `god`，每 5s 采样；断言见 §7.6 |

### 7.6 长跑断言（每分钟参考）

- 响应：采样数 ≥ 期望的 80%；
- 进展：`wave` 或 `score` 有增长；
- 节点：后 20% 采样中位数 < 前 20% × 1.6 + 300；
- 孤儿节点 ≤ 32；贴花 ≤ 400；
- `obstacleCount>0` 的采样 = 0；
- 卡死（`stuckCount>0`）采样占比 ≤ 15%；重叠（`overlapPairs>8`）占比 ≤ 10%；
- 内存：后 20% 中位数 < 前 20% × 1.6 + 80MB；
- 日志无 `SCRIPT ERROR`。

**停滞诊断（重要）**：若 `score` 连续 6 个采样（30s）不增长且场上敌人 ≤2，打印一次剩余敌人的
`type/hp/state/pos` 和所有玩家 `id/isCpu/pos/hp` —— 长跑里发现"波次卡住"靠的就是这段输出。

### 7.7 输出与退出码

- 每条用例一行：`PASS 名称 | 详情` / `FAIL 名称 | 详情`；
- 结束打印 `汇总：X/Y 通过`；
- 全部通过退出码 0，否则 1；
- 异常时打印 Godot 日志尾部（脚本应把 stdout 重定向到临时日志并保留路径）。

### 7.8 可直接粘贴的生成提示词

```text
你是 Godot 4.7.2 项目的测试工程师。项目在 F:oxHead-remakeox-head-remake，
已有一个 autoload：autoload/test_bridge.gd（仅当启动参数带 --test-bridge 时启用，
监听 127.0.0.1:<port>，按行收发 JSON）。请生成 doc/tools/run_bridge_tests.py，要求：
1) 只用 Python 标准库（socket/json/subprocess/threading/time/tempfile/argparse）。
2) 自动选空闲端口；启动：
   <GODOT> --headless --path <PROJ> [--time-scale N] <SCENE>
           -- --test-bridge --test-bridge-port=<PORT> [--slots=1,2,3,3]
   连接重试 30 秒；结束后 quit → terminate → 按快照 pid 精确 kill。
3) 实现命令：ping/snapshot/spawn/clear_enemies/set_hp/grant_weapons/teleport/
   set_setting/pause/god/input/quit。快照字段见规格 7.4（键名必须一致）。
4) 用例与判定：规格 7.5（基础/CPU/敌人/长跑）。长跑额外提供停滞诊断（7.6）。
5) 输出 PASS/FAIL 行 + “汇总：X/Y 通过”，全过退出 0，否则 1；失败时打印 Godot 日志尾部。
6) 场景参数：--scene test_cpu|test_flow_field|both|map；长跑：
   --longrun --minutes 5 --time-scale 3 --ff on|off。
7) 不要修改 test_bridge.gd，不要引入第三方依赖。
```

### 7.9 已知坑（生成后自检）

- 长跑必须 `god`（否则玩家会被打死导致提前 Game Over），且长跑前记得设置 `friendlyFire` 或用 `--ff off`，避免"队友挡枪"把 CPU 卡死；
- `snapshot` 里的 `state` 是旧状态字段，敌人可能长期停在 9（不代表卡在出生），判断卡死请用 `stuckCount`/位置变化；
- `obstacleCount` 已排除"出生/从场外走进来"的敌人；但它只按**原点**判格子，贴墙时受击盒仍可能在墙里（见 §2.H 备注）；
- 控制台中文可能因 GBK 显示乱码，JSON 数据本身是 UTF-8，报告里存 UTF-8 即可。

