# 项目体检问题清单（待逐条确认）

来源：2026-11-03 三路只读核查 —— ①代码里的未完成/临时/桩信号扫描，②文档自认的遗留项与代码逐条比对，
③对照 `F:\scripts` 原版源码的玩法完整度对比。

每条给 **现象 / 证据 / 影响 / 怎么确认**。判定含义：

- `已修` = 本轮已改代码，需要你实机回归
- `待确认` = 我认为是问题，但需要你拍板（是不是有意为之）
- `范围决策` = 与原版的差距，不是 bug，做不做由路线图决定

---

## 1. 本轮已修（需要回归验证）

### 1.1 恶魔寻路实际是失效的 `已修（第一层）` → **第二层仍未修，见 1.1b**
- 现象：恶魔不会绕墙、凹室和窄口会直线撞墙；僵尸正常。
- 原因：`map.gd` 只生产 `flowFieldDict["multi"]`（`computeFieldMulti`），而 `devil.gd::targetId()` 返回 **int** 玩家号，
  `getFlowDir(pos, 1)` 查不到键 → 恒返回 `ZERO` → 走 `freeDirectionTowardsTarget()` 直线贪心。
  僵尸在"多玩家单场"改造时已改成返回 `"multi"`，恶魔漏了。
- 改动：`script/character/devil.gd:94` 返回 `"multi"`。
- 确认方法：开局后看恶魔是否绕开墙体追人；或 `test_devils.tscn` 里把恶魔放在墙两侧观察。

### 1.1b 恶魔缺"可行性过滤" `已修`
- 现象：1.1 修完仍然"前面被挡住不会换方向"。流场正常时它会绕，一旦流场给 `ZERO`
  （所在格是障碍 / 该格不可达 / 场刚清空）或给的方向正好怼墙，就一直顶墙。
- 原因：僵尸那条链有三层保护，恶魔一层都没有：
  | 能力 | 僵尸 | 恶魔（修前） |
  |---|---|---|
  | 方向可行性 `canStep()` | `zombie.gd:271` | **完全没有** |
  | 流场方向被挡时侧移 | `chooseDirTowardsTarget()` → `sidestepDirection()` | 直接用流场原方向 |
  | 贪心回退过滤 + 卡墙脱困 | `freeDirectionTowardsTarget()` 过滤 + `escapeDirection()` | 只取最优点积方向，撞墙不回头 |
- 改动：`script/character/devil.gd` 补 `canStep()` / `sidestepDirection()` / `escapeDirection()`，
  并让 `flowDirection()` 走"可行就用、不可行就侧移"。恶魔的 `canStep` **只查地形障碍格**，
  不查同类占格（僵尸那版会查）：恶魔体型大、又会拆障碍，把同类当墙会在窄口集体卡死。
- 确认方法：`test_devils.tscn` 里把恶魔放在墙的另一侧，观察它会绕/侧移而不是贴墙；
  实测同点位（恶魔格 (10,8)、朝玩家方向 (-1,0) 是墙）：修前照走撞墙，修后改选 `(0.71,0.71)` 并真的移动。

### 1.2 复活不再清空武器 `已修`
- 现象（改前）：死亡复活后背包只剩手枪，辛苦开的 UZI/霰弹/火箭全没。
- 原版：`CThing_Creature_Player.as:321-327 ResetWeapons()` 只对非手枪调 `EmptyWeapon()`
  （`CThing_Weapon.as:115-118`：`mAmmo = mTotalAmmo != mInfinateAmmo ? 0 : mTotalAmmo`），**武器保留**，再 `SelectWeapon("pistol")`。
- 改动：`script/character/player.gd` 新增 `resetWeaponsOnRespawn()`，`resurrection()` 改调它（除手枪与无限弹药外弹药清零、切回手枪、保留列表）。
- 确认方法：开局开箱拿一把 UZI → 故意送死 → 复活后按切枪键应还在，且弹药为 0。

### 1.3 高难度开局补发升级与解锁枪 `已修`
- 现象（改前）：选 Expert/Nightmare 只把 `currKillStreak` 设成 29/49，**不发任何升级**，与 Beginner 开局装备完全一样。
- 原版：`CUpgrades.SetDifficulty:90-133` 逐级 `mMultiplier += 1`，setter（`:567-586`）把经过档位的升级全部 `AddUpgrade`；
  `AddUpgrade:134-152` 对**每个在场玩家**调 `NewWeapon(枪名)` → 解锁的枪直接进背包，不等开箱。
- 改动：
  - `autoload/mapData.gd`：新增 `grantUpgradesToStreak()`（逐档 `countKillStreak()`，幂等）、`silentNotices`（原版 `mSilentMessages` 的等价物，开局补发不刷 HUD）；
    `unlockWeapon()` 现在会给在场玩家 `giveWeapon()`。
  - `script/character/player.gd`：新增 `weaponSceneName()` / `giveWeapon()`；`initWeapon()` 在生成手枪后补发 `MapData.weaponUnlock` 里的枪（覆盖"开局前解锁"的情况）。
  - `script/map.gd::applyDifficulty()`：`MapData.currKillStreak = startMult` 改为 `MapData.grantUpgradesToStreak(startMult)`。
- 确认方法：难度选 INTERMEDIATE（倍率 9）开局，按切枪应能立刻切到解锁的枪，HUD 升级列表（`upgrade_list.gd`）应有对应项；
  且开局不应刷一屏"解锁提示"。

### 1.4 新局进度未重置（实现 1.3 时发现的泄漏）`已修`
- 现象（改前）：`MapData` 是 autoload，`score / currKillStreak / killStreak / weaponUnlock / weaponUpgrades`
  跨场景存活，`resetAllWeaponData()` 只在 `mapData._ready` 调过一次 → 回菜单再开一局会带着上一局的解锁与升级。
  叠加 1.3 后危害变大：跑过一次 Nightmare，之后所有局都白送 49 档升级。
- 改动：`mapData.gd` 新增 `resetRunProgress()`，`map.gd::_ready()` 开头调用。
- 确认方法：打一局拿几次升级 → 回主菜单 → 再开一局，开局背包应只有手枪、升级列表为空。

### 1.5 玩家/贴花遍历缺有效性判断（5 处）`已修`
- 证据与改动：
  - `map.gd::playerDead()`、`_on_resurrection_timer_timeout()`（含 `awaitingResurrectionPlayer` 里的旧引用）、`pickRespawnPos()`
    —— 组里可能还挂着本帧已 `queue_free` 的玩家，直接取 `isDead` 会崩；已加 `is_instance_valid`。
  - `game_camera.gd::refreshTarget()` —— 兜底 `ps[0]` 可能是已释放/死亡玩家；改为只取有效节点，取不到则 `target = null`
    （`_physics_process` 已有 `target == null` 分支，安全）。
  - `mapData.gd::addDecal()` —— 换房时旧贴花层还在组里，已加判空。
- 确认方法：4 人局连续死亡/复活 + 中途换房，观察是否还有 `previously freed` 报错。

### 1.6 新增：暂停菜单可返回主菜单 `已实现`
- `script/ui/pause_layer.gd`：暂停时除遮罩/文字外，多了「继续游戏 / 返回主菜单」两个按钮（代码里建控件，沿用项目主题，暂停瞬间把焦点给"继续"）。
- 关键处理：**返回主菜单前必须先 `setPaused(false)`** —— `get_tree().paused` 是全局的，带着暂停态换场景，新场景一进场就是冻住的。
- 文案进 `lang/lang.csv`：`Resume` → 继续游戏、`Main Menu` → 返回主菜单。

### 1.7 新增：TestBridge 补给刷新诊断 `已实现`
- `autoload/test_bridge.gd::refreshMetrics()`，快照里多一个 `refresh` 字段：
  `points`（刷新点数量）、`blocked`（当前被判占用的点数）、`timerLeft` / `waitTime`（定时器剩余与周期）。
- 导出版没有控制台，这个字段就是用来在 exe 里判断"定时器没跑 / 点全被判占用 / 刷新点为空"三种情况到底命中哪一种（见 §9）。

### 1.8 「碰撞」开关（collision）已接通原版语义 `已实现`

原版调查结论（`F:\scripts`）：

| 事实 | 出处 |
|---|---|
| 开关是存档项 `mCollisionsActive`，默认 1（开） | `CSaveData.as:32,139-146`；选项按钮 `CScreen_SelectWorld.as:235-236` |
| **只有玩家这一侧**受开关控制：`PlayerCollide` 里"把自己从可碰撞体推出去"那步包在 `if (mCollisionsActive)` | `CMap_Collide.as:44-63` |
| 静态墙**不受开关影响**：进入前先查 `mCollide_StaticImpassable`，之后 `Collide_Map` 无条件执行 | `CMap_Collide.as:45-47,60-62,120-140` |
| 敌人不受开关影响：`CreatureCollide` 里 `Collide_Mapwho` 是无条件调用的 | `CMap_Collide.as:66-88` |
| 哪些东西算"可碰撞体"（`mFlag_Collidable`）：所有生物（玩家/僵尸/恶魔）+ 油桶 + 玩家喷的墙 | `CThing_Creature.as:47,183`、`CThing_Object_Barrel.as:66,81`、`CThing_Object_Wall.as:64,79,125` |
| 出生/复活瞬间生物会临时摘掉该标志（`mFlag_Collidable` 被 `&=~`），死亡时也会 | `CThing_Creature.as:158,357` |

**所以原版行为是**：关掉 Collisions 后，玩家可以穿过**其他玩家、僵尸、恶魔、油桶、玩家喷的墙**（它们全都在同一个 `Collide_Mapwho` 里，被同一个开关一起关掉），但**静态墙照样挡**；而且这是**单向**的 —— 敌人自己那边仍然做推开解算，所以敌人不会叠在玩家身上，玩家却能径直穿过敌人。

重制版的实现（默认开，关掉才生效；开=完全保持现状）：

- `mapData.gd::collisionOn()`（对齐 `friendlyFireOn()` 的写法）。
- `player.gd::applyCollisionSetting()`（`_ready` 里调一次，与原版"进图读一次"一致）：
  开 → `collision_mask = 1+2+4+8`、`shapeQuery.collision_mask = 1+2+4`；
  关 → 只留 `8`（staticWall），`shapeQuery` 掩码置 0（`intersect_shape` 返回空 → `resolveAreaBlockers` 不再推开）。
- `player.gd::blockedByCell()`：关碰撞时跳过"物体类"障碍格。为此 `mapData.gd` 新增 `itemCells` / `isItemCell()`，
  `addObstacleAt(cell, fromItem)` 标记来源 —— 预摆油桶/墙（`room_generic.gd:192`）与玩家放置的油桶/墙
  （`barrel.gd:47`、`wall.gd:36`）都标成 `true`，静态墙（`room_generic.gd:167`）不标。
  僵尸/恶魔的流场仍然把这些格当障碍（与原版 `CreatureCollide` 不看开关一致）。
- `cpu_brain.gd::canStepTo()`：去掉直接查 `isObstacle` 的那行，改为只用 `player.blockedByCell()`，
  否则 CPU 关碰撞后仍然"不敢"走油桶那格（身体其实能过）。

**待实机确认**：关掉 Collisions 后，玩家应能走过队友、敌人、油桶和自己喷的墙，但**走不进静态墙**；
敌人依旧会绕开玩家身体、且仍把油桶/墙当路障。

### 1.1c 恶魔的碰撞层配错，物理上能穿墙 `已修`
- 现象：1.1b 之后仍然"被挡住不会改变方向"。
- 原因：`scene/character/devil.tscn` 的根节点没写 `collision_layer / collision_mask`，继承了
  `character.tscn` 的 `mask = 3`（玩家+敌人），而僵尸是 `layer 2 / mask 11`（多带了 `8 = staticWall`）。
  于是恶魔**既不跟静态墙碰撞，也不跟油桶/物品碰撞**，还挂在玩家层（layer 1）上。
  结果：格子级的 `canStep` 说"不能进"，身体却直接穿进墙格；一旦站在障碍格里，
  `flowDirection()` 就退化成贪心，看起来就是"贴着墙不换方向"。
- 改动：`devil.tscn` 根节点补 `collision_layer = 2`、`collision_mask = 11`（与僵尸一致）。
- 确认方法：把恶魔放在墙前一直朝墙走，中心应停在墙格外（实测墙格 (8,2)，恶魔停在 x=242，格 (7,3)，未进墙）；
  再抽查 8 个点位，2 秒内都能满速移动且不进障碍格。
- 残留：个别点位（room_0003 格 (25,20)）2 秒只走 17.6px，属于**圆形碰撞体贴墙角**导致
  "格子判定可走、身体实际被蹭停"。要彻底消掉需要加"按实际位移判卡墙"的机制（僵尸靠逐格承诺规避了这点），
  实机若仍能看出贴墙磨蹭再做。

### 1.1d 爆炸图被自己的焦痕盖住 `已修`
- 原因：`explosion` 没设 `z_index`（默认 0），而贴花层是 `z_index = 2`、角色/墙按 y 排到几十到上千，
  所以爆炸闪光被压在焦痕和所有东西下面。
- 改动：`mapData.gd` 新增 `FX_Z = 4096`（高于 `worldZ` 的 ±4000 上限），`explosion.gd::_ready()` 开头设 `z_index = MapData.FX_Z`。
- 同类未动：`smoke.tscn` 的 `z_index = 10`、`fireball.gd` 的 `z_index = 200` 也低于角色（按 y 排到几百），
  烟雾/火球在地图下半部分会被角色和墙盖住。要不要一起抬到 `FX_Z` 待定。

### 1.9 单人死亡后僵尸原地摇摆 `已修`
- 现象（改前）：只有一个玩家时玩家死亡，僵尸在原地来回抖；恶魔不会。多人里死一个不受影响
  （活着的玩家还在，僵尸会转追别人）。
- 原因：`zombie_chase.gd` 无目标分支走 `wanderFallback()` → `zombie.gd::wanderDir()`
  是**每帧**从可走方向里 `randi()` 挑一个，方向每帧重掷 → 视觉抖动。
  恶魔的 `devil_chase.gd:21-24` 无目标直接 `velocity = ZERO` + `stand`，所以不抖。
- 改动：僵尸与恶魔统一成"无存活目标 → 站住"，删掉 `wanderFallback()` / `wanderDir()`
  （以及没有调用方的 `inNavBounds()`）。被墙围住/卡在障碍格的脱困不依赖它，走
  `escapeDirection()`。口径与依据写在 `doc/01-enemy-ai.md` §3.1。
- 与原版的差别：原版会把尸体当目标继续走（`CThing_Collection.as:95-102`、`:120`），
  但目标格被 `mCollide_Player` 永久占着，实际是在尸体边反复 Attack 落空 / Wait；
  且原版 `PlayerDead` 同帧就切结算场景（`CWorld.as:665`）。重制版全灭后有 **5 秒**才进
  `gameover.tscn`（`map.gd::playerDead`），抖动会被看清，所以选择站住。
- 确认方法：单人开局打死一只僵尸→自己送死→5 秒内僵尸应站住不再抖；多人（≥2 人）死一个，
  僵尸应立刻改追活着的队友。

---

## 2. 待确认：设置与开关

| # | 问题 | 证据 | 需要你确认 |
|---|---|---|---|
| 2.1 | ~~`collision`（玩家互撞）是死配置~~ → **已接通**，见 §1.8（原版语义：只关玩家那一侧的推开，静态墙照旧挡，敌人不受影响） | 实现：`mapData.gd:418-426`、`player.gd:690-696/611-625`、`cpu_brain.gd:457-465` | 仍需实机确认密度观感：关掉后玩家可以穿过敌人，可能显得"怪黏在身上" |
| 2.2 | `gameSpeed` 同样是死配置 | `mapData.gd:223,869` 有键，无任何读取者 | 同上 |
| 2.3 | `friendlyFire` 默认值三处自相矛盾：`mapConfig` 初值 `true`、`friendlyFireOn()` 兜底 `false`、函数注释写"默认关闭" | `mapData.gd:223` vs `:389` 注释 vs `:411-412` | 默认为什么？现在实际生效的是 `true`（开友伤） |
| 2.4 | 血迹开关"关"只拦新贴花，**已有血迹不清空**；"恢复默认"漏 `blood`/`screenShake`；`resetMapConfig()` 无调用者 | `script/fx/decal_layer.gd:86 clearAll()` 零调用；`game_setting_panel.gd:209-215`；`mapData.gd:821` | 关开关是否应该立刻清空？（decals 文档 §开关 写的是"立即清空"） |
| 2.5 | **`hasBlock()` 的碰撞判定是失效的**：标志点 Area2D 的 `collision_layer = 0`、`collision_mask = 0`，`has_overlapping_areas()/has_overlapping_bodies()` 恒为 false，只剩"24px 内有敌人"这条兜底 | `scene/level/map_sign.tscn:52-53`；消费方 `map.gd:322`（刷怪点占用判定）、`map.gd:598`（补给刷新）、`test_flow_field.gd:148` | 结果：箱子会在同一个点**重复堆叠**、刷怪点占用判定退化。要不要把 mask 设成 `1`(player) + `64`(box)？改了以后刷怪/刷箱都会变严格，需要实机看密度 |

---

## 3. 待确认：表现与素材

| # | 问题 | 证据 | 需要你确认 |
|---|---|---|---|
| 3.1 | 贴花挂点不全 → **玩家血迹已补**；墙碎**决定不画焦痕** | 实现：`player.gd:560`（受击/致命各一摊）、`player.gd:1160-1166`（击退滑行按 25Hz 滴血，爆炸来源不滴，对齐 `CThing_Creature.as:308/332-335/378`）；对照表见 `doc/decals-blood-scorch.md §2.3` | ⚠️ 提醒：**原版墙被打碎是会画焦痕的**（`CThing_Object_Wall.as:129`），而油桶的焦痕是间接来自爆炸特效（`CThing_Effect_Explosion.as:86`，所以火箭/手雷/地雷同样会留）。当前重制版只有爆炸留焦痕、墙碎不留 —— 按你的决定保留，属于有意偏离原版 |
| 3.2 | ~~手持武器枪口锚点 `offsetDir` 未落地~~ → **已实现**：五把枪各自脚本里写死 8 方向值，已按 `muzzles.json` 逐方向核对（±1px 内） | `script/weapon/hand_gun.gd:23-30`、`uzi.gd`、`shotgun.gd`、`rocket.gd`、`railgun.gd`；规格与换算见 `doc/xsi-sprite-skins.md §8` | 无遗留（曳光/出膛视觉仍需实机看一眼） |
| 3.3 | 玩家/僵尸/恶魔素材替换**只做了静态校验，没实机跑过**：锚点、8 方向映射、恶魔比旧素材高约 5~7px、僵尸地面线偏差 ≤1px | `doc/xsi-sprite-skins.md` §4/§7；离线合成图比对结论 | 实机确认朝向与落地位置（尤其 2P/CPU 与恶魔体型观感） |
| 3.4 | 旧素材仍在仓库且已无引用：`sprite/player/DefineSprite_*`、`sprite/Zombie2`(200 张)、`sprite/Devil`(184 张) | 全项目 grep `sprite/Zombie2` / `sprite/Devil` / `sprite/player/DefineSprite` = 0 | 确认后删除？（git 里有历史，可恢复） |

---

## 4. 待确认：CPU AI

| # | 问题 | 证据 | 需要你确认 |
|---|---|---|---|
| 4.1 | 临时 AI 与 CpuBrain **双轨并存**：`cpuBrain == null` 时退回 `cpuUpdateAi()`，行为不一致且出问题难排查（长跑里"CPU 站着挨打"就是这条路径） | `player.gd:793` 兜底、`player.gd:891+ cpuUpdateAi()`；cpu-player-ai.md P4 明确要删 | 删临时 AI，还是保留兜底并在挂载失败时 `push_error` 报警？ |
| 4.2 | 长跑偶发**波次卡住**（分数冻结、剩 1~2 个敌人）：①恶魔受击盒中心压进顶部墙带（hp 220/237 卡在 y≈65）②CPU 被队友挡死且不会绕行 | doc/test-checklist.md §已知偏差；5 分钟长跑采样记录 | 是否按之前提的两条修（敌人出生/移动时把受击盒中心夹出墙格；被挡时让 CpuBrain 换位） |
| 4.3 | 文档引用的验证资产不存在：`tools/qa/qa_flee.tscn`、`tools/_cpu_solo_test`、`qa_runner` | cpu-player-ai.md §13 | 是删掉文档里的这段，还是补回工具？ |

---

## 5. 范围决策：与原版的玩法差距

| # | 差距 | 原版证据 | 重制现状 | 备注 |
|---|---|---|---|---|
| 5.1 | ~~补给箱掉落**节奏**慢很多~~ → **已修**，按原版补了独立的连击计数器 | 原版**两个计数器**：`CUpgrades.LogKills:513-521` 里 `mMultipleKill` 与 `mMultiplier` 同时 +1，但衰减不同（`:81-88`）——`mMultipleKillsTick = GetTicks/6`（`:546`，约 0.45s）**到点直接归零**，`mMultiplierTick`（`:570`）才是慢速 `-1`；掉箱判的是快的那个：`CWorld.LogKill:620` `mMultipleKill % 5 == 0`，恶魔 `:627` 无条件掉；箱子寿命 `CWorld._CreatePickup:647` = `FPS*10` = **10s** | 现实现：`MapData.comboKills`（≡`mMultipleKill`）+ `MapData.killRewardBox = 5`，`map.gd::restartComboDecay()/onComboDecayTimeout()` 负责 1/6 窗口归零，`enemyKilled()` 判 `comboKills % 5`；`spawnRewardBox` 寿命 15→10s。`currKillStreak` 仍只当倍率（显示/分数/升级）用 | 之前是拿慢衰减的 `currKillStreak % 30` 判，等于要连杀 30 才掉一个，比原版稀有得多。⚠️ 未实机验证：连杀 5 只的窗口很短（约 0.45s/只），实际掉箱频率需要打一局看 |
| 5.2 | ~~箱内物品**权重**不同~~ → **已修**，改成原版的加权抽签 | 原版 `CThing_Creature_Player.RandomPickup:355-397` | 现实现 `script/item/box.gd::rollContent()/ammoWeight()`：每把已解锁非手枪武器权重 `(1-当前弹/上限)×0.75+0.25`，回血权重 `(1-hp/maxHp)×武器权重和` | ⚠️ 原版的推论：**一把武器都没解锁时开箱什么都不给**（回血权重乘的是武器权重总和，总和为 0）。已按原版保留；想改成"新手期开箱必给血"只需把 life 项换成固定权重。自造的 `healThreshold` 已删除 |
| 5.3 | ~~无 DeathMatch / 模式选择 / 胜者结算 / HighScore 提交~~ → **明确不做**（超出本项目范围） | 原版 `CScreen_Main.as:38-40`、`CWorld.mGameMode`、`CScreen_Debrief_Winner` | 只有合作流程，按决定不再补 | 将来若要做：`MapData.resetRunProgress()` 与 `playerSlots` 都要按模式分支 |
| 5.4 | 结算与暂停信息量低（暂停已补"继续 / 返回主菜单"，其余仍缺） | 原版 `CScreen_Debrief.as:34-96`、`CHud.Pause:63-108` | `gameover.gd:11-16` 只显示总分；`pause_layer.gd` 现有两个按钮，但无升级列表 | 缺等级/击杀/死亡/存活时间/升级列表 |
| 5.5 | HUD 无连杀倍率衰减圆环 | `CHud.as:159 mcScoreTotal.mcTimer` | 无 | 玩家看不出倍率什么时候掉 |
| 5.6 | 武器/升级/物体缺项 | `CThing_Weapon_Devastator`、`CThing_Shot_Devastator`、`CThing_Effect_SmartBomb`、`CUpgrades:212-215 FatalDamage×10`、`:269-272 HomingMissiles`、`CThing_Object_LaserNode` | 未实现 | 原版玩家实际也拿不到 Devastator/SmartBomb，优先级低 |
| 5.7 | 火球撞墙行为存疑 | `CThing_Shot_FireBall.as:58` 只建 AffectArea，未确认 `Collide_Map` 是否爆炸/推人 | `fireball.gd:85-88` 撞墙直接 `queue_free`，注释称"原版就是消失" | future-improvements.md:312-321 却写"应爆炸+推人" —— **文档与代码注释互相矛盾，需核对原版** |
| 5.8 | BigBang 子爆炸简化 | `CThing_Effect_Explosion` 分级 | `explosion.gd:119` 简化为 4 个偏移延迟爆炸 | 已知偏差，视觉可接受则不动 |
| 5.9 | 逻辑步长仍是 60Hz | 原版 25 tick/s 逻辑 + 50 enterFrame | `project.godot` 无 `[physics]` 段 | 数值靠换算对齐；低帧率下与原版不同 |
| 5.10 | 空桩与占位 | — | `map.gd:384 loadLevel()`、`mapData.gd:443 clearMapTile()` 是 `pass`；`information_panel.gd:5` 未实现；`devil_track_target.gd:6` 是保留未接入的占位状态 | 要么接上要么删，避免误以为生效 |

---

## 6. 工程卫生（低风险，顺手可清）

1. `print` 调试残留：`map.gd:238,297,486,718`、`room_generic.gd:202,216,226`；`script/main.gd:11` 打印系统语言。
2. `scene/main.tscn` + `script/main.gd` 是调试场景，主场景是 `welcome.tscn`，无人引用 → 死资产。
3. `scene/map.tscn` 里 `ui/Button`（`visible = false`，text "test"）连着 `map.gd:_on_button_pressed()`，函数体是 `toastInfo.display('11111111111', RED)` → 测试残留。
4. `player.gd::pickItem()` 十段几乎相同的"实例化武器 + 抄数值"代码；其中 railgun 用 `get_rid()` 作 `ownerId`，其余用 `body.get_rid()` → 自机排除口径不一致，可能让火箭筒/地雷等对自身的排除失效（**值得单独确认**）。现在已有 `giveWeapon()` 可复用，pickItem 可收敛。
5. `.gitignore:31 /doc/tools` 把核查/生成脚本全排除在外（`gen_player_skins.py`、`gen_creature_skins.py`、`check_naming.py`、`check_callback_naming.py`、`fix_naming.py`、`run_bridge_tests.py`）→ 想留档要 `git add -f`。
6. `box-head-remake/.vscode/` 未忽略，会污染 `git status`。
7. `map.gd:709` 写死 `room.name = "room001"`，换房后名字与实际房间不符。

---

## 7. 文档陈旧（2026-11-03 已按当前功能更新）

| 文档位置 | 原不符点 | 状态 |
|---|---|---|
| cpu-player-ai.md §11 阶段表 | 写"P4 挂 CpuBrain 待做"，实际 `map.gd:171-175` 已挂 | **已改**：标成"部分完成"，并写明临时 AI 兜底仍在（指向 §4.1） |
| cpu-player-ai.md §8.2 树结构 | 缺 `pickup / place / investigate` 三条分支 | **已改**：按 `cpu_brain.gd::buildTree()` 重写 |
| cpu-player-ai.md §8.3 叶子清单 | 缺 6 个叶子 | **已改**：补 `should_pickup / pickup / should_place / place_weapon / has_noise / investigate` |
| cpu-player-ai.md §13 测试记录 | 引用未入库的 `tools/qa/qa_*`、`tools/_cpu_solo_test` | **已改**：开头加说明——那些是一次性测试壳、没入库、数字不能复现；可复现入口是 `test_cpu.tscn` 与 `doc/tools/run_bridge_tests.py` |
| test-checklist.md §1 命令表 | 端口写 8765；`step / select_strategy` 文档有、代码没有 | **已改**：端口改 28765（可 `--test-bridge-port=` 覆盖），两条未实现命令标 ⚠️，并补齐 `grant_weapons / teleport / god` |
| test-checklist.md §1 快照字段 | 列了 `mode/processMs/physicsMs/avgSpeed/dirFlipPerSec/items[]` 等没实现的字段 | **已改**：换成 `buildSnapshot()` 真实字段，并新增本轮的 `refresh{points,blocked,timerLeft,waitTime}` |
| test-checklist.md §4 已知偏差 | "霰弹 4 发 / 恶魔 mass 1.0 / hitFeedback 未实现" | **已改**：3/5/5 已对齐原版、恶魔 mass 5.0、击退回伤害×质量；并补了补给权重与碰撞开关两条 |
| map_select.gd:181 注释 | 说"角色只影响界面展示"，实际驱动皮肤 | **已改**：注释指向 `xsi-sprite-skins.md §5` 与撞角色才染色的规则 |
| xsi-sprite-skins.md §8 | 数据源目录名写错；把已实现的枪口锚点写成待办 | **已改**：目录名更正为 `run-2026-11-03015429-player-body-game-s2`，状态改"已实现（5 把枪 × 8 方向与 muzzles.json 比对 ±1px）"，校验改为直接比对表（`check_muzzle_overlay.py` 标注为未创建的可选工具） |
| decals-blood-scorch.md §开关 | "关=立即清空"未实现 | **未改**：这仍是待确认项（见 §2.4），要么实现 `clearAll()` 调用，要么改文档措辞 |
| future-improvements.md §流场 | 第 1 步"数组化"等仍未做 | **保留**：那是优化提案，不是陈旧描述 |

---

## 8. 建议的确认顺序

1. 实机跑 `test_cpu.tscn` + 一局 INTERMEDIATE：看恶魔绕墙、开局武器/升级、复活背包、HUD 通知是否安静。
2. 打一局 → 回菜单 → 再开一局：验证 1.4 的进度重置。
3. 5 分钟长跑（`--time-scale 3`）：复现/确认 4.2 的卡波是否还在。
4. 逐条勾选 §2~§7：把"其实是有意为之"的划掉，剩下的再排优先级。

---

## 9. 导出 exe 后"补给箱不刷新"（排查中，需要你用 exe 采一次数据）

现象：编辑器里正常，导出的 exe 开局后补给箱不再刷新。

### 已经排除的（静态可查，都没问题）
- **路径大小写**：`.pck` 区分大小写而 Windows 文件系统不区分，是"编辑器正常、exe 加载失败"的头号原因。
  已写检查工具 `python doc/tools/check_res_paths.py`，全项目扫描结果：**0 处大小写不一致**
  （剩下 5 条是格式串/命令行文档造成的误报，如 `res://scene/level/room_%04d.tscn`）。
- **目录枚举**：全项目没有用 `DirAccess` 读资源目录（只有 `test_devils.gd` 建调试输出目录），
  不存在"pck 里列不出散文件"的问题。
- **空弹药池崩溃**：`box.gd::rollContent()` 在 `weaponUnlock` 为空时返回 `Life`，不会越界。
- **刷新代码不是新加的**：`_on_refresh_timer_timeout` 早在 2026-07-15（`3104d4e`）就有，
  所以不是"exe 是旧版"以外能解释的 —— 但**仍建议确认你的导出时间**，
  如果导出的是皮肤替换（11-02 深夜）之前的版本，画面差异会与这次改动混在一起。

### 刷新链路（供对照）
`map.gd:142 itemSpawnPoint = room.itemSpawnPoint` → `:143-144 refreshTimer.wait_time=20; start()`
→ `map.tscn:536` 连接 → `map.gd:595 _on_refresh_timer_timeout()` → 对每个 `Box` 型标志点
`if not hasBlock(): box.instantiate() 加到 get_tree().current_scene`。

### 需要你采一次数据（不用控制台，用现成的 TestBridge）
导出的 exe 支持带参数启动（`OS.get_cmdline_user_args()`）：

```powershell
# 1) 用调试参数启动导出的 exe（注意 -- 分隔符）
your_game.exe -- --test-bridge --test-bridge-port=28765

# 2) 另开一个终端连上去，每 5 秒取一次快照，重点看两个字段
#    boxCount  : 场上箱子数
#    refresh   : {points, blocked, timerLeft, waitTime}   ← 本轮新加的诊断字段
```

三种可能的结论：

| 观察到的值 | 判定 |
|---|---|
| `timerLeft` 一直不变 / 从不归零 | 定时器没跑（`refreshTimer` 未启动或被暂停态卡住）→ 查 `map.gd:143` 是否执行到 |
| `points = 0` | 房间里的 `Box` 型标志点没被收集（`room_generic.gd:34-45` 的 `find_children` + group 判定在导出环境失效）→ 需要看那张房间场景 |
| `blocked == points` 且 `boxCount` 不增 | 刷新点全被判"占用"。注意 §2.5：`hasBlock()` 的碰撞判定其实是坏的，只剩"24px 内有敌人"这条兜底 —— 敌人长期在箱子点上转就会一直拦刷新 |
| `boxCount` 在涨但你看不见 | 箱子生成在看不见的地方（父节点/坐标口径问题：初始箱由 `room_generic.spawnBoxes()` 挂到房间、用 `position`；刷新箱挂到 `current_scene`、用 `global_position`）→ 两条路径要统一 |

把这几个数字发我，就能定位到具体是哪一种，不用靠猜。

