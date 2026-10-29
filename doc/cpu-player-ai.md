# CPU 玩家 AI 设计

> 目标：在重制版里加入可由电脑控制的「玩家」（CPU / NPC），能和 1P、2P 一起玩。
>
> 设计约束：
> - **决策层用 Beehave 行为树**（插件，需先安装），执行层沿用现有的 Player + 状态机；
> - 先做独立测试场景，验证到可接受后再在 `map` 里启用（关卡选择的 CPU 槽位已经做好）；
> - 不做全图 A*，复用项目已有的格子 / 距离场设施。
>
> 引用约定：重制版路径相对 `box-head-remake/`；`F:\scripts` 为原版明文 AS2 源码。

---

## 0. 一句话结论

CPU 玩家 = **低频决策（Beehave，10Hz 左右）+ 每帧执行（现有 Idle 状态）**：

- **决策**只产出三样“意图”：往哪走（8 向）、朝哪打（精确方向）、要不要开火，外加“想用哪把枪”；
- **移动**优先直线，被挡了才查一张**敌人源距离场**（共享、只存 dist、方向现算），不做逐 CPU 的 A*；
- **感知**每 0.2 秒索敌一次（先按距离筛，再对前 3 名做视线射线）；
- **武器 / 策略**都用「打分 + 滞回」选择，强制冷却，避免来回切换和来回摇摆。

---

## 1. 现状盘点（设计的前提）

| 已有能力 | 位置 | 说明 |
|---|---|---|
| 4 个玩家槽位、1P/2P/CPU | [mapData.gd:74-84](file:///F:/boxHead-remake/box-head-remake/autoload/mapData.gd#L74) | `playerSlots`，关卡选择界面已接好 |
| 按槽位生成玩家 | [map.gd:150-168](file:///F:/boxHead-remake/box-head-remake/script/map.gd#L150) | CPU 用 `playerId = 3,4,5` |
| CPU 开关 | [player.gd:28](file:///F:/boxHead-remake/box-head-remake/script/character/player.gd#L28) | `isCpu`；挂了 `CpuBrain` 走行为树，没挂则退回内联临时 AI |
| 临时 AI（回退） | [player.gd:800](file:///F:/boxHead-remake/box-head-remake/script/character/player.gd#L800) | `cpuUpdateAi()`：索敌 + 保持距离 + 开火 + 卡住绕行（P4 删除） |
| 行为树大脑 | [script/ai/cpu_brain.gd](file:///F:/boxHead-remake/box-head-remake/script/ai/cpu_brain.gd) | `class_name CpuBrain`：Area2D 感知 + Beehave 树 + 选枪 |
| 危险物层 | [project.godot](file:///F:/boxHead-remake/box-head-remake/project.godot) / `fireball.tscn` | 新增第 8 层 `hazard`，火球加入该层与同名组 |
| 玩家状态机 | `script/fsm/*`、`player_states/*` | Idle / Hurt / Dead，移动只在 Idle 里做 |
| 8 方向朝向 | [player.gd:719-723](file:///F:/boxHead-remake/box-head-remake/script/character/player.gd#L719) | `angle = round(vector.angle()/(PI/4))`，动画按 8 向 |
| 障碍格 | [mapData.gd:366](file:///F:/boxHead-remake/box-head-remake/autoload/mapData.gd#L366) | `isObstacle(cell)`，油桶/墙/房间墙都登记 |
| 多源流场（给敌人） | [mapData.gd:818-886](file:///F:/boxHead-remake/box-head-remake/autoload/mapData.gd#L818) | `computeFieldMulti(seeds)` → `flowFieldDict["multi"]` + 全局 `navDist` |
| 读流场方向 | [mapData.gd:521-527](file:///F:/boxHead-remake/box-head-remake/autoload/mapData.gd#L521) | `getFlowDir(pos, "multi")` |
| 流场刷新节奏 | [map.gd:688-700](file:///F:/boxHead-remake/box-head-remake/script/map.gd#L688) | 每 60 物理帧一次，`flowDirty` 时立刻 |
| 敌人组 / 玩家组 | `zombie.tscn:1075`、`player.tscn:2547` | `"enemy"` / `"player"` |
| 友伤开关 | [mapData.gd:361](file:///F:/boxHead-remake/box-head-remake/autoload/mapData.gd#L361) | `friendlyFireOn()` |

**友伤的实际语义（代码事实，设计必须依赖这点）**

- 关闭时：子弹对玩家**完全无效**（[hand_gun.gd:88-91](file:///F:/boxHead-remake/box-head-remake/script/weapon/hand_gun.gd#L88)、uzi:88、shotgun:144、railgun:100），爆炸对玩家也**完全无效**（含自己踩雷，[explosion.gd:113-114](file:///F:/boxHead-remake/box-head-remake/script/fx/explosion.gd#L113)）。
- 开启时：玩家之间、玩家与自己的爆炸都会互相伤害。

**武器真实数值**（[mapData.gd:671-706](file:///F:/boxHead-remake/box-head-remake/autoload/mapData.gd#L671)，升级会改伤害/射速/弹药）

| 武器 | 伤害 | 射程 | 间隔 | 弹药 | 备注 |
|---|---|---|---|---|---|
| Pistol | 26 | 256 (8 格) | 0.32s | ∞ | 保底武器 |
| UZI | 35 | 256 | 0.16s | 100 | 连发，近距离压制 |
| Shotgun | 51/弹丸 | 224 (7 格) | 0.48s | 20 | 贴脸爆发 |
| Railgun | 100 | 320 (10 格) | 0.20s | 15 | 远距离穿透 |
| Rocket | 250 | 弹丸 | 0.48s | 20 | 爆炸半径 ≈88px（2.75 格） |
| Grenade | 150 | 投掷 192 | 0.48s | 20 | 爆炸半径 ≈72px |
| Mine / Barrel / ChargePack | 100~150 | 放置 | — | 10 | 爆炸半径 2~2.25 格 |
| Wall | 0 | 放置 | — | 5 | 纯障碍 |

---

## 2. 总体架构

```
┌───────────────────────────── 决策层（Beehave，~10Hz）─────────────────────────────┐
│  感知叶子 ──> 黑板(Blackboard) ──> 策略叶子 / 选目标 / 选武器 / 移动意图 / 开火意图   │
└───────────────────────────────────────┬──────────────────────────────────────────┘
                                        │ 黑板书：move_dir(8向) / aim_dir / want_fire / weapon_hint
┌───────────────────────────────────────▼──────────────────────────────────────────┐
│  执行层（每帧，现有 Player.updateIdle）                                            │
│  移动 → 格子阻挡滑行 → move_and_collide；开火 → currWeapon.fire(aim_dir)           │
│  受击/死亡由 FSM 的 Hurt / Dead 状态接管，决策层在此期间不输出意图                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

设计原则：

1. **树只写意图，不直接改坐标**。所有位移仍走玩家现有的碰撞与边界逻辑，CPU 和人类行为一致（贴墙滑行、格子阻挡、Z 排序都不会走偏）。
2. **决策低频**：Beehave `tick_rate` 设 0.1~0.2s。位移与开火每帧消费上次决策，避免 60Hz 下反复抖动。
3. **一套逻辑，两套驱动**：`isCpu` 为真时 `updateIdle` 只读 CPU 指令，不读 `Input`；人类分支保持原样。
4. **敌人仍然只认 `"player"` 组**：CPU 天然会被僵尸当作目标，也会作为流场种子，不需要额外改敌人逻辑。

---

## 3. 导航设计（重点）

### 3.1 需求与地图特征

- 网格 32px；房间规模 374 格（room_001 704×544）到 1640 格（room_0018 2624×640）。
- 障碍稀疏（墙、油桶、假墙、地图边界），但**存在凹形房间和窄口**：纯转向会在 U 形墙角打转、在窄口反复碰撞。
- CPU 只用 8 向移动（动画本身就是 8 向），不需要像素级平滑绕障。

### 3.2 候选方案对比

| 方案 | 每次代价 | 凹形/窄口 | 多 CPU 扩展 | 结论 |
|---|---|---|---|---|
| A. 纯转向 + 贴墙滑行 | ~0 | 会卡在局部最小 | 好 | 只适合开阔房间 |
| B. 全图 A*（每个 CPU 各自重算） | O(格数·log) × CPU 数 × 重算频率；GDScript 字典键开销大 | 好 | 差 | 不采用 |
| C. 复用现有 `"multi"` 流场 | 0 | 方向错（指向玩家） | 好 | **不能直接用** |
| D. **敌人源距离场（共享）+ 直线优先** | 每次 BFS ≈ 1640 格 × 8 邻居，2~3Hz | 好 | 好（全员共用一张） | **推荐** |
| E. 局部窗口 A*（LOS 断时） | 400 格级别，按需 | 好 | 中 | 作为 D 的降级备选 |

结论：**D 为主，A 作为常态路径，E 不做**。理由：

- 地图最大也就 1640 格，一次 BFS 是微秒~毫秒级，2~3Hz 刷新完全可接受；而 A* 要按 CPU 数量、按目标变化重复算，性价比低。
- 距离场天生解决凹形和窄口（全局最短路径），而 CPU 只需要“下坡走一格”，不需要路径点。
- 所有 CPU 共享同一张场，CPU 数量从 1 涨到 3 时成本不增加。

### 3.3 推荐实现

**场的定义**

- 新增独立槽位 `"cpu"`：**只存距离**（`cpuDist: Dictionary`），**不存方向场**。
- 种子 = 所有存活敌人所在格（僵尸 / 恶魔）。
- 方向在每个 CPU 所在格现算：查 8 邻域的 `cpuDist`，取最小者 → 8 向单位向量。每 CPU 每帧 8 次字典查询，可忽略。

**为什么不复制整套 `computeFieldMulti`**

- 现有实现会把 `navDist` 写全局、并遍历全图生成方向字典（[mapData.gd:473-486](file:///F:/boxHead-remake/box-head-remake/autoload/mapData.gd#L473)）。敌人靠 `navDist` 工作，**第二次调用会覆盖它**。
- 所以新增独立实现：`computeCpuField()` 自己从 `enemy` 组取种子做 BFS，结果写进 `MapData.cpuDist`（不碰 `navDist` / `flowFieldDict`）。

**刷新策略**

| 触发 | 频率 | 说明 |
|---|---|---|
| 定时 | 0.4s | 敌人一直在动，距离场要跟上 |
| `obstacleVersion` 变化 | 立即 | 油桶/假墙增删后重新算 |
| 敌人数量变化（生/死） | 合并到下一次定时 | 不必逐次重算 |
| 场上有 CPU 且有敌人 | 才计算 | 没有 CPU 时零开销 |
| 敌人全灭 | 不计算 | CPU 改用“回到人类队友身边”（见下） |

**移动决策（每个 CPU 每帧）**

1. 有目标且在射程带内 → 按策略输出走位（侧移 / 保持距离 / 前进）。
2. 目标较远 → 先试**直线**：用格子 DDA（或一次墙体射线）确认目标方向无遮挡 → 直接 8 向走过去。
3. 直线被挡 → 查 `cpuDist` 当前格 8 邻域，取 dist 最小的邻居方向；如果邻格 dist 都 ≥ 当前格（孤立/无路），退化为：
   - 有敌人：侧向绕行 0.5s（现有 `cpuDetour` 逻辑）；
   - 无敌人或不可达：用现有 `"multi"` 场（玩家源）回家找队友——这正好是“撤退/归队”想要的方向。
4. 卡住检测沿用现有实现（0.6s 没挪动 → 侧向绕行），另加“窄口对齐”：若前方连续 2 帧被挡且目标在正前方 ±22.5° 内，先沿墙切向走 0.3s 再回正。

**成本估算（1640 格的大房间）**

| 项 | 估算 |
|---|---|
| 一次 BFS（含斜角检查） | ~13k 次字典查询，≈1~3ms（GDScript） |
| 刷新频率 | 2.5Hz → 平均 <0.01ms/帧 |
| CPU 读方向 | 8 次查询/帧/CPU，3 CPU ≈ 0.003ms |
| 目标：后续优化 | 把 `cpuDist` 换成 `PackedInt32Array`（见 `future-improvements.md` 的数组化方案），可再降一个量级 |

> 如果之后地图继续变大，再考虑方案 E（局部窗口 A*）作为兜底，而不是上全图 A*。

### 3.4 为什么必须是独立的一张场？到底花不花时间？

**必须独立**（不能复用现有 `"multi"`）：

1. `"multi"` 的种子是**玩家**，方向是"朝玩家走"；CPU 要的是"朝敌人走"，方向完全相反，靠取反也绕不开多玩家多源的叠加（Voronoi 分区是按玩家划分的，取反会把人推到最近玩家身边）。
2. 现有 `computeFieldMulti()` 会写全局 `navDist`（敌人 `Nav_Direction` 依赖它），第二次调用会把敌人的距离场覆盖掉。

**成本没有想象中大**，原因有三：

| 因素 | 说明 |
|---|---|
| 不做方向场 | 现有实现在 BFS 之后还要遍历**每一格 × 8 邻居**生成方向字典；CPU 只有 ≤3 个，每帧只需要自己那一格的 8 个邻居，所以新场**只存 dist**，方向现算，直接省掉一半以上的遍历 |
| 全员共享 | 一张场服务所有 CPU，CPU 数从 1 涨到 3 不增加计算量 |
| 低频刷新 | 0.4s 一次（2.5Hz）；敌人全灭不计算；没有 CPU 不计算 |

粗算（最大房间 1640 格，GDScript 字符串键字典）：

| 项 | 单次 | 均摊到每帧（60fps） |
|---|---|---|
| BFS（约 1.3 万次字典操作） | 1~3 ms | 0.004~0.012 ms（2.5Hz） |
| CPU 读方向（3 CPU × 8 邻域） | — | < 0.005 ms |
| 合计 | — | **< 0.02 ms / 帧（一帧 16.6 ms 的 0.1%）** |

格子数翻 4 倍也才 ~0.08ms/帧。真要再省，按优先级：

1. **事件驱动**：只有"至少一个 CPU 失去直线视野"时才重算（开阔房间几乎不触发）；
2. **只刷新必要区域**：从 CPU 所在格反向做局部 BFS（代价上界 = 到最近敌人的距离）；
3. **数组化**：`PackedInt32Array` + 扁平下标，字典开销直接降一个数量级（同 `future-improvements.md`）。

结论：**值得做，不是瓶颈**。已按此实现：`MapData.computeCpuField()`（只存 `cpuDist`）+ `cpuFieldDir()/cpuFieldAwayDir()`（方向现算），`CpuBrain.pathDir()` 在"直线被挡"时才查场，刷新由 `ensureCpuField()` 统一节流（默认 0.4s / 障碍变化）。

---

## 4. 感知能力（Area2D 方案）

### 4.1 用 Area2D 而不是遍历节点组

CPU 控制器自带一个感知 `Area2D`（代码创建，半径默认 12 格 = 384px），一次宽相查询就能拿到范围内所有候选，**不需要在每个 tick 里 `get_nodes_in_group` 后再逐个算距离**：

| 检测对象 | 物理层 | 拿法 |
|---|---|---|
| 僵尸 / 恶魔本体（CharacterBody2D） | layer 2 `enemy` | `get_overlapping_bodies()` |
| 僵尸 / 恶魔受击区（Area2D） | layer 6 `enemyBody`（值 32） | `get_overlapping_areas()` → `owner` 取本体 |
| 恶魔火球（危险物） | layer 8 `hazard`（值 128，**本次新增**） | `get_overlapping_areas()`，按 `hazard` 组识别 |

- 火球原本 `collision_layer = 0`，任何 Area2D 都感知不到；本次给它加了第 8 层 `hazard` 并加入 `hazard` 组（`scene/projectile/fireball.tscn`），不影响它自己的 `collision_mask = 52`（它只负责撞墙/撞人）。
- CPU 的感知 Area2D：`collision_layer = 0`、`monitorable = false`（不占层、也不被别人看到），只做监听。
- 兜底：火球数量极少，如果某个场景层级没配对，控制器会再按 `hazard` 组按距离补扫一次，保证躲火球逻辑不会因为层配置失误而完全失效。

### 4.2 选目标

- 每个 tick（0.1s）刷新一次：取感知范围内**距离最近**的敌人作为目标；`target` 写入黑板。
- 目标评分（P3 再加）：距离 × 威胁（恶魔 1.4 > 僵尸 1.0）× 队友受威胁加成 − 被其他 CPU 锁定的惩罚（分散火力）。
- 目标粘滞（P3 再加）：新目标要高出 15% 才换；丢失目标时保留最后位置 1.2s。
- 不做视野锥：原版敌人是全向感知，CPU 也全向，省得背身挨打。
- **开火前做一次墙体视线检查**（射线掩码 4|8 = 油桶/假墙 + 房间墙）：感知不滤遮挡（省钱），但打不穿墙就不浪费子弹，也顺带避免误射挡在中间的油桶。

---

## 5. 友伤与安全

| 场景 | `friendlyFire` 关闭 | `friendlyFire` 开启 |
|---|---|---|
| 普通子弹 | 玩家免疫，**无需避让** | 开火前检查：队友在「方向锥 ±22.5°、距离 160px」内 → 不开火，改为侧移换角度 |
| 爆炸物（火箭/手雷/地雷/油桶/炸药包） | 玩家免疫，仍避免贴脸（浪费弹药、遮挡视线） | 队友（或自己）在**爆炸半径 + 1 格**内 → 不发射 / 换枪 |
| 油桶 | 可以打 | 队友在油桶爆区（半径 2.25 格 + 1 格）内 → 不打 |
| 队友枪线 | 不处理 | 低优先：站位尽量不站在队友与目标的连线上（SUPPORT 策略除外） |

实现要点：

- 判断“队友是否在爆区”只需距离比较（爆炸半径可由伤害公式推出：`2 + max(damage-100,0)*0.005` 格）。
- 判断“是否挡枪线”用队友相对方向与瞄准方向的点积（`to·aim / |to| > cos(22.5°)`），不额外做射线。
- 开关中途变化不用特殊处理：每次决策重新读 `MapData.friendlyFireOn()`。

---

## 6. 策略（打法）

每个 CPU 有一个**主策略**，15 秒级别切换；策略决定交战距离、追击上限、撤退阈值和武器偏好。

| 策略 | 交战距离 | 追击上限 | 撤退条件 | 偏好武器 | 站位 |
|---|---|---|---|---|---|
| **AGGRESSIVE**（突进） | 武器理想距离 ×0.85 | 不限 | HP < 25% | UZI / Shotgun / Rocket | 主动拉近，绕后 |
| **DEFENSIVE**（防守） | 武器理想距离 ×1.0 | 6 格 | HP < 40% 或 2 个以上敌人贴脸 | Pistol / Railgun | 守住当前区域，敌人靠近就后退 |
| **SUPPORT**（跟随支援） | 60%~85% 射程 | 距队友 5 格内 | 队友倒地 | Pistol / Railgun / Shotgun | 跟着最近的人类，只打威胁他和自己的敌人 |
| **KITER**（放风筝） | 武器理想距离 ×1.15 | 8 格 | HP < 30% | Railgun / Pistol | 侧向绕圈，始终保持最大射程 |
| **RESCUE**（救援，最高优先级） | 贴队友 3~5 格 | 距队友 5 格 | 队友脱险 / 超时 | UZI / Shotgun | 挡在队友与敌人之间，优先清队友身边的敌人 |
| **PATROL**（巡逻，无敌人时） | — | 锚点 6 格 | 发现敌人立即切回战斗策略 | 任意 | 在锚点附近随机走动，到点停留 0.5~1.5s |

### 6.1 救援策略（本次新增）

触发条件（任一满足）：

- 最近的人类队友 **HP < 35%**；
- 该队友**当前武器弹药 < 15%**（有限弹药的枪）；
- 队友身边 4 格内敌人 ≥ 3（被围）。

前置限制（"保存实力"）：

- 距队友 **> 12 格（384px）→ 不救**，按当前策略继续行动；
- 队友已死亡 → 不救（等待复活机制）。

行为：

- 向队友靠拢，保持 **3~5 格**；进入区间后侧向游走，不挡在队友枪口正后方；
- **目标重排**：优先打队友 4 格内的敌人（`enemyNear(ally, 4 格)`），没有才打自己的最近目标；
- 武器偏好 UZI / Shotgun（近距离清场）；爆炸物同样受"队友在爆区不发射"约束；
- 优先级：**躲火球 > 救援 > 撤退 > 战斗 > 跟队**。救援是"救场"，允许打断战斗分支，但本身有 8 秒超时，避免追着队友跑一整天。

退出：

- 队友 HP 回到 50% 以上且身边没有敌人；或
- 距离被拉开到 12 格以外；或
- 持续 8 秒，强制回到普通策略（重新评估，不立即再次救援）。

### 6.2 巡逻策略（本次新增）

- **触发**：感知范围内没有敌人、也没有"最后见到目标"的记忆。此时若人类队友距离 > 8 格，先归队（SUPPORT）；否则进入 **PATROL**。
- **行为**：以"进入巡逻时的位置（有队友则取队友位置）"为锚点，**一格一格走**：随机选一个能走的 8 向方向，走 **4~7 格**，然后原地歇 **1.5~3.5 秒**再选下一个方向。进入巡逻时也会先站 1~2.5 秒，不会立刻乱窜。
- **选方向前会检查整格占用**：静态障碍（墙/油桶）、其他玩家、敌人、可玩区域边界，任一不满足就换方向；离锚点超过 5 格会先往回走。
- **卡住**：方向被挡 / 走进新格子的节奏停住就停下重选，不会顶着墙一直推。
- 锚点会跟随队友（队友走远 4 格就重置锚点），避免 CPU 巡逻走丢。
- **退出**：`Perceive` 一旦发现敌人，战斗分支排在巡逻之前，会先接管；`updateStrategy` 在下一 tick 检测到"当前是巡逻且有目标"时**立即**切回性格对应的战斗策略（不等 15 秒驻留）。
- 巡逻时不主动开火（`cpuWantFire` 每 tick 由 `Perceive` 清零，巡逻分支不设置它）。

### 6.3 低血求生（本次新增）

- **触发**：血量 < **25%**，且（附近 14 格内有补给箱 或 有敌人）。
- **优先级**：躲避火球 > **求生** > 救援 > 撤退 > 拆物 > 战斗 —— 自己快死了先保命。
- **行为**：
  1. 有箱子 → 直奔箱子（箱子在玩家血量 ≤ 50% 时给回血，正好对应低血场景）；
  2. 没箱子 → 沿远离敌人的方向后退（被挡就沿敌人源距离场往"更远"的邻格退），同时**边退边开火**。
- **策略联动**：血量 < 25% 时主策略强制切到 **KITER（放风筝）**，交战距离按武器 ×1.15；25%~35% 仍走 DEFENSIVE。
- **退出**：血量回到 25% 以上（或箱子拿到、敌人消失）。

**策略选择**

- 出场时按 CPU 序号分配性格：CPU1 = AGGRESSIVE，CPU2 = DEFENSIVE，CPU3 = KITER（也允许随机加权）。
- 每 15 秒重新评估一次（打分 → 选最高），满足任一条件时**强制切换**并重置驻留计时：
  - HP < 30% → DEFENSIVE；
  - 最近的人类队友倒地 → DEFENSIVE（守尸/等复活）或 SUPPORT；
  - 场上敌人 > 8 且距离 > 10 格 → AGGRESSIVE（清场）；
  - 场上没有敌人 → SUPPORT（归队）。
- **滞回**：新策略分数需高出当前 20% 才切换，且两次切换间隔 ≥ 5 秒，避免来回摇摆。

---

## 7. 武器使用

### 7.1 每把武器的“认知”

| 武器 | 理想距离 | 危险/限制 | CPU 使用规则 |
|---|---|---|---|
| Pistol | 0~256 | 无限弹药 | 默认/兜底；其他枪没弹时回退 |
| UZI | 0~256 | 100 发，连发 | 近中距离压制，射速高，优先打血厚的恶魔 |
| Shotgun | 0~224 | 20 发，需贴脸 | 距离 < 2.5 格时优先；对群体无效（只打一条线） |
| Railgun | 0~320 | 15 发 | 远距离首选；穿透可打直线上的多个敌人 |
| Rocket | 96~320 | 爆区 88px | 中远距离；队友/自己在爆区内**绝不发射** |
| Grenade | 96~192 | 爆区 72px | 中距离；同样避开队友 |
| Mine / Barrel / ChargePack / Wall | — | 放置类 | **CPU 不使用**（需要战术放置，留到后续版本） |

**交战距离按武器决定**（`CpuBrain.idealDistance()`），策略只做小幅修正，不再"一律靠近到射程的 55%"：

| 武器 | 理想距离 | 策略修正 |
|---|---|---|
| Shotgun | 56px（约 1.75 格） | 突进 ×0.85 / 跟随 ×0.9 / 放风筝 ×1.15 |
| UZI | 168px | 同上 |
| Pistol | 208px | 同上 |
| Rocket | 240px | 同上 |
| Railgun | 300px（射程 320） | 同上 |

距离带内**站定开火**；只有"带内但射线被挡"才侧移找角度。

### 7.3 拆除油桶 / 墙（本次新增）

CPU 会**选择性**拆物，不是见什么打什么：

| 条件 | 判断 | 行为 |
|---|---|---|
| 墙挡在"CPU → 目标"的射线上 | 武器射线的第一命中是 Wall | 站定打墙（墙 10 血，一枪就碎） |
| 油桶挡在射线上 | 第一命中是 Barrel，且**爆区里没有自己人** | 站定打爆，清出射界 |
| 油桶旁边有敌人 | 敌人进入油桶爆区（半径按伤害公式），且自己人不在爆区 | 把油桶当炸药打（范围伤害） |
| 油桶在队友/自己爆区里 | `barrelSafeToBlow()` 为 false（**关闭友伤时直接放行**） | 不打，改走位/换目标 |
| 没有目标、附近也没敌人 | — | 不拆（避免无意义开枪浪费弹药） |

### 7.2 评分与切换（避免“一直切枪”）

```
score(w) = 距离适配 + 伤害效率 + 弹药余量 + 策略偏好 − 安全惩罚
距离适配 = 1 − |d − ideal| / 射程        （ideal 取策略的交战距离）
伤害效率 = damage / delay 归一化          （DPS 越高越好）
弹药余量 = min(ammo / maxAmmo, 1)         （无限弹药记 1）
安全惩罚 = 队友/自己在爆区 → −10
```

切换规则（**三条同时满足才换**）：

1. 当前武器不在“空弹/射程外/被安全规则禁用”的状态；
2. 最佳武器分数 − 当前武器分数 > 0.15；
3. 距上次换枪 ≥ 2 秒，且当前武器 `canShoot == true`（别在开火动画中途换）。

特例：当前武器弹药为 0 → 立刻换（跳过 2、3 条）；全部枪械没弹 → 回退 Pistol（无限）。

---

## 8. Beehave 行为树

### 8.1 插件与 API（已安装 2.9.3）

- 已安装到 `addons/beehave`（版本 **2.9.3**，Godot 4），无需再装。
- 关键 API（与早期版本不同，注意）：
  - `BeehaveTree.tick_rate` 的单位是**帧**（默认 1 = 每帧），0.1 秒要写 `6`；
  - 叶子继承 `ConditionLeaf` / `ActionLeaf`，实现 `tick(actor, blackboard) -> int`，返回 `SUCCESS / FAILURE / RUNNING`；
  - 组合节点：`SequenceComposite` 会**跳过本 tick 已成功的子节点**，条件不会每 tick 重判；需要"条件每 tick 重新判断"时必须用 **`SequenceReactiveComposite` / `SelectorReactiveComposite`**；
  - 黑板 `Blackboard`：`set_value(key, value)` / `get_value(key, default)`。
- 树**用代码搭**（`CpuBrain.buildTree()`），不依赖 `.tscn`：先把整棵子树建好再 `add_child(tree)`，避免 `BeehaveTree` 在空树状态下 tick；编辑器里的 Beehave 调试器照样能看到节点。

### 8.2 树结构（已实现）

```
BeehaveTree (tick_rate = 6 帧 ≈ 0.1s)
└── SequenceReactive  root
    ├── CanAct                      # CPU、未死、state == Idle
    ├── Perceive                    # Area2D 感知 + 敌人源距离场；每 tick 清空指令
    ├── PickStrategy                # 主策略（1s 节流 / 15s 驻留 / 强制切换）
    └── SelectorReactive  behaviour
        ├── SequenceReactive  dodge      FireballIncoming → Dodge
        ├── SequenceReactive  survive    ShouldSurvive → Survive（低血找箱子/放风筝）
        ├── SequenceReactive  rescue     ShouldRescue → Rescue
        ├── SequenceReactive  retreat    ShouldRetreat → Retreat
        ├── SequenceReactive  demolish   ShouldDemolish → Demolish（拆墙/炸油桶）
        ├── SequenceReactive  combat     HasTarget → PickWeapon → MoveToRange → FireIfSafe
        ├── SequenceReactive  search     HasLastKnown → MoveToLastKnown
        ├── SequenceReactive  patrol     ShouldPatrol → Patrol
        ├── SequenceReactive  follow     HasAlly → FollowAlly
        └── Idle
```

### 8.3 叶子清单（已实现）

| 叶子 | 文件 | 类型 | 职责 |
|---|---|---|---|
| `can_act` | `script/ai/leaves/can_act.gd` | Condition | 是否允许决策（Idle、未死、是 CPU） |
| `perceive` | `perceive.gd` | Condition | 调 `CpuBrain.scan()`，写 `target` / `hazards`，清空上帧指令 |
| `fireball_incoming` | `fireball_incoming.gd` | Condition | 有火球朝自己飞 → 选好侧闪方向 |
| `dodge` | `dodge.gd` | Action | 沿侧向闪避，朝向保持对着目标 |
| `should_rescue` | `should_rescue.gd` | Condition | 队友低血 / 低弹且距离 ≤ 12 格 |
| `rescue` | `rescue.gd` | Action | 贴队友 3~5 格，优先打队友身边的敌人 |
| `should_retreat` | `should_retreat.gd` | Condition | HP < 30% 且敌人贴脸 |
| `retreat` | `retreat.gd` | Action | 远离目标；有队友则往队友方向退 |
| `has_target` | `has_target.gd` | Condition | 黑板目标有效且存活 |
| `pick_weapon` | `pick_weapon.gd` | Action | 按距离选枪（滞回 + 冷却 + 空弹，逻辑在 `CpuBrain.bestGun`） |
| `move_to_range` | `move_to_range.gd` | Action | 保持"射程 60%"距离；直线 + 邻格障碍侧移 |
| `fire_if_safe` | `fire_if_safe.gd` | Action | 射程内 + 友伤检查通过才开火 |
| `has_ally` | `has_ally.gd` | Condition | 找最近的人类队友 |
| `follow_ally` | `follow_ally.gd` | Action | 超过 4 格才跟上去（被挡时借玩家流场绕路） |
| `pick_strategy` | `pick_strategy.gd` | Action | 更新主策略（内部节流 + 驻留 + 强制切换） |
| `has_last_known` | `has_last_known.gd` | Condition | 目标丢失但仍在 1.2s 记忆期内 |
| `move_to_last_known` | `move_to_last_known.gd` | Action | 去目标最后出现的位置（走距离场） |
| `should_survive` | `should_survive.gd` | Condition | 血量 < 25% 且有箱子/有敌人 |
| `survive` | `survive.gd` | Action | 去捡箱子；没箱子就边后退边打 |
| `should_demolish` | `should_demolish.gd` | Condition | 有挡路的墙/油桶，或有能炸到敌人的油桶 |
| `demolish` | `demolish.gd` | Action | 站定用当前枪拆掉该目标 |
| `should_patrol` | `should_patrol.gd` | Condition | 主策略=巡逻且无目标/无记忆 |
| `patrol` | `patrol.gd` | Action | 在锚点附近随机游走（卡住换点，到点停顿） |
| `idle` | `idle.gd` | Action | 原地待机 |

### 8.4 与执行层的接口（已实现）

`Player` 新增三个字段，树只写它们：

```gdscript
var cpuBrain: Node = null        # 子节点 CpuBrain 在 _ready 里认领
var cpuMoveDir: Vector2          # 8 向移动意图
var cpuAimDir: Vector2           # 精确瞄准方向（开火 + 朝向动画）
var cpuWantFire: bool            # 是否开火（已有字段）
```

`updateIdle()` 的分支：

```gdscript
if isCpu:
    if cpuBrain != null:
        if cpuAimDir != Vector2.ZERO: vector = cpuAimDir
        inputDir = cpuMoveDir
    else:
        inputDir = cpuUpdateAi(delta)   # 没挂行为树时的临时 AI（map 里暂时走这里）
else:
    inputDir = Input.get_vector(...)
```

换枪通过 `player.cpuRequestWeapon(type)`：当前枪在冷却时先不换，避免打断射击动画。

---

## 9. 测试场景（已实现）

`scene/test/test_cpu.tscn` + `script/test/test_cpu.gd`：加载 room_001、1 个人类（可操作、默认无敌）+ 1 个 CPU（带行为树），相机复用 `game_camera`。

**调试可视化（世界层）**

- 每个 CPU：蓝色感知圈、红色到目标的连线、绿色移动意图箭头、黄色到火球的连线；
- CPU 头顶显示编号与当前武器；
- 左上角文字：CPU 数量、友伤状态、行为树运行/暂停、人类无敌状态、场上敌人数。

**控件**

| 键 | 作用 |
|---|---|
| `1` / `2` | 减少 / 增加一个 CPU（0~3 个，依次给 playerId 3/4/5） |
| `Z` / `X` | 在人类身边 8 格内刷一只僵尸 / 恶魔 |
| `C` | 清空所有敌人 |
| `F` | 切换 friendlyFire（观察 CPU 是否停火） |
| `T` | 轮换所有 CPU 的主策略（突进 → 防守 → 跟随 → 放风筝） |
| `P` | 暂停 / 恢复所有 CPU 行为树 |
| `R` | 把 CPU 拉回出生点 |
| `空格` | 人类无敌开关 |

**验收清单**

- [ ] 直线可达时 CPU 直接走，不抖方向
- [ ] 中间隔墙时 CPU 从缺口绕过（不贴墙打转），窄口不反复碰撞
- [ ] 敌人移动后目标平滑切换，不出现每帧换目标
- [ ] 武器不会来回切（观察 30 秒内切换 ≤ 2 次，且都是因为空弹/距离变化）
- [ ] `friendlyFire` 开启时，CPU 不会朝队友方向开火，也不会在队友身边用爆炸物
- [ ] 人类低血/低弹且距离 ≤ 12 格时，CPU 会回到他身边清场；超过 12 格不来
- [ ] 恶魔火球飞来时 CPU 会侧闪（不是站着挨打）
- [ ] 队友倒地/无敌人时，CPU 会归队而不是原地发呆
- [ ] 3 个 CPU + 60 敌人时，帧率与无 CPU 时相差 < 2 帧

---

## 10. 性能预算

| 项 | 频率 | 预算 |
|---|---|---|
| Beehave tick | 10Hz/CPU | 每 tick < 0.05ms |
| 感知（Area2D 宽相 + 最近距离） | 10Hz/CPU | < 0.05ms |
| 距离场 BFS（全图，P1） | 2.5Hz（共享） | 1~3ms/次 |
| 每帧移动/开火指令消费 | 60Hz/CPU | 可忽略 |

合计：3 CPU 时平均每帧 < 0.05ms，峰值出现在距离场重算的帧（+1~3ms），可接受。

---

## 11. 分阶段实施

| 阶段 | 内容 | 状态 |
|---|---|---|
| **P0** | 安装 Beehave（2.9.3 已装）；`test_cpu.tscn` + `CpuBrain` 骨架 + 15 个叶子 + Player 接口 | **已完成**（未实机运行，仅静态检查） |
| **P1** | 敌人源距离场导航 + 窄口兜底 | **已完成**：`MapData.cpuDist/ensureCpuField/cpuFieldDir/cpuFieldAwayDir`，`CpuBrain.pathDir()` 接入走位/撤退/搜索 |
| **P2** | 目标评分/粘滞/记忆、队友枪线避让、爆炸物爆区检查 | **已完成**：`CpuBrain._targetScore/scan()`、`explosiveSafe()`、`cpuAllyInLine` |
| **P3** | 策略层（含 RESCUE / PATROL）+ 性格分配 | **已完成**：4 种战斗策略 + 巡逻 + 救援分支 + 性格按 playerId 分配 + 15s 驻留/20% 滞回 |
| **P4** | 删除临时 AI，`map` 里的 CPU 挂上 `CpuBrain` | 待做（关卡选择 CPU 槽位已就绪） |

### 已落地的骨架文件

| 文件 | 作用 |
|---|---|
| `script/ai/cpu_brain.gd` | `class_name CpuBrain`：Area2D 感知、代码搭行为树、选枪评分、队友/敌人查询 |
| `script/ai/leaves/*.gd` | 24 个叶子（见 §8.3） |
| `autoload/mapData.gd` | 敌人源距离场：`cpuDist / ensureCpuField() / computeCpuField() / cpuFieldDir() / cpuFieldAwayDir()` |
| `script/character/player.gd` | `cpuBrain / cpuMoveDir / cpuAimDir / cpuRequestWeapon()`，`updateIdle` 消费意图 |
| `scene/test/test_cpu.tscn`、`script/test/test_cpu.gd` | 测试场景 |
| `scene/projectile/fireball.tscn` | 火球加入 `hazard` 层（128）与 `hazard` 组，供感知 |

---

## 12. 风险与待定

1. **Beehave API 版本**：2.9.3 的 `tick_rate` 按帧、条件需用 Reactive 组合节点——已按实际源码核对；换版本时要重新确认。
2. **距离场字典开销**：大地图 + 高频刷新可能产生抖动；超预算时按 `future-improvements.md` 的数组化方案改造（`PackedInt32Array` + 扁平下标）。
3. **CPU 堵门/挡枪**：CPU 站在窄口可能把人类堵住；需要在走位层加“让路”规则（人类 1 格内且正在靠近 → 侧移）。
4. **CPU 抢击杀/升级**：升级是全局信号（所有玩家共享），CPU 击杀会推进全队升级——这是设计意图；若希望人类优先，需要单独的击杀归属规则。
5. **角色选择**：目前 CPU 与人类共用同一套精灵（仅换色），个性只体现在策略与颜色上。
6. **拾取/开箱**：本设计不包含；后续可加“顺路拾取”叶子。
7. **Area2D 火球感知**：依赖“单向监听”（CPU 的 mask 命中火球 layer）在 Godot 4 下成立；骨架里已加按 `hazard` 组的距离兜底，即使层级不生效也不会完全失效。

---

## 13. 实机测试记录（2026-10-30，Godot 4.7.2 / room_001）

本轮在测试场景里实际跑了一遍（人工按键驱动 + 截图/日志分析），确认了 6 个问题并当场修复。

### 13.1 修复的问题

| # | 现象 | 根因 | 修复 |
|---|---|---|---|
| 1 | CPU 站在僵尸旁边却始终 `ov0/0`、不索敌 | 感知 Area2D 挂在 `CpuBrain`（普通 `Node`）下，Node2D 的变换断了，Area2D 实际停在**世界原点** | `player.add_child(area)`，挂到玩家（Node2D）下 |
| 2 | 人类站在射线附近时 CPU 几乎不开火，子弹全打在无敌人类身上 | "队友挡枪"原来是 24°×160px 的锥形预判，太宽/太粗 | 改用**武器真实射线**：`CpuBrain.shotHitsTarget()`，第一命中必须是目标（队友/墙/油桶都会拦住），与开火几何完全一致 |
| 3 | 救援分支在 35% 血量附近反复进出 | 人类 30 秒回满血，回血越过阈值就退出、掉下来又进入 | 加滞回：进入 35%，已在救援中则到 **50%** 才结束 |
| 4 | 测试场景刷的僵尸朝左上角走、且感知不到 | 刷怪没设 `state = init` / `initPos`，僵尸按默认值往 (0,0) 走 | 照 `map.gd` 的刷怪方式补上 `initPos`、`state`、初速；测试场景另把敌人移速提到 60 |
| 5 | 恶魔不计入"敌人"数量，CPU 距离场/救援也找不到恶魔 | `devil.tscn` 不在 `enemy` 组 | 根节点加 `groups=["enemy"]`（已确认现有组逻辑只按 Character 处理，安全） |
| 6 | 行为树一创建就报 "Node not found: BeehaveGlobalDebugger" | Beehave 的 autoload 由插件启用时才注册，项目里没有启用项 | `project.godot` 补 `BeehaveGlobalMetrics` / `BeehaveGlobalDebugger` autoload，并加 `[editor_plugins]` |

### 13.2 验证通过的行为

- **巡逻**：无敌人时在锚点附近随机走动（到点停 0.5~1.5s），敌人出现后标签立刻从「巡逻」切到「突进/防守/放风筝」。
- **索敌与战斗**：单只僵尸在检测到后 3 秒内被击杀；目标距离稳定在策略交战带（突进约 129px）。
- **换枪**：用测试键发全套枪后，CPU 会按距离/策略切到 UZI、Railgun（弹药 100→94、15→7 正常扣减），并保持数秒不抖。
- **躲火球**：恶魔火球进入 176px 且朝向自己时，分支切到 `[dodge]` 并侧向闪避（截图可见 3 条危险物连线与横向位移）。
- **救援**：人类 HP 压到 60/200 后，分支切到 `[rescue]` 并贴近队友；8 秒上限 + 5 秒冷却后回到普通策略。
- **多 CPU**：1 人类 + 3 CPU + 3 僵尸 + 1 恶魔无脚本错误；3 个 CPU 各自策略（突进/防守/放风筝）同时工作。
- **性能**：窗口保持焦点时 0 CPU ≈ 57 FPS、3 CPU ≈ 56 FPS（vsync 60），AI 开销可忽略。

### 13.3 观察到的现象（非 bug）

- 受伤（Hurt）期间行为树停摆，调试标签上的策略/动作名会停在受伤前的值。
- 战斗分支的动作都返回 `SUCCESS` 而不是 `RUNNING`，所以调试标签的 `running_action` 在战斗时显示 `-`（这是刻意的，避免序列被"跟随队友"顶掉）。
- 窗口失焦时 Godot 帧率会掉到个位数，测性能必须先让窗口保持焦点 2~3 秒再看 FPS。
- 救援有 8 秒上限和 5 秒冷却，冷却期内低血队友看起来"没人管"是设计行为。

### 13.4 还没做

- **P4**：`map.gd` 的 CPU 槽位仍走旧 `cpuUpdateAi()`，还没挂 `CpuBrain`。
- CPU 不拾取/开箱；爆炸物只对火箭做爆区检查；"队友旁边的油桶不打"未单独处理（开火射线会被油桶挡住，算半个兜底）。

### 13.5 第二轮走位修复（2026-10-30，未运行验证）

用户反馈"CPU 分不清静态/动态障碍和角色、到处乱走、开枪时乱晃、巡逻太频繁"，对应修改：

1. **移动统一走 `CpuBrain.canStepTo()`**：同时检查
   - 静态障碍格（`MapData.isObstacle`，墙 / 油桶 / 假墙）；
   - 玩家碰撞体（`player.blockedByCell` 的 3×3 采样）；
   - **动态占格** `cellOccupiedByCharacter()`（其他玩家、敌人，按格心 0.75 格判定）；
   - 可玩区域边界（`MapData.getPlayRect`）。
2. **`pathDir()`**：直线可走就直走，否则依次尝试"敌人源距离场方向 → 左右侧移"，每一步都用 `canStepTo` 复检；接近目标时把目标本人从占用判定里排除。
3. **巡逻降频**：从"随机远点 + 0.5~1.5s 停顿"改成"一格一格走 4~7 格 + 停 1.5~3.5s"，只在到点/被挡/方向失效时重选，离锚点 5 格强制回家。
4. **开枪时站定**：`move_to_range` 在距离带内输出零位移（不再 `orthogonal` 横移）；只有"带内但射线被挡"时才侧移找角度；接近/后退都沿瞄准方向直线走。救援分支在 3~5 格内同样站定。
5. 逃跑、归队、去最后位置也全部改用 `canStepTo`，不会往人/墙里走。

### 13.6 第三轮：低血求生 / 按武器交战距离 / 拆物（2026-10-30，未运行验证）

按用户反馈补的三块逻辑：

1. **低血求生**（`should_survive` / `survive`）：血量 < 25% 时优先去捡补给箱（箱子在玩家 ≤ 50% 血时给回血），没有箱子就边后退边开火；同时主策略强制切 KITER。树里的优先级：躲避火球 > 求生 > 救援 > 撤退 > 拆物 > 战斗。
2. **按武器决定交战距离**（`CpuBrain.idealDistance()`）：霰弹 56px、UZI 168、手枪 208、火箭 240、轨道炮 300，策略只做 ×0.85~×1.15 的小幅修正；距离带内站定，不再"一律贴到射程 55%"。
3. **选择性拆物**（`should_demolish` / `demolish`）：墙挡射线就拆墙；油桶挡射线且爆区无自己人才打爆；油桶旁有敌人且爆区无自己人则当炸药打；友伤开启时自己/队友在爆区里坚决不打。
   - 感知 Area2D 的掩码加了 **layer 4（item）**，`scan()` 额外收集范围内的油桶/墙。
   - 新增 `firstHit()` 统一复用武器射线；`shotHitsTarget` / `shotHitsProp` / `propBlocker` 都基于它。
   - 顺带修正：火箭是弹丸武器（`wRange = 0`），原逻辑会让它"贴脸又永远打不到"；新增 `CpuBrain.effectiveRange()`（火箭按 320px）并统一用于交战距离、开火判定、拆物判定。
   - 去捡箱子时用 `pathDirSimple()`（只做直线+侧移，不查敌人距离场），避免"绕路时被距离场带着往敌人跑"。

