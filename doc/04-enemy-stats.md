# 04 · 敌人数值、玩家数值、关卡与难度曲线

> **逆向对象**：`E:\boxHead-remake\oldGame\Boxhead_2Play.swf`
> Flash 8 / AS2 / 640×480 / 63 帧 / SWF 帧率 50fps
> 产品串 `Boxhead: 2Play Rooms: Final.1.00110 (16/05/2007 22:37)`，© Sean Cooper 2007
>
> **取证来源（本文件中的相对路径都相对以下根目录）**
> - 主：`oldGame\_decompiled\Boxhead_2Play\linearized\`（下文裸写的 `__Packages/...:行号` 均指此处）
> - **成员名还原版**：`oldGame\_decompiled\Boxhead_2Play\resolved\`
>   —— 常量池还原后的树，**行号与 `linearized\` 逐行完全对齐**（已核对 11 个文件，行数全部一致）。
>   两者引用同一行号即可：`linearized\` 里同一行显示 `this[§§constant(44)] = 100;`，
>   `resolved\` 里显示 `this[mScore] = 100;`。
>   本文档的引用一律写 `linearized\` 的相对路径，凡标注「**常量池恢复**」的结论都表示
>   `resolved\` 树在同一行给出了真实成员名（读者可自行打开该树查看名字）。
> - 旁证：`oldGame\_decompiled\MoreRooms\linearized\`，引用时一律加前缀 `[MoreRooms] `
> - 少数关键结论回到未线性化原文核对（**原始反编译树**）：
>   `oldGame\_decompiled\Boxhead_2Play\scripts\scripts\` 与 `oldGame\_decompiled\MoreRooms\scripts\scripts\`。
>   这两棵树**不属于**上面两个 `linearized\` 根，因此文中引用它们时一律写成「`路径` 第 N-M 行」而不是 `路径:N`，
>   以免与 linearized 的行号混淆（同一份字节码在两棵树里的行号不同）。
> - 表格里为了让列窄一些，同一小节内会复用裸文件名简写，例如 `...CThing_Creature_Player.as:177`
>   指的是本小节上文已给出的完整路径（这里是 `__Packages/Thing/Creature/CThing_Creature_Player.as:177`）；
>   每个 basename 在各自的根目录内唯一，不会歧义。
>
> **可信度标注约定**
> - 「**事实**」= 该数值/公式在**未加密或已线性化可读**的字节码里直接读到，行号可复核。
> - 「**常量池恢复**」= 数值本来就明文，成员名由 `resolved\` 树还原后确证；等同于事实，但注明名字是后补的。
> - 「**推断**」= 从结构位置、调用形态、数值一致性推出的结论，未经运行时验证。
> - 「**未恢复**」= 成员名或数值被字符串加密，读不出来。会写明尝试过的路径。
>
> **加密情况（决定本文档能写多细）**
> 混淆器把成员名换成常量池引用（线性化产物里表现为 `§§constant(N)`），把字符串换成乱码（`{invalid_utf8=..}`）。
> 本次逐文件统计（`§§constant(` + `invalid_utf8=` 记号数，0 = 真正干净）：
>
> | 文件 | 2Play 行数/记号数 | MoreRooms 行数/记号数 |
> |---|---|---|
> | `World/CUpgrades.as` | **669 / 0（干净）** | 671 / 1103 |
> | `Thing/Creature/CThing_Creature_Devil.as` | **228 / 0（干净）** | 209 / 365 |
> | `Thing/Object/CThing_Object_Pickup.as` | **111 / 0（干净）** | — |
> | `CSaveData.as` | 481 / 808 | **134 / 0（干净）** |
> | `Thing/Creature/CThing_Creature.as` | 488 / 709 | 793 / 990 |
> | `Thing/Creature/CThing_Creature_Zombie.as` | 134 / 286 | 1315 / 535 |
> | `Thing/Creature/CThing_Creature_Player.as` | 495 / 899 | 625 / 335 |
> | `World/Init/CWorld_Init_Zombie.as` | 23 / 13 | 1872 / 2122 |
> | `World/CHud.as` | 505 / 953 | 954 / 810 |
> | `CMain.as` | 370 / 460 | 264 / 13 |
>
> **结论提前说**：僵尸的**全套数值现已确证**（血量 100 / 速度 0.02 / 伤害 50 / 记分 100 / 身高 1.5 / 半径 0.45，
> 全部是「常量池恢复」级别的事实）。仅 `CSaveData` 的约 30 个属性名与默认值、
> 以及少数静态槽位名（如 2Play `CMain.mFPS` 的槽位）仍是未恢复项（见 §13.2）。
> 恶魔的全套数值、玩家的大部分数值、1..100 级曲线、难度、升级掉落表、计时公式**都是确凿事实**。
> 需要「照着写 Godot 代码」时，第 2、3、4 章的数值表都可以直接照抄。

---

## 1. 全局常量与时间基准

| 项 | 值 | 出处 | 可信度 |
|---|---|---|---|
| 逻辑帧率 `CMain.mFPS` | **25** | `[MoreRooms] __Packages/CMain.as:188`（`}.mFPS = 25;`） | 事实（MoreRooms 可读；2Play 同位置只有 `= 25`，见下） |
| 每帧最多推进几个逻辑帧 `mFrameCap` | **1** | `[MoreRooms] __Packages/CMain.as:190` | 事实 |
| 单帧逻辑模式 `mSingleFrame` | `false` | `[MoreRooms] __Packages/CMain.as:189` | 事实 |
| SWF 自身帧率 | 50 fps | SWF 头（`get_swf_metadata`） | 事实 |

**2Play 侧的对应证据**：2Play 的 `CMain.as` 被字符串加密，函数名不可读，但在与 MoreRooms **完全相同的结构位置**上出现了两个 `= 25` 的静态量：
`__Packages/CMain.as:288`（`}[§§constant(34)] = 25;`）与 `__Packages/CMain.as:314`（`}[§§constant(44)] = 25;`），
紧随其后 `__Packages/CMain.as:315-316` 是 `[§§constant(119)] = false;` 与 `[§§constant(123)] = 1;`——
正好对应 MoreRooms 的 `mSingleFrame = false` / `mFrameCap = 1`。
再加上 2Play 的 `CUpgrades.as`（干净）里大量使用 `CMain.mFPS`（`:370/373/395`）且数值与 MoreRooms 曲线互证，
因此 **2Play 的 `mFPS` 也是 25**。（推断，置信度很高）

### 1.1 tick ↔ 秒 的换算（本文件所有「秒」都由此而来）

`CMain.ProcessFrames(tFrameRate)` 的定义见 `[MoreRooms] __Packages/CMain.as:140-157`（可读）：
`:147` `var _loc3_ = 1000 / tFrameRate;` → `:149` 用 `getTimer()` 差值除以它算出积累了**几个**逻辑步 →
`:153` 封顶到 `this[§§constant(85)]`（即 `mFrameCap = 1`）。
调用方每帧只按返回值循环这么多次：`[MoreRooms] __Packages/CMain.as:27-44`（`:31` `var _loc4_ = this.ProcessFrames(CMain.mFPS);`）。
所以逻辑步的节拍是 **1000 / 25 = 40 ms**：

> **1 tick = 1/25 s = 0.04 s**  ⇔  **1 秒 = 25 tick**

注意：SWF 是 50fps、每帧最多跑 1 个逻辑步 —— 也就是说**游戏逻辑的设计速度是 25Hz，一个 SWF 帧最多推进 40ms**。
低帧机器上游戏会整体变慢（不是掉帧，是慢动作）。重制版建议固定 25Hz 逻辑 tick（`Engine.physics_ticks_per_second = 25`）。

---

## 2. 玩家数值

`CThing_Creature_Player.as` 的线性化版本被加密（899 记号），但 `resolved\` 树把成员名全部还原了，
`Process_Init` 的字面量也齐全，因此下面的数值**全部是事实**。

### 2.1 基础属性

| 属性 | 值 | 出处 | 可信度 |
|---|---|---|---|
| `mMaxLife` = `mLife` | **200** | `__Packages/Thing/Creature/CThing_Creature_Player.as:180`<br>交叉验证：`[MoreRooms] ...CThing_Creature_Player.as:560` | 事实 |
| `mSpeed` | **0.16 格/tick**（= 4 格/s） | `...CThing_Creature_Player.as:177`；`[MoreRooms] ...:557` | 事实 |
| `mMass` | **2** | `...CThing_Creature_Player.as:178`；`[MoreRooms] ...:558` | 事实 |
| `mHeight` | **1.5** | `...CThing_Creature_Player.as:179`；`[MoreRooms] ...:559` | 事实 |
| `mColor` | 1044480（0x00FF00 蓝绿） | `...CThing_Creature_Player.as:176`；`[MoreRooms] ...:556` | 事实 |
| `mInvincible` 初值 | **200** tick | `...CThing_Creature_Player.as:188`（`this[mInvincible] = 200;`） | 事实 |
| 重生后生命重置 | 200（满血） | `...CThing_Creature_Player.as:330` | 事实 |
| 初始武器 | `pistol`（`SelectWeapon(pistol)`） | `...CThing_Creature_Player.as:182` | 常量池恢复 |
| 受伤白名单（正常） | `mAffect_Bullet \| mAffect_Explosion \| mAffect_ZombieAttack \| mAffect_PlayerLineOfSight \| mAffect_FireBall` | `...CThing_Creature_Player.as:153` | 常量池恢复 |
| 受伤白名单（`mInfinateLife` 开） | 只有 `mAffect_PlayerLineOfSight`（＝免疫一切伤害） | `...CThing_Creature_Player.as:147-149` | 常量池恢复 |
| 死亡音效 | `CSound.mSamples.Creature_Player_Scream_1_wav` | `...CThing_Creature_Player.as:184`；`[MoreRooms] ...:565` | 常量池恢复 |
| 每 tick 碰撞方向登记 | `SetCollideDirection(this.mPosition, World.Map.CMap_Cell.mCollide_Player)` | `[MoreRooms] ...CThing_Creature_Player.as:573` | 事实（明文） |
| 半径 | 基类 `SetRadius(0.45)`（玩家不覆写） | `__Packages/Thing/Creature/CThing_Creature.as:35`；`[MoreRooms] ...CThing_Creature.as:38` | 事实 |

> ⚠️ **一处容易搞错的地方**：2Play 玩家的免疫分支判据是 **`_global.mInfinateLife`**，不是 `mDebug`
> （`__Packages/Thing/Creature/CThing_Creature_Player.as:147` 在 `resolved\` 树里是 `if(_global[mInfinateLife])`）；
> MoreRooms 的同一分支才写 `if(_global.mDebug)`（`[MoreRooms] ...CThing_Creature_Player.as:548`）。
> 两个 build 在这里用**不同的开关**，重制时别混。
> 另外注意正常分支的掩码在 2Play 里含 `mAffect_FireBall`（5 个 flag），MoreRooms 只列了 4 个。

**玩家受伤/生命**：基类里 `mLife <= 0` 即进入死亡流程（`CThing_Creature.as:308-312`、`[MoreRooms] ...CThing_Creature.as:645-648`）。
玩家数值里**没有任何护甲/减伤**机制，敌人打多少就是多少。

### 2.2 主动回血（脱战自动回血）

**事实**（2Play 与 MoreRooms 逐字相同）：

```as2
if(this.mLife > 0 && this.mLife < this.mMaxLife)
    this.mLife = Math.min(this.mLife + this.mMaxLife / (CMain.mFPS * 30), this.mMaxLife);
```
出处：`__Packages/Thing/Creature/CThing_Creature_Player.as:211-214`（`State_PlayerControl` 内，`resolved\` 树给出真实成员名）；
`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:575-578`。

换算：每 tick 回 `200 / (25*30) = 200/750 = 0.2667` HP → **6.67 HP/s**；从 1 点回满 200 点需 **750 tick = 30 秒**。
即「满血用 30 秒」，且只要 `mLife >= 1` 就持续生效——**没有脱战延迟**。

### 2.3 死亡与重生（时间轴）

状态函数名已由 `resolved\` 还原（`State_Dead` / `State_Respawn`），计时器字段是 **`mStateCount`**：

| 项 | 值 | 出处 | 可信度 |
|---|---|---|---|
| 玩家尸体停留 | `CMain.mFPS * 4` = **100 tick（4 s）** | `__Packages/Thing/Creature/CThing_Creature.as:346`（`this[mStateCount] = this[_CLASSID_] != CThing_Creature_Player ? CMain.mFPS * 2 : CMain.mFPS * 4;`） | 常量池恢复 |
| `State_Dead` | 最后 1 秒做淡出（`mAlpha = mStateCount / mFPS * 100`），并把死亡上报给世界（`mWorld.PlayerDead(this)`）；计数到 0 后切 `State_Respawn` 并把 `mStateCount` 重置为 **25** | `...CThing_Creature_Player.as:300-312` | 常量池恢复 |
| `State_Respawn` | 再等 **25 tick（1 s）**，然后重置一切（满血 / 满弹 / 手枪 / 角度 / 位置） | `...CThing_Creature_Player.as:313-332` | 常量池恢复 |
| `mInvincible`（重生后无敌） | **125 tick（5 s）**；DeathMatch 模式为 **25 tick（1 s）** | `...CThing_Creature_Player.as:327`（`this[mInvincible] = 25 * (World.CWorld.mGameMode != DeathMatch ? 5 : 1);`） | 常量池恢复 |
| 重生点 | `mWorld.Spawn_Player_PositionObject(mThing_Collection.GetOtherPlayer(this))` —— 优先取**另一个玩家附近**的合法出生点 | `...CThing_Creature_Player.as:318` | 常量池恢复 |
| 重生后武器 | `ResetWeapons()` + `SelectWeapon(pistol)`（弹药全满、只留手枪） | `...CThing_Creature_Player.as:331-332` | 常量池恢复 |
| 玩家死亡数统计 | `mWorld.mHud.<X>[playerIndex+1]++` | `__Packages/World/CWorld.as:216-218` | 事实（结构） |

> 所以 2 人死亡时间轴 = **4 s 尸体 + 1 s 等待 = 5 s**，之后 5 s 无敌（死斗 1 s）。

> Godot 建议：死亡 → 约 1 s 死亡动画 → 约 1 s 复活等待 → 出生点满血复活 + 5 s 无敌闪烁（死亡竞赛 1 s）。

---

## 3. 恶魔（Devil）数值 —— 全干净，可直接照抄

`__Packages/Thing/Creature/CThing_Creature_Devil.as` 是 **228 行、0 记号**的完全可读文件。

### 3.1 基础属性表

| 属性 | 值 | 出处 |
|---|---|---|
| `mSpeed` | **0.04 格/tick**（= 1 格/s） | `...CThing_Creature_Devil.as:63` |
| 半径 | `SetRadius(CThing_Creature_Devil.mDefault_Scale)`，`mDefault_Scale = 0.42` | `:64`、`:226` |
| `mMaxLife` = `mLife` | **1000** | `:65` |
| `mAttackRange` | **5 格** | `:66` |
| `mAttackDamage` | **50** | `:67` |
| `mMass` | **5** | `:68` |
| `mFireRate` | **0** | `:69` |
| `mScore` | **1000** | `:70` |
| `mHeight` | **1.8** | `:71` |
| `mFireRateCount` | **5**（出生后 5 tick 才能第一次攻击；每次攻击后重置为 `mFireRate`） | `:72`、`:189`、`:82` |
| `mColor` | 16711680（纯红） | `:17`、`:24` |
| 伤害/死亡音效 | `CSound.mSamples["Creature_Zombie_Hit_" + (random(4)+1) + "_wav"]`（3 种随机） | `:76-77` |
| 渲染比例 | `CDrawPrimitive_XSI_StyleSheet.SS_DEVIL(0.42)` | `:34` |
| 动画集 | `Player_Stand/Walk/HitRear/HitFront/Dying/Dead` + `Devil_Devil_Attack` | `:35-41` |

**注意 `mAttackSpeed` 从未被赋值**：
`CUpgrades.ApplyUpgrade_Creature_Devil` 会读写它（`__Packages/World/CUpgrades.as:155`、`:321`），
`State_Attack` 也会把它当弹速传给火球（`...CThing_Creature_Devil.as:176`、`:188`），
但 `Process_Init` 里**没有任何** `mAttackSpeed = ...`（全树 grep `mAttackSpeed` 只有 3 处：CUpgrades 两处 + Devil 一处读取）。
因此 `State_Attack` 传给 `CThing_Shot_FireBall` 的 `tSpeed` 是 `undefined`（注册后可能变成 `NaN`，见 3.3 注），
火球走**构造函数默认速度 0.15**：`__Packages/Thing/Shot/CThing_Shot_FireBall.as:23`
（`this.mDelta = this.mAngle.mDelta.ScaleN(tSpeed != undefined ? tSpeed : 0.15);`）。
→ **恶魔火球速度 = 0.15 格/tick = 3.75 格/s**（推断：等价于「弹速写死 0.15」）。

### 3.2 恶魔攻击的判定与冷却（全部事实）

```
State_Attack_Decision()                                    // :136-161
  1. 若 !mCanAttack 或 mFireRateCount > 0 → 不打
  2. 若目标玩家 mLife <= 0 → 不打
  3. 若 朝向 != 玩家方向 → 不打
  4. 若 Distance_SQR(玩家) > mAttackRange² (25) → 不打
  5. 用 Collide_Line 做视线检测（阻挡者必须是玩家本身）→ 否则不打
```

- 攻击动画推进速度：`Math.min(0.2 * (mSpeed * 25 * 1.5), 1)`（`:168`），即 `min(0.2 * mSpeed * 37.5, 1)`，满速时被 1 封顶。
- 在攻击动画第 **3** 帧时生成火球（`:173`）：`_loc3_.mNewFrame && _loc3_.mFrameIndex == 3`。
- 火球生成位置：模型左右手的平均点；若 NaN 则退回「本体 + 朝向 × 1.5×半径」，`Z = 0.84`（`:178-187`）。
- 开火后 `mFireRateCount = mFireRate`（`:189`）→ 因为 `mFireRate = 0`，**每次攻击动画都能开火**。
  实际射速 = 攻击动画长度（由 0.2×(mSpeed×25×1.5) 的动画播放速率决定）。
- **追击转向时「顺手拆物」**：`State_GotoPlayer` 若前方格子是 `mCollide_Object`，直接进入攻击（`:120-127`）。
- `State_RemoveObject`：正前方对象格上施加 `CThing_Affect_DevilAttack(this, this, **100000**, mAngle)`（`:212`）→ 用来拆墙（比血量任何值都大）。

### 3.3 恶魔火球（`CThing_Shot_FireBall`，干净文件）

| 项 | 值 | 出处 |
|---|---|---|
| 构造函数 | `(tPosition, tAngle, tParent, tDamage, tDamageMultiply, tSpeed)` | `__Packages/Thing/Shot/CThing_Shot_FireBall.as:14` |
| 速度 | `tSpeed`，默认 **0.15 格/tick** | `:23` |
| 半径 | `SetRadius(!mDamageMultiply ? 0.25 : 1)` — 打人版 0.25，拆物版 **1** | `:38` |
| 碰撞半径（静态） | `mCollideRadius = 0.1` | `:74` |
| 每 tick | 命中则按半径矩形做 `AffectArea`；否则 `mPosition += mDelta` | `:43-56` |
| 打人伤害 | `new CThing_Affect_FireBall(mParent, this, this.mDamage, mAngle)`，`mDamage` = 恶魔 `mAttackDamage` = **50** | `:50` + `__Packages/Thing/Creature/CThing_Creature_Devil.as:175`、`:188` |
| 拆物伤害 | `new CThing_Affect_DevilAttack(mParent, this, **10000**, mAngle)` | `:50` |
| `mDelta.ScaleN(1.02)` | 每 tick 意图加速 2%，但**返回值未被使用**（`ScaleN` 返回新对象），因此本行实际无效 | `:45`（推断） |

> 注：`ApplyUpgrade_Creature_Devil` 会写 `tThing.mAttackSpeed = mOriginalStats.mAttackSpeed * (AttackSpeedUp ?? 1)`（`__Packages/World/CUpgrades.as:155`），
> 而 `mOriginalStats.mAttackSpeed` 在注册时是 `undefined`（`__Packages/Thing/Creature/CThing_Creature_Devil.as:65-72` 没赋值），
> `undefined * 1 = NaN`。这会使 `tSpeed != undefined` 成立而传入 `NaN`。
> **推断**：这是原版的一个潜在 bug；重制版请直接把火球速度写死为 0.15（或按 `mAttackSpeed` 默认 0.15 处理），不要复刻 NaN。

### 3.4 恶魔相关伤害组件（成员名已由 `resolved\` 还原）

- `__Packages/Thing/Affect/CThing_Affect_ZombieAttack.as:14`：`function(tOwner, tDamage)`；
  `:16` 把 `tOwner` 同时当作 owner 与 affector 传给基类，伤害类型为 `mAffect_ZombieAttack`；
  `:18-22` 的 `AffectThing(tThing)` 执行 **`tThing[mLife] -= this[mDamage]; return this[mDamage];`**。
  → **事实（常量池恢复）**：僵尸近战就是直接扣 `mLife`，没有护甲/减免。
- `__Packages/Thing/Affect/CThing_Affect_DevilAttack.as:15`：`function(tOwner, tAffector, tDamage, tHitDirection)`，
  类型 `mAffect_DevilAttack`，`:18` 记下 `this[mHitDirection] = tHitDirection`，`:22` 同样执行 `tThing[mLife] -= this[mDamage]`。
  → 恶魔火球/拆物/拆墙都走这个组件，伤害值由调用方给（打人 50 / 拆物 10000 / 拆墙 100000）。**事实（常量池恢复）**

---

## 4. 僵尸（Zombie）数值 —— 已由常量池还原全部确证

线性化版本里 `__Packages/Thing/Creature/CThing_Creature_Zombie.as` = 134 行 / **286 记号**（成员名全被加密），
但 `resolved\` 树把名字全部还原了（行号与线性化一致）。下面直接给出**真实源码**。

### 4.1 `Process_Init` 全文（`__Packages/Thing/Creature/CThing_Creature_Zombie.as:53-66`）

```as2
_loc2_[Process_Init] = function()
{
    super[Process_Init]();                                  // :55 先跑基类：半径 0.45、身高 1.5、mMaxLife=mLife=100
    this[mSpeed]       = 0.02;                              // :56
    this[SetState](State_EnterMap);                         // :57
    this[mBrain_Count] = this[mUniqueID] % 3;               // :58
    this[mScore]       = 100;                               // :59
    this[mHeight]      = 1.5;                               // :60
    this[mDamage]      = 50;                                // :61
    this[mSound]       = new Object();                      // :62
    this[mSound][Damage] = CSound.mSamples["Creature_Zombie_Hit_" + (random(4) + 1) + "_wav"];  // :63
    this[mSound][Death]  = CSound.mSamples["Creature_Zombie_Hit_" + (random(4) + 1) + "_wav"];  // :64
    this[mWorld][mUpgrades][Register_Creature_Zombie](this);                                     // :65
};
```

### 4.2 僵尸数值表（全部为「常量池恢复」级别的事实）

| 属性 | 值 | 出处 |
|---|---|---|
| `mSpeed` | **0.02 格/tick**（= 0.5 格/s） | `CThing_Creature_Zombie.as:56` |
| `mScore` | **100** | `:59` |
| `mHeight` | **1.5** | `:60`（与基类同值） |
| `mDamage` | **50** | `:61` |
| `mMaxLife` = `mLife` | **100**（**继承自基类，僵尸不覆写**） | `__Packages/Thing/Creature/CThing_Creature.as:41` |
| 半径 | **0.45**（**继承自基类，僵尸不覆写**：全文件没有 `SetRadius` / `mRadius` / `mMass` 出现） | `CThing_Creature.as:35` |
| `mMass` | **1**（继承自基类构造函数；僵尸不覆写） | `CThing_Creature.as:21` |
| `mAlpha` | 100（基类构造函数） | `CThing_Creature.as:20` |
| `mBrain_Count` | `this.mUniqueID % 3` —— 每个僵尸出生时取自己的 ID 模 3，用于把僵尸分成 3 组错开行为 | `CThing_Creature_Zombie.as:58` |
| `mColor` | 16711680（纯红） | `CThing_Creature_Zombie.as:18` |
| 受伤/死亡音效 | `Creature_Zombie_Hit_1..4_wav`（各随机一次，所以受伤与死亡可能不同） | `:63`、`:64` |
| 攻击伤害落地位置 | 正前方相邻格：`mAdjacentCells[mAngle.__get__mDirection()].Affect(new CThing_Affect_ZombieAttack(this, this.mDamage))` | `:115-116` |
| 攻击动画速率 | `Math.min(0.3 * (mSpeed * 25 * 1.5), 1)` = `min(0.225, 1)` = **0.225** | `:113` |
| 攻击后收招 | `SetState(State_Sleep)` 并 `mStateCount = 10` → **10 tick = 0.4 s** | `:118`、`:119` |
| 初始状态 | `State_EnterMap` | `:57` |
| 状态集合 | `State_EnterMap` / `State_GotoPlayer` / `State_Attack` / `State_Sleep` / `State_Dead` 等 | `:57`、`:79`、`:109`、`:118` |

> **血量这一项是如何确证的**：僵尸整个文件里 `mLife` 与 `mMaxLife` **一次都不出现**（可在 `resolved\` 树 grep 实证），
> 也就是它完全不覆写血量；基类 `__Packages/Thing/Creature/CThing_Creature.as:41` 的
> `this.mMaxLife = this.mLife = 100;` 就是最终值。→ **僵尸 100 血**，出处写基类那一行。
> 同理，半径与质量也来自基类（`SetRadius(0.45)`、`mMass = 1`），僵尸没有任何覆写。

**攻击的完整判定链**（`resolved\` 树，`:109-122`）：

```as2
_loc2_[State_Attack] = function() {
    if(this[mXSI_Animation][Animate](Math.min(0.3 * (this[mSpeed] * 25 * 1.5), 1))) {   // :113 动画推到命中帧
        var _loc3_ = this[mMap][mCells][this[mPosition][mY] & 0xFFFFFF][this[mPosition][mX] & 0xFFFFFF];
        _loc3_[mAdjacentCells][this[mAngle][__get__mDirection]()][Affect](
            new Thing.Affect.CThing_Affect_ZombieAttack(this, this[mDamage]));          // :116 50 点伤害
        var _loc2_ = this[mReturnStateID];
        this[SetState](State_Sleep);                                                   // :118
        this[mStateCount] = 10;                                                        // :119
        this[mReturnStateID] = _loc2_;
    }
};
```

所以僵尸**没有独立的"攻击冷却"字段**：攻击间隔 = 攻击动画播到命中帧所需的时间 + `State_Sleep` 的 10 tick。
命中帧由动画速率 `0.225` 与动画帧数共同决定。

**僵尸实际移动速度**：

| 等级 | SpeedUp | 僵尸速度 (格/tick) | 格/s |
|---|---|---|---|
| 1 | ×1.10 | 0.022 | 0.55 |
| 10 | ×2.00 | 0.040 | 1.00 |
| 40+ | ×5.00（上限） | 0.100 | 2.50 |

（公式 `mSpeed = 0.02 × SpeedUp`，两项都是事实，见 5.1。）

**与恶魔的对比（一眼看懂设计意图）**：

| | 僵尸 | 恶魔 |
|---|---|---|
| 血量 | 100 | 1000 |
| 伤害 | 50（近战相邻格） | 50（火球）/ 10000（拆物） |
| 速度 | 0.02 格/tick | 0.04 格/tick |
| 半径 / 身高 / 质量 | 0.45 / 1.5 / 1 | 0.42 / 1.8 / 5 |
| 记分 | 100 | 1000 |
| 攻击方式 | 前方相邻格直接扣血 | 远程火球（射程 5 格） |
| 攻击节拍 | 攻击动画 + 10 tick 收招 | 攻击动画（`mFireRate = 0`，每轮都能开火） |

### 4.3 MoreRooms 里那段"可读赋值块"是错位的 —— 请**不要**当成僵尸数值表用

> ✅ **结论状态**：这一判断**现已由 2Play 常量池还原值交叉确认**。
> 2Play 僵尸的真值是 `speed 0.02 / damage 50 / score 100 / height 1.5`（§4.2），
> 而 MoreRooms 那段可读块给的是 `0.04 / 1000 / 1000 / 1.8` —— 显然不是僵尸的数值，而是恶魔的。

`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Zombie.as` 里确实有一段**名字可读**的赋值块：

```as2
// [MoreRooms] __Packages/Thing/Creature/CThing_Creature_Zombie.as:174-192（FFDec 名字替换后的产物）
_loc2_.Process_Init = function() {
    super.Process_Init();
    this.mScore = 0.04;
    this.mHeight(0.42);
    this.mDamage = this.mSound = 1000;
    this.Damage = 5;
    this.CSound = 50;
    this.mSamples = 5;
    this.Creature_Zombie_Hit_ = 0;
    this._wav = 1000;
    this.Death = 1.8;
    this.mWorld = 5;
    this.mUpgrades.Register_Creature_Zombie.Process_Normal(this);
    ...
```

**但这段的成员名是错的，不能当僵尸数值表。** 三条硬证据：

1. 该段的**数值序列与恶魔完全相同**（逐位对应）：
   `0.04 / SetRadius(0.42) / 1000=1000 / 5 / 50 / 5 / 0 / 1000 / 1.8 / 5`
   —— 与 `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Devil.as:54-63` 以及
   **完全可读的** `__Packages/Thing/Creature/CThing_Creature_Devil.as:63-72` 一模一样。
2. 名字本身是自相矛盾的：`this.mHeight(0.42)` 把属性当函数调用；`this.mDamage = this.mSound = 1000` 把音效对象与伤害绑在一起；
   `this.mWorld = 5` 把世界对象赋成 5；`this.mUpgrades.Register_Creature_Zombie.Process_Normal(this)` 把注册函数当对象调方法。
   —— 这些都是 FFDec「常量池名字替换」错位的典型症状（同一构建里恶魔的类名常量缺失，被错误替换成了僵尸的名字）。
3. **同一个文件里还有第二份僵尸类**（成员名仍是 `§§constant`，即未被替换），它的 `Process_Init` 字面量是
   `0.02 / SetRadius(常量) / <X> % 3 / 100 / 1.5 / 50`
   —— `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Zombie.as:446-459`
   （`:449` = `0.02`、`:451` = `% 3`、`:452` = `100`、`:453` = `1.5`、`:454` = `50`），
   **与 2Play 僵尸逐字一致**（对照 `__Packages/Thing/Creature/CThing_Creature_Zombie.as:53-66`）。
   （同一份字节码在未线性化的原始产物里位于 `MoreRooms\scripts\scripts\__Packages\Thing\Creature\CThing_Creature_Zombie.as`
   第 583-596 行；那条路径不属于本文件头约定的两个 `linearized\` 根，仅列出供交叉核对。）

> 因此本文档的立场是：
> - 上面那段 MoreRooms「可读赋值块」**只能作为孤立证据**（它证明了 MoreRooms 僵尸的数值槽位顺序与恶魔相同），
>   **不能**据此写出僵尸的完整数值表，也**不能**据此下结论说「2Play 僵尸血量 1000」——
>   因为 2Play 僵尸的 `Process_Init` 里根本没有 1000 这个字面量。
> - **现已由 2Play 常量池还原值交叉确认**：2Play 僵尸是 `0.02 / 100 / 1.5 / 50`（§4.2 全部为事实），
>   1000 那一组确认属于恶魔，不属于僵尸。
> - 如果 MoreRooms 版本的僵尸真的被调成了 1000 血 / 50 伤 / 1.8 高，那也和 2Play 不是同一套数值，两个 build 有差异。

**僵尸项的最终状态（原「未恢复清单」已基本清空）**：

| 原未恢复项 | 尝试过的路径 | 现状 |
|---|---|---|
| `mMaxLife` / `mScore` 的成员名与数值 | 2Play 线性化（名字加密）；`resolved\` 常量池还原树；基类 `CThing_Creature.as` | ✅ **已恢复**：`mScore = 100`（`:59`）、血量 = 基类 100（`CThing_Creature.as:41`，僵尸不覆写：全文件 0 处 `mLife`/`mMaxLife`） |
| 僵尸半径 / `mMass` | 查 `:56` 的常量、`CDrawPrimitive_XSI_StyleSheet.as`、`CDrawPrimitive_XSI_Collection.as`；再查 `resolved\` 树 | ✅ **已恢复**：僵尸文件里**没有** `SetRadius`/`mRadius`/`mMass` → 半径 = 基类 `SetRadius(0.45)`（`CThing_Creature.as:35`）、质量 = 基类 `mMass = 1`（`CThing_Creature.as:21`） |
| `% 3` 的字段语义 | 对照恶魔、基类；查 `CThing.mID` 分配 | ✅ **已恢复**：`:58 this[mBrain_Count] = this[mUniqueID] % 3;` —— 按实例 ID 分 3 组 |
| 2Play 是否在别处调用 `CUpgrades.SetDifficulty` | grep 全树 `SetDifficulty`；`resolved\` 树逐句核对 `Player.Process_Init:184-188` | ❌ **仍未确认**：`resolved\` 树里 `:186` 是 `SetState(State_PlayerControl)`、`:187` 是 `mWorld.mHud.AddPlayer(this)`、`:188` 是 `mInvincible = 200`，**没有 SetDifficulty**（详见 6.3） |

---

## 5. 敌人升级乘数（SpeedUp / FireRateUp / AttackSpeedUp）

### 5.1 公式（事实）

`__Packages/World/CUpgrades.as:141-167`：

```as2
ApplyUpgrade_Creature_Devil = function(tThing) {
    ... 若 IDCount 未变则直接 return ...
    var _loc4_ = _loc2_.mOriginalStats;
    tThing.mSpeed       = _loc4_.mSpeed       * (SpeedUp       ?? 1);   // :153
    tThing.mFireRate    = _loc4_.mFireRate    * (FireRateUp    ?? 1);   // :154
    tThing.mAttackSpeed = _loc4_.mAttackSpeed * (AttackSpeedUp ?? 1);   // :155
};
ApplyUpgrade_Creature_Zombie = function(tThing) {
    ... 若 IDCount 未变则直接 return ...
    tThing.mSpeed = _loc4_.mSpeed * (SpeedUp ?? 1);                     // :166  ← 只处理 SpeedUp
};
```

- `mOriginalStats` 在**该类第一次生成实例**时快照下来（`Register_Creature_*`，`:293-328`），之后所有乘数都作用在快照上，
  所以是**乘算而非累乘**（每次重算都是 `原始值 × 当前倍率`，不会指数爆炸）。
- 只有 `SpeedUp` 会被写进等级表（`:383` 僵尸、`:392` 恶魔）；`FireRateUp` 与 `AttackSpeedUp` **全程没有赋值点**
  （grep `FireRateUp` / `AttackSpeedUp` 全树只有这两处读取）→ 实际恒为 `1`，即**不生效**。
  但 `ApplyUpgrade_Creature_Devil` 会把 `mAttackSpeed` 写成 `undefined × 1 = NaN`（见 3.3 注）。

### 5.2 上限（事实）

```as2
// __Packages/World/CUpgrades.as:383 与 :392
SpeedUp = Math.min(1 + 等级 / 100 * 10, 5)   // = min(1 + 等级/10, 5)
```

| 行为 | 公式 | 上限 | 达到上限的等级 |
|---|---|---|---|
| 僵尸 `SpeedUp` | `min(1 + L/10, 5)` | **5.0** | L ≥ 40 |
| 恶魔 `SpeedUp` | `min(1 + L/10, 5)` | **5.0** | L ≥ 40 |

推算速度（`mSpeed`）：

| 等级 | 倍率 | 僵尸（0.02 基数，事实） | 恶魔（0.04 基数，事实） |
|---|---|---|---|
| 1 | ×1.10 | 0.022 | 0.044 |
| 10 | ×2.00 | 0.040 | 0.080 |
| 25 | ×3.50 | 0.070 | 0.140 |
| 40+ | ×5.00 | 0.100 | 0.200 |

对照玩家 `mSpeed = 0.16`：**第 30 级左右恶魔就追得上玩家（0.16），之后比玩家快**；
僵尸直到第 40 级封顶也只有 0.10，永远慢于玩家。

---

## 6. 难度（0 / 1 / 2 / 3）

### 6.1 映射表（事实）

`__Packages/World/CUpgrades.as:77-120`：

| `tDifficulty` | 起始等级 `mLevel` | 起始 multiplier | 出处 |
|---|---|---|---|
| `0` | 1 | 1 | `:89-92` |
| `1` | **10** | **10** | `:93-96` |
| `2` | **20** | **30** | `:97-100` |
| `3` | **35** | **50** | `:101-103` |
| 其他（含 `deathmatch` 特例） | 1 | — | `:81-84`：若 `World.CWorld.mGameMode == "DeathMatch"` 则 multiplier 起始值设为 `200`（**注意：代码写的是 `_loc2_ = 200`，而 `_loc2_` 是 multiplier**） |

实现细节（事实）：

```as2
this.mWorld.mHud.mSilentMessages = true;     // :106 屏蔽 "LEVEL N" 提示
_loc3_ = _loc3_ - 1;  while(_loc3_) { ++this.mLevel; _loc3_--; }        // :107-112
_loc2_ = _loc2_ - 1;  while(_loc2_) { ++this.mMultiplier; _loc2_--; }  // :113-118
this.mWorld.mHud.mSilentMessages = false;    // :119
```
即「从 1 逐级递推到目标值」，所以**每一级的升级掉落都会被逐级触发**（例如难度 3 会把 1..35 级里所有 ≤50 的倍率奖励一次性发完）。
`:106/:119` 的 `mSilentMessages` 是给 HUD 的静默标志；HUD 侧读它的位置在
`[MoreRooms] __Packages/World/CHud.as:750-756`（`if(this[§§constant(108)]) return undefined;`，
成员名加密，按语义与唯一性推断为 `mSilentMessages`）。

### 6.2 难度对曲线的连带影响（事实）

- 难度 1（起始 10 级）→ 一开场就是 `Zombie_SpawnRate=16`、`Zombie_Count=55`、`Zombie_TotalCount=55`、僵尸 `SpeedUp=2.0`、恶魔 3 只/级。
- 难度 2（20 级）→ `SpawnRate=6`、`Count=60`、`TotalCount=105`、`SpeedUp=3.0`、恶魔 5 只/级。
- 难度 3（35 级）→ `SpawnRate=1`、`Count=60`、`TotalCount=180`、`SpeedUp=4.5`、恶魔 5 只/级。
- **multiplier 起始值越高，衰减计时器越短**（见第 9 章 `GetTicks`）：难度 1 一开局 multiplier 10 的窗口只有 2.40 s，
  难度 3 的 multiplier 50 只有 0.655 s。

### 6.3 难度的应用时机与解锁

**应用时机**：

| build | 调用点 | 净值 |
|---|---|---|
| MoreRooms | `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:567`（`Process_Init` 内，每个玩家实例一次） | 一次 |
| 2Play | **没有调用**（`resolved\` 树已确认）。2Play 玩家 `Process_Init` 的末尾三句是 `__Packages/Thing/Creature/CThing_Creature_Player.as:186-188`：`this[SetState](State_PlayerControl);` / `this[mWorld][mHud][AddPlayer](this);` / `this[mInvincible] = 200;` —— **没有 `SetDifficulty`**；全树 grep `SetDifficulty` 只有 `CUpgrades.as:77` 的定义 | **0 次** |

> **结论（常量池恢复后）**：2Play 这个 build **从不调用** `CUpgrades.SetDifficulty`。
> 也就是说 `SetDifficulty` 在 2Play 里是一段**死代码**，难度 0/1/2/3 的映射表虽然还在，
> 但**不会**在游戏里生效——难度选项只被存进 `CSaveData.mDifficulty`（供 UI 显示），不影响开局等级/倍率。
> **（推断补充）**：2Play 里难度对数值的唯一实际影响也就到此为止；如果重制版想让难度生效，
> 应当**主动**在开局（每个玩家生成时**只调一次**）应用 `SetDifficulty(CSaveData.mDifficulty)`，
> 数值就按 §6.1 的表。注意别按「每个玩家一次」实现，否则 2 人合作时 `mLevel`/`mMultiplier` 会累加两次
> （难度 1 → 等级 19 / multiplier 19）。

**解锁条件**：**代码里没有难度解锁门槛**。
- `CSaveData`（MoreRooms 干净版）只是把 `mDifficulty` 存进 SharedObject，默认值 `0`：
  `[MoreRooms] __Packages/CSaveData.as:74-83`（getter/setter）、`:125`（`_loc2_._Difficulty = 0;`）、`:101`（`SharedObject.getLocal`）。
  2Play 的 `CSaveData.as` 属性更多（约 30 个，含 `mDevilsActive` / `mCollisionsActive` / `mDamageActive` / 键位等），但**整套被加密（808 记号）**，默认值未能恢复。
 - 游戏选项界面允许直接改难度：**原始反编译树**（`oldGame\_decompiled\Boxhead_2Play\scripts\scripts\`）下的
   `__Packages/Screen/CScreen_Intro.as`，其字符串常量池段**第 8490-8507 行**同时出现
   `"mDifficulty"`、`"__set__mDifficulty"`、`"RegisterDifficulty"`、`"mAllGroups"`，以及难度名
   `"_Level_Intermediate"`（第 8492 行）、`"_Level_Nightmare"`（第 8493 行）。
   ⚠️ 这段内容**只存在于未线性化的原始产物里**：`linearized\` 树的同名文件没有这串字符串
   （该文件在 `linearized\` 里共 8513 行，第 8488-8495 行是浮点常量，不是字符串池）。
   → 界面上的难度名只有 **Normal / Intermediate / Nightmare** 三个（对应 0/1/2），
   **难度 3（35 级 / ×50）在字符串池里没有对应标签**，很可能是调试/隐藏档（推断）。
- 全树 grep `unlock` / `Unlock` / `WorldsActive` / `LevelsActive` **零命中**（大小写都试过）。
- 关卡选择界面上每个关卡图标的"专属/不可玩"标记来自三个 19 元素数组，**名字已由 `resolved\` 还原**：
  `__Packages/Screen/CScreen_SelectWorld.as:478` = **`Single_Exclusives`** = `[0×13, 1×6]`、
  `:498` = **`Coop_Exclusives`** = `[0×4, 1×15]`、
  `:518` = **`DeathMatch_Exclusives`** = `[0×4, 1×15]`。
  **是按游戏模式区分，不是按难度。** 取用与判定（`resolved\`，`:124-138`）：

  ```as2
  ChangeLevel = function(mcTarget, tIndex) {
      var _loc5_ = Screen.CScreen_SelectWorld[this.mMode + "_Exclusives"];      // :126
      ...
      var _loc4_ = !_global.mHostedOnCMG ? _loc5_[tIndex] == 1 : false;         // :129
      mcTarget.mcLevelIcons.mcExclusive._visible = _loc4_;                      // :130
      if(!_loc4_) { mcTarget.mcLevelIcons._Button.onRelease = ... }             // :131-138 装了才可点
  };
  ```
  → **数组值 = 1 表示该关卡对该模式"专属/禁用"**（会显示 `mcExclusive` 标记并且**不安装点击处理器**，点不动）。
  于是：**Single 模式只有第 14-19 关可玩（0 基索引 13..18）；Coop 与 DeathMatch 只有第 5-19 关可玩（索引 4..18）。**
  另外门槛用的是 `_global.mHostedOnCMG`（不是 `mDebug`）：托管在 CrazyMonkeyGames 时全部按 `false` 处理，即**所有关卡都可玩**。
  （「1 = 专属/禁用」这一极性是从 `:130/:131` 的 `_visible` 与 `if(!_loc4_)` 推出来的，属**推断**；
  数组内容、名字、行号都是**事实**。）

**其他 `CSaveData` 门槛（事实）**：提交高分前会检查三个选项是否都为 1：
`__Packages/Screen/CScreen_Debrief.as:1038`、`__Packages/Screen/CScreen_Debrief_Winner.as:39`：
```as2
if(!(CMain.mSaveData.mDevilsActive == 1 && CMain.mSaveData.mCollisionsActive == 1 && CMain.mSaveData.mDamageActive == 1))
    this.DisableSubmitScore();
```
→ 即「关了恶魔 / 关了碰撞 / 关了伤害」的作弊式设置**不允许上传分数**。

---

## 7. 1..100 级完整刷怪曲线

### 7.1 递推源码（事实）

`__Packages/World/CUpgrades.as:365-398`（`InitLists`，**干净可读**；MoreRooms 有一份独立实现可互证：
`[MoreRooms] __Packages/World/Init/CWorld_Init_Zombie.as:467-497`，数值完全一致）：

> **权威来源说明**：本章（以及第 5、6、8、9、10 章）的**唯一权威来源是 2Play 的 `__Packages/World/CUpgrades.as`**
> —— 669 行、**0 处加密记号**、全明文。
> MoreRooms 的 `CUpgrades` 类反而被严重加密（1103 处记号），**不要**拿它当依据；
> 它只是把同一份 `InitLists` 的字节码错位到了别的文件名下（`CWorld_Init_Zombie.as` 等），
> 可以当**交叉验证**用（本文件确实用它验证了闭式公式），但不能作为主要出处。

```as2
var _loc8_ = 1 * CMain.mFPS;                              // = 25      僵尸刷怪间隔
var _loc4_ = !_global.mCheat_OneZombie ? 10 : 1;          // = 10      僵尸同屏上限初值
var _loc5_ = 10;                                          // = 10      僵尸总数
var _loc6_ = 10 * CMain.mFPS;                             // = 250     恶魔刷怪间隔
var _loc7_ = 0;                                           // 恶魔同屏上限（浮点累加）
var _loc9_ = 0;                                           // 恶魔总数（浮点累加）
var _loc3_ = 1;
while(_loc3_ <= 100) {
    AddToLevel(_loc3_, Zombie_SpawnRate  = floor(_loc8_));                       // :380
    AddToLevel(_loc3_, Zombie_Count      = floor(_loc4_));                       // :381
    AddToLevel(_loc3_, Zombie_TotalCount = floor(_loc5_));                       // :382
    AddToLevel(_loc3_, CThing_Creature_Zombie.SpeedUp = min(1 + _loc3_/100*10,5)); // :383
    _loc8_ = max(_loc8_ - 1, 1);                                                 // :384
    _loc4_ = min(_loc4_ + 5, 60);                                                // :385
    _loc5_ += 5;                                                                // :386
    if(CMain.mSaveData.mDevilsActive) {                                          // :387
        AddToLevel(_loc3_, Devil_SpawnRate  = floor(_loc6_));                    // :389
        AddToLevel(_loc3_, Devil_Count      = floor(_loc7_));                    // :390
        AddToLevel(_loc3_, Devil_TotalCount = floor(_loc9_));                    // :391
        AddToLevel(_loc3_, CThing_Creature_Devil.SpeedUp = min(1 + _loc3_/100*10,5)); // :392
        _loc7_ = min(_loc3_ != 1 ? _loc7_ + 0.3 : 1, 5);                         // :393
        _loc9_ = _loc3_ != 1 ? _loc9_ + 0.25 : 1;                                // :394
        _loc6_ = max(_loc6_ - 1, CMain.mFPS);                                    // :395
    }
    _loc3_++;
}
```

### 7.2 闭式公式（由上面递推解出）

| 参数 | 闭式 | 范围 |
|---|---|---|
| `Zombie_SpawnRate(L)` | `max(26 - L, 1)` tick | 1→25，25 级起恒为 1 |
| `Zombie_Count(L)` | `min(5L + 5, 60)` | 1→10，11 级起 60（**运行期还会被画质再压一次，见 7.4**） |
| `Zombie_TotalCount(L)` | `5L + 5` | 1→10，100→505（无上限） |
| `Devil_SpawnRate(L)` | `max(251 - L, 25)` tick | 1→250，100→151 |
| `Devil_Count(L)` | `L == 1 ? 0 : min(floor(1 + 0.3(L-2)), 5)` | 1→0，2..5→1，16 级起 5 |
| `Devil_TotalCount(L)` | `L == 1 ? 0 : floor(1 + 0.25(L-2))` = `floor(0.25L + 0.5)` | 1→0，10→3，50→13，100→25（**无上限**） |
| `SpeedUp(L)`（僵尸与恶魔相同） | `min(1 + L/10, 5)` | 1→×1.10，40 级起 ×5.00 |

**`mDevilsActive` 是开关**（`:387`）：若为 `0`，则**整张恶魔表都不生成**，
`Level.Devil_SpawnRate` / `Devil_Count` / `Devil_TotalCount` 全为 `undefined`，
此时 `Process` 里 `var _loc5_ = !this.Level.Devil_Count ? 0 : this.Level.Devil_Count;`（`:35`）保证不刷恶魔、也不卡关。

### 7.3 完整 1..100 级表（按 7.1 递推程序化生成，`CMain.mFPS = 25`）

> 僵尸/恶魔速度列为 `基数 × SpeedUp` 的换算结果（僵尸基数 0.02、恶魔基数 0.04 都是事实，见 §4.2 / §3.1）。
> 「间隔(s)」= `SpawnRate / 25`。

| 等级 | 僵尸间隔(tick) | 僵尸同屏上限 | 僵尸总数 | 恶魔间隔(tick) | 恶魔同屏上限 | 恶魔总数 | SpeedUp | 僵尸速度 | 恶魔速度 | 僵尸间隔(s) | 恶魔间隔(s) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 25 | 10 | 10 | 250 | 0 | 0 | ×1.10 | 0.022 | 0.044 | 1.00 | 10.00 |
| 2 | 24 | 15 | 15 | 249 | 1 | 1 | ×1.20 | 0.024 | 0.048 | 0.96 | 9.96 |
| 3 | 23 | 20 | 20 | 248 | 1 | 1 | ×1.30 | 0.026 | 0.052 | 0.92 | 9.92 |
| 4 | 22 | 25 | 25 | 247 | 1 | 1 | ×1.40 | 0.028 | 0.056 | 0.88 | 9.88 |
| 5 | 21 | 30 | 30 | 246 | 1 | 1 | ×1.50 | 0.030 | 0.060 | 0.84 | 9.84 |
| 6 | 20 | 35 | 35 | 245 | 2 | 2 | ×1.60 | 0.032 | 0.064 | 0.80 | 9.80 |
| 7 | 19 | 40 | 40 | 244 | 2 | 2 | ×1.70 | 0.034 | 0.068 | 0.76 | 9.76 |
| 8 | 18 | 45 | 45 | 243 | 2 | 2 | ×1.80 | 0.036 | 0.072 | 0.72 | 9.72 |
| 9 | 17 | 50 | 50 | 242 | 3 | 2 | ×1.90 | 0.038 | 0.076 | 0.68 | 9.68 |
| 10 | 16 | 55 | 55 | 241 | 3 | 3 | ×2.00 | 0.040 | 0.080 | 0.64 | 9.64 |
| 11 | 15 | 60 | 60 | 240 | 3 | 3 | ×2.10 | 0.042 | 0.084 | 0.60 | 9.60 |
| 12 | 14 | 60 | 65 | 239 | 3 | 3 | ×2.20 | 0.044 | 0.088 | 0.56 | 9.56 |
| 13 | 13 | 60 | 70 | 238 | 4 | 3 | ×2.30 | 0.046 | 0.092 | 0.52 | 9.52 |
| 14 | 12 | 60 | 75 | 237 | 4 | 4 | ×2.40 | 0.048 | 0.096 | 0.48 | 9.48 |
| 15 | 11 | 60 | 80 | 236 | 4 | 4 | ×2.50 | 0.050 | 0.100 | 0.44 | 9.44 |
| 16 | 10 | 60 | 85 | 235 | 5 | 4 | ×2.60 | 0.052 | 0.104 | 0.40 | 9.40 |
| 17 | 9 | 60 | 90 | 234 | 5 | 4 | ×2.70 | 0.054 | 0.108 | 0.36 | 9.36 |
| 18 | 8 | 60 | 95 | 233 | 5 | 5 | ×2.80 | 0.056 | 0.112 | 0.32 | 9.32 |
| 19 | 7 | 60 | 100 | 232 | 5 | 5 | ×2.90 | 0.058 | 0.116 | 0.28 | 9.28 |
| 20 | 6 | 60 | 105 | 231 | 5 | 5 | ×3.00 | 0.060 | 0.120 | 0.24 | 9.24 |
| 21 | 5 | 60 | 110 | 230 | 5 | 5 | ×3.10 | 0.062 | 0.124 | 0.20 | 9.20 |
| 22 | 4 | 60 | 115 | 229 | 5 | 6 | ×3.20 | 0.064 | 0.128 | 0.16 | 9.16 |
| 23 | 3 | 60 | 120 | 228 | 5 | 6 | ×3.30 | 0.066 | 0.132 | 0.12 | 9.12 |
| 24 | 2 | 60 | 125 | 227 | 5 | 6 | ×3.40 | 0.068 | 0.136 | 0.08 | 9.08 |
| 25 | 1 | 60 | 130 | 226 | 5 | 6 | ×3.50 | 0.070 | 0.140 | 0.04 | 9.04 |
| 26 | 1 | 60 | 135 | 225 | 5 | 7 | ×3.60 | 0.072 | 0.144 | 0.04 | 9.00 |
| 27 | 1 | 60 | 140 | 224 | 5 | 7 | ×3.70 | 0.074 | 0.148 | 0.04 | 8.96 |
| 28 | 1 | 60 | 145 | 223 | 5 | 7 | ×3.80 | 0.076 | 0.152 | 0.04 | 8.92 |
| 29 | 1 | 60 | 150 | 222 | 5 | 7 | ×3.90 | 0.078 | 0.156 | 0.04 | 8.88 |
| 30 | 1 | 60 | 155 | 221 | 5 | 8 | ×4.00 | 0.080 | 0.160 | 0.04 | 8.84 |
| 31 | 1 | 60 | 160 | 220 | 5 | 8 | ×4.10 | 0.082 | 0.164 | 0.04 | 8.80 |
| 32 | 1 | 60 | 165 | 219 | 5 | 8 | ×4.20 | 0.084 | 0.168 | 0.04 | 8.76 |
| 33 | 1 | 60 | 170 | 218 | 5 | 8 | ×4.30 | 0.086 | 0.172 | 0.04 | 8.72 |
| 34 | 1 | 60 | 175 | 217 | 5 | 9 | ×4.40 | 0.088 | 0.176 | 0.04 | 8.68 |
| 35 | 1 | 60 | 180 | 216 | 5 | 9 | ×4.50 | 0.090 | 0.180 | 0.04 | 8.64 |
| 36 | 1 | 60 | 185 | 215 | 5 | 9 | ×4.60 | 0.092 | 0.184 | 0.04 | 8.60 |
| 37 | 1 | 60 | 190 | 214 | 5 | 9 | ×4.70 | 0.094 | 0.188 | 0.04 | 8.56 |
| 38 | 1 | 60 | 195 | 213 | 5 | 10 | ×4.80 | 0.096 | 0.192 | 0.04 | 8.52 |
| 39 | 1 | 60 | 200 | 212 | 5 | 10 | ×4.90 | 0.098 | 0.196 | 0.04 | 8.48 |
| 40 | 1 | 60 | 205 | 211 | 5 | 10 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.44 |
| 41 | 1 | 60 | 210 | 210 | 5 | 10 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.40 |
| 42 | 1 | 60 | 215 | 209 | 5 | 11 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.36 |
| 43 | 1 | 60 | 220 | 208 | 5 | 11 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.32 |
| 44 | 1 | 60 | 225 | 207 | 5 | 11 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.28 |
| 45 | 1 | 60 | 230 | 206 | 5 | 11 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.24 |
| 46 | 1 | 60 | 235 | 205 | 5 | 12 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.20 |
| 47 | 1 | 60 | 240 | 204 | 5 | 12 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.16 |
| 48 | 1 | 60 | 245 | 203 | 5 | 12 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.12 |
| 49 | 1 | 60 | 250 | 202 | 5 | 12 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.08 |
| 50 | 1 | 60 | 255 | 201 | 5 | 13 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.04 |
| 51 | 1 | 60 | 260 | 200 | 5 | 13 | ×5.00 | 0.100 | 0.200 | 0.04 | 8.00 |
| 52 | 1 | 60 | 265 | 199 | 5 | 13 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.96 |
| 53 | 1 | 60 | 270 | 198 | 5 | 13 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.92 |
| 54 | 1 | 60 | 275 | 197 | 5 | 14 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.88 |
| 55 | 1 | 60 | 280 | 196 | 5 | 14 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.84 |
| 56 | 1 | 60 | 285 | 195 | 5 | 14 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.80 |
| 57 | 1 | 60 | 290 | 194 | 5 | 14 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.76 |
| 58 | 1 | 60 | 295 | 193 | 5 | 15 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.72 |
| 59 | 1 | 60 | 300 | 192 | 5 | 15 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.68 |
| 60 | 1 | 60 | 305 | 191 | 5 | 15 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.64 |
| 61 | 1 | 60 | 310 | 190 | 5 | 15 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.60 |
| 62 | 1 | 60 | 315 | 189 | 5 | 16 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.56 |
| 63 | 1 | 60 | 320 | 188 | 5 | 16 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.52 |
| 64 | 1 | 60 | 325 | 187 | 5 | 16 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.48 |
| 65 | 1 | 60 | 330 | 186 | 5 | 16 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.44 |
| 66 | 1 | 60 | 335 | 185 | 5 | 17 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.40 |
| 67 | 1 | 60 | 340 | 184 | 5 | 17 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.36 |
| 68 | 1 | 60 | 345 | 183 | 5 | 17 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.32 |
| 69 | 1 | 60 | 350 | 182 | 5 | 17 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.28 |
| 70 | 1 | 60 | 355 | 181 | 5 | 18 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.24 |
| 71 | 1 | 60 | 360 | 180 | 5 | 18 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.20 |
| 72 | 1 | 60 | 365 | 179 | 5 | 18 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.16 |
| 73 | 1 | 60 | 370 | 178 | 5 | 18 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.12 |
| 74 | 1 | 60 | 375 | 177 | 5 | 19 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.08 |
| 75 | 1 | 60 | 380 | 176 | 5 | 19 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.04 |
| 76 | 1 | 60 | 385 | 175 | 5 | 19 | ×5.00 | 0.100 | 0.200 | 0.04 | 7.00 |
| 77 | 1 | 60 | 390 | 174 | 5 | 19 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.96 |
| 78 | 1 | 60 | 395 | 173 | 5 | 20 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.92 |
| 79 | 1 | 60 | 400 | 172 | 5 | 20 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.88 |
| 80 | 1 | 60 | 405 | 171 | 5 | 20 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.84 |
| 81 | 1 | 60 | 410 | 170 | 5 | 20 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.80 |
| 82 | 1 | 60 | 415 | 169 | 5 | 21 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.76 |
| 83 | 1 | 60 | 420 | 168 | 5 | 21 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.72 |
| 84 | 1 | 60 | 425 | 167 | 5 | 21 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.68 |
| 85 | 1 | 60 | 430 | 166 | 5 | 21 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.64 |
| 86 | 1 | 60 | 435 | 165 | 5 | 22 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.60 |
| 87 | 1 | 60 | 440 | 164 | 5 | 22 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.56 |
| 88 | 1 | 60 | 445 | 163 | 5 | 22 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.52 |
| 89 | 1 | 60 | 450 | 162 | 5 | 22 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.48 |
| 90 | 1 | 60 | 455 | 161 | 5 | 23 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.44 |
| 91 | 1 | 60 | 460 | 160 | 5 | 23 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.40 |
| 92 | 1 | 60 | 465 | 159 | 5 | 23 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.36 |
| 93 | 1 | 60 | 470 | 158 | 5 | 23 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.32 |
| 94 | 1 | 60 | 475 | 157 | 5 | 24 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.28 |
| 95 | 1 | 60 | 480 | 156 | 5 | 24 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.24 |
| 96 | 1 | 60 | 485 | 155 | 5 | 24 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.20 |
| 97 | 1 | 60 | 490 | 154 | 5 | 24 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.16 |
| 98 | 1 | 60 | 495 | 153 | 5 | 25 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.12 |
| 99 | 1 | 60 | 500 | 152 | 5 | 25 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.08 |
| 100 | 1 | 60 | 505 | 151 | 5 | 25 | ×5.00 | 0.100 | 0.200 | 0.04 | 6.04 |

**关键节点速查**

| 等级 | 僵尸间隔 | 僵尸同屏 | 僵尸总数 | 恶魔间隔 | 恶魔同屏 | 恶魔总数 | SpeedUp | 僵尸速度 | 恶魔速度 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 25 tick / 1.00 s | 10 | 10 | 250 tick / 10.00 s | 0 | 0 | ×1.10 | 0.022 | 0.044 |
| 10 | 16 tick / 0.64 s | 55 | 55 | 241 tick / 9.64 s | 3 | 3 | ×2.00 | 0.040 | 0.080 |
| 25 | 1 tick / 0.04 s | 60 | 130 | 226 tick / 9.04 s | 5 | 6 | ×3.50 | 0.070 | 0.140 |
| 50 | 1 tick / 0.04 s | 60 | 255 | 201 tick / 8.04 s | 5 | 13 | ×5.00 | 0.100 | 0.200 |
| 100 | 1 tick / 0.04 s | 60 | 505 | 151 tick / 6.04 s | 5 | 25 | ×5.00 | 0.100 | 0.200 |

> **100 级以上**：`mLevel` 会被钳到 100 级继续游戏，HUD 显示 `LEVEL 101 (FOREVER)` 之类。
> 证据：`__Packages/World/CUpgrades.as:512`（`this.mLevels[this.mLevelIndex <= 100 ? this.mLevelIndex : 100]`）与
> `:521`（`this.mLevelIndex <= 100 ? this.mLevelIndex : this.mLevelIndex + " (FOREVER)"`）。
> 也就是说 **100 级之后难度不再增长，只无限重复 100 级的曲线**。

### 7.4 刷怪与同屏上限（事实）

`__Packages/World/CUpgrades.as:26-64`（`Process`，每逻辑 tick 一次）：

```as2
if(World.CWorld.mGameMode == "DeathMatch") return;                      // :28 死斗模式不刷怪
this.mTick = this.mTick + 1;
var _loc4_ = !counters.CThing_Creature_Devil && !counters.CThing_Creature_Zombie;  // 场上无敌人
var _loc5_ = !Level.Devil_Count ? 0 : Level.Devil_Count;
var _loc6_ = Level.Zombie_Count;
if(_loc6_ <= 0 && _loc5_ <= 0 && _loc4_) { ++this.mLevel; CSound.mSamples.Click.PlaySound(); }  // :37-41 过关
else {
    // 僵尸
    if(Level.mZombieCount < Math.min(Level.Zombie_Count, _root._quality != "LOW" ? 60 : 40)) {  // :44-45
        if(Level.mSpawnCount_Zombie-- <= 0) {                       // :46
            if(mWorld.Spawn_Zombie()) Level.mSpawnCount_Zombie = Level.Zombie_SpawnRate;        // :48-50
        }
    }
    // 恶魔
    if(Level.mDevilCount < Level.Devil_Count) {                     // :54
        if((Level.mSpawnCount_Devil -= Level.Zombie_Count != 0 ? 1 : 10) <= 0) {                // :56
            if(mWorld.Spawn_Devil()) Level.mSpawnCount_Devil = Level.Devil_SpawnRate;           // :58-60
        }
    }
}
```

三个重要细节：

1. **画质决定同屏上限**：`min(Zombie_Count, LOW 画质 ? 40 : 60)`（`:44`）。表里的 60 在 LOW 画质下变成 40。
2. **僵尸配额见底后恶魔刷得更快**：`:56` 的递减量是「僵尸总数 ≠ 0 时减 1，否则减 10」。
   即关卡前期恶魔按 `Devil_SpawnRate` 计时，**僵尸被清完后计时速度 ×10**（10 级时 241 tick → 折合约 0.96 s 一只）。
3. **实际刷怪点**：从关卡里的 `CWorld_Init_Zombie` 标记点里**随机**取一个通过校验的点
   （`[MoreRooms] __Packages/World/CWorld.as:299-334`：`Spawn_ValidPosition` 检查 `mCollide_NoSpawn`，
   `Spawn_ValidPosition_NonStrict` 检查 `mCollide_Creature`；僵尸用严格版，恶魔用宽松版）。
   出生点登记本身是 `[MoreRooms] __Packages/World/CWorld.as:260-279`，四个数组分别落在
   `mSpawnPoint_Zombie`（`:263`）、`mSpawnPoint_Player`（`:268`）、`mSpawnPoint_Devil`（`:273`）、
   `mSpawnPoint_Pickup`（`:278`），每个点都用 `this.mMap.GetCell(p.mX, p.mY)` 反查格子
   —— 这就是「刷怪位置规则」的可靠出处（`[MoreRooms] __Packages/World/CWorld.as` 是 505 行、**0 记号、全明文**）。
   `Spawn_Zombie` 失败（找不到合法点）时**不会重置计时器**，下一 tick 继续尝试（`:48-50`）。
   2Play 里对应实现见 `__Packages/World/CWorld.as:147-170`（成员名加密，但结构与 `:153` 的计数器自增、`:154/:166` 的
   `AddThing(new CThing_Creature_Zombie/Devil(...))` 完全一致）。
   `CWorld_Init_Zombie` / `CWorld_Init_Devil` / `CWorld_Init_Player1` / `CWorld_Init_Player2` / `CWorld_Init_Pickup`
   本身只是**标记类**（2Play `__Packages/World/Init/CWorld_Init_Zombie.as` 仅 23 行：声明继承 + `_CLASSID_`），
   真正的语义在 `CWorld.Init` 的分发里：`[MoreRooms] __Packages/World/CWorld.as:103-117`。

---

## 8. 每级要杀多少怪 · 计数如何减少 · 何时进下一级

### 8.1 计数器的语义

| 计数器 | 含义 | 初始化位置 |
|---|---|---|
| `Level.Zombie_Count` | **同屏上限**，同时兼作「本关剩余目标」的钳位 | 每级从等级表写入（`:381`） |
| `Level.Zombie_TotalCount` | **本关僵尸总配额**，每杀 1 只 -1 | 每级从等级表写入（`:382`） |
| `Level.mZombieCount` | **当前存活僵尸数** | 每级重置为 0（`:517`） |
| `Level.mSpawnCount_Zombie` | 刷怪倒计时 | 每级重置为 `Zombie_SpawnRate`（`:519`） |
| `Level.Devil_*` / `mDevilCount` / `mSpawnCount_Devil` | 同上，恶魔版 | `:518`、`:520` |

### 8.2 击杀如何减少计数（事实，带 setter 副作用）

```as2
// __Packages/World/CUpgrades.as:591-609
__set__mZombieCount = function(a) {
    var _loc2_ = a - this.Level.mZombieCount;      // 变化量
    if(_loc2_ < 0) {                               // 在减少（= 有僵尸死了）
        this.Level.Zombie_TotalCount += _loc2_;    // 总配额 -1
        if(this.Level.Zombie_TotalCount < this.Level.Zombie_Count)
            this.Level.Zombie_Count = this.Level.Zombie_TotalCount;   // 同屏上限跟着往下压
        this.LogKills(1);                          // 连杀 +1、multiplier +1
    }
    this.Level.mZombieCount = a;
};
// :610-624 恶魔版完全对称
```
- 生成时 `++mZombieCount`（`__Packages/World/CWorld.as:153`，`[MoreRooms] __Packages/World/CWorld.as:341`）。
- 死亡时 `--mZombieCount`（`__Packages/World/CWorld.as:206`，`[MoreRooms] __Packages/World/CWorld.as:372`），触发上面的副作用。
- 所以**每关需要击杀的总数 = 该级的 `Zombie_TotalCount`（+ `Devil_TotalCount`）**，
  而 `Zombie_Count` 会随着剩余配额下降而自动收敛，保证「配额清零 ⇒ 同屏上限也变 0」。

`LogKills`（`:500-508`）：
```as2
LogKills = function(a) { while(a) { ++this.mMultipleKill; ++this.mMultiplier; a = a - 1; } };
```
→ **一次击杀同时 +1 连杀计数和 +1 multiplier**。

### 8.3 进入下一级的判定（事实）

```as2
// __Packages/World/CUpgrades.as:33-41
var _loc4_ = !counters.CThing_Creature_Devil && !counters.CThing_Creature_Zombie;   // 场上无存活敌人
var _loc5_ = !this.Level.Devil_Count ? 0 : this.Level.Devil_Count;
var _loc6_ = this.Level.Zombie_Count;
if(_loc6_ <= 0 && _loc5_ <= 0 && _loc4_) { ++this.mLevel; CSound.mSamples.Click.PlaySound(); }
```

进级瞬间（`__set__mLevel`，`:509-523`）：

1. `mLevelIndex = a`；
2. 从 `mLevels[min(a,100)]` 里把该级的 `Level.*` 参数与 `SpeedUp` 全部 `AddUpgrade`；
3. `Level.mZombieCount = 0; Level.mDevilCount = 0;`
4. `Level.mSpawnCount_Zombie = Zombie_SpawnRate; Level.mSpawnCount_Devil = Devil_SpawnRate;`
5. HUD 消息 `"-+-+-+- LEVEL N -+-+-+-"`（`mSilentMessages` 为 true 时不显示）。

> 注意 2、3、4 的顺序：**先写参数再清零计数**，所以新关的 `mSpawnCount_*` 用的是新关的参数。
> 另外 `AddUpgrade` 内部对 `tValue != true` 的条目会调用**所有玩家**的 `NewWeapon(tValue)`（`:128-135`），
> 这就是「捡到新武器会直接给所有玩家」的机制。

**每关实际杀敌数**（= `Zombie_TotalCount + Devil_TotalCount`，两表都由 7.2 的闭式给出）：

| 等级 | 僵尸 | 恶魔 | 合计 | 等级 | 僵尸 | 恶魔 | 合计 |
|---|---|---|---|---|---|---|---|
| 1 | 10 | 0 | 10 | 50 | 255 | 13 | 268 |
| 5 | 30 | 1 | 31 | 60 | 305 | 15 | 320 |
| 10 | 55 | 3 | 58 | 70 | 355 | 18 | 373 |
| 15 | 80 | 4 | 84 | 80 | 405 | 20 | 425 |
| 20 | 105 | 5 | 110 | 90 | 455 | 23 | 478 |
| 25 | 130 | 6 | 136 | 100 | 505 | 25 | 530 |
| 30 | 155 | 8 | 163 | | | | |
| 40 | 205 | 10 | 215 | | | | |

（恶魔数会随 `mDevilsActive` 开关整体为 0。）

---

## 9. multiplier 与 multiple-kill：触发条件与完整掉落表

### 9.1 multiplier（倍率链）—— **这就是升级系统的主体**

```as2
// __Packages/World/CUpgrades.as:556-576
__set__mMultiplier = function(a) {
    this.mMultiplierIndex = a >= 1 ? (a <= 999 ? a : 999) : 1;        // 钳位 [1, 999]
    this.mMultiplierTickTotal = this.mMultiplierTick = this.GetTicks(this.mMultiplierIndex);
    if(a > 1) {
        var _loc3_ = this.mMultipliers[this.mMultiplierIndex];
        for(var _loc4_ in _loc3_) {
            var _loc2_ = _loc3_[_loc4_];
            if(_loc2_.mActive != true) { this.AddUpgrade(...); _loc2_.mActive = true; }   // 只发一次
        }
    }
};
```

- **触发条件**：任何一次击杀（`LogKills` 里 `++mMultiplier`）。
- **衰减**：`Process` 里 `if(this.mMultiplierTick-- < 0) { --this.mMultiplier; }`（`:72-75`），
  窗口长度 = `GetTicks(multiplier)`（见第 10 章）。窗口越靠后越短。
- **精确匹配**：只发 `mMultipliers[当前 index]` 这一档。因为每次击杀恰好 +1，正常流程会经过每一档；
  但如果链条断掉（衰减到 1）再重新攒，**已发过的档不会重发**（`mActive` 标记，`:567-572`），没到过的档仍然会补发。
- **`mActive` 永不复位**：全树没有把 `mActive` 设回 false 的代码 → 一局里每个奖励只可能拿到一次。

### 9.2 multiple-kill（连杀）—— **表是空的**

```as2
// :528-547
__set__mMultipleKill = function(a) {
    this.mMultipleKillsIndex = a >= 0 ? a : 0;
    if(this.mMultipleKillsIndex) {
        this.mMultipleKillsTickTotal = this.mMultipleKillsTick = this.GetTicks(this.mMultipleKillsIndex) / 6;
        var _loc2_ = this.mMultipleKills[this.mMultipleKillsIndex];
        delete this.mMultipleKills[this.mMultipleKillsIndex];        // ← 用完即删
        for(var _loc3_ in _loc2_) { this.AddUpgrade(...); }
    } else {
        this.mMultipleKillsTickTotal = this.mMultipleKillsTick = 100000;
    }
};
```

- 触发：`LogKills` 里 `++mMultipleKill`（每次击杀 +1，与 multiplier 同步）。
- 窗口：`GetTicks(连杀数)/6`（**只有 multiplier 窗口的 1/6**）；窗口长度在**每次**连杀数变化时都会重置。
- **但是 `InitLists` 只调用了 `AddToMultipliers`，从头到尾没有一处调用 `AddToMultipleKills`**：
  - 定义：`__Packages/World/CUpgrades.as:488-493`
  - 全树（两个 build、raw + linearized）grep `AddToMultipleKills` 只有这一个**定义**，零调用。
  - 因此 `mMultipleKills` 永远是空数组，`_loc2_` 是 `undefined`，`for...in undefined` 在 AS2 里静默跳过。
- **结论（事实）**：**multiple-kill 在 2Play 里不发放任何升级**，它只驱动 HUD 的连杀进度条
  （数据源 `mMultipleKillRatio`，`:552-555`；HUD 侧 `[MoreRooms] __Packages/World/CHud.as:705`
  的表达式里含 `this.mWorld.mUpgrades.<X>()`，成员名加密，推断为倍率/连杀比例）与刷怪掉落的判定（见 9.4）。
  重制版如果要做「连杀奖励」，需要自己设计表（`mMultipleKills` 是预留接口）。

### 9.3 multiplier 完整掉落表（事实，`__Packages/World/CUpgrades.as:403-460`）

格式：`multiplier` → 目标类.属性，HUD 文案。

| multiplier | 目标 | 效果 | HUD 文案 |
|---|---|---|---|
| 3 | `CThing_Weapon_Pistol` | `FastFire` | Pistol+: Fast Fire |
| 5 | `CThing_Creature_Player` | `NW_uzi = "uzi"` | New Weapon: UZI (Key 2) |
| 8 | `CThing_Weapon_Pistol` | `DoubleDamage` | Pistol+: Double Damage |
| 10 | `CThing_Creature_Player` | `NW_shotgun = "shotgun"` | New Weapon: Shotgun (Key 3) |
| 13 | `CThing_Weapon_UZI` | `RapidFire` | UZI+: Rapid Fire |
| 15 | `CThing_Creature_Player` | `NW_barrel = "barrel"` | New Weapon: Barrel (Key 4) |
| 17 | `CThing_Weapon_UZI` | `DoubleAmmo` | UZI+: Double Ammo |
| 18 | `CThing_Weapon_Shotgun` | `FastFire` | Shotgun+: Fast Fire |
| 20 | `CThing_Creature_Player` | `NW_grenade = "grenade"` | New Weapon: Grenade (Key 5) |
| 21 | `CThing_Weapon_Shotgun` | `DoubleAmmo` | Shotgun+: Double Ammo |
| 23 | `CThing_Weapon_UZI` | `LongShot` | UZI+: Long Shot |
| 26 | `CThing_Weapon_Barrel` | `DoubleAmmo` | Barrel+: Double Ammo |
| 30 | `CThing_Creature_Player` | `NW_fakewall = "fakewall"` | New Weapon: Fake walls (Key 6) |
| 31 | `CThing_Weapon_Shotgun` | `WideShot` | Shotgun+: Wide Shot |
| 32 | `CThing_Object_Barrel` | `BigBang` | Barrel+: Big Bang |
| 33 | `CThing_Weapon_Grenade` | `ClusterExplode` | Grenade+: Cluster Explode |
| 35 | `CThing_Weapon_Shotgun` | `LongShot` | Shotgun+: Long Shot |
| 36 | `CThing_Weapon_Barrel` | `QuadAmmo` | Barrel+: Quad Ammo |
| 37 | `CThing_Weapon_FakeWall` | `DoubleAmmo` | Fake Wall+: Double Ammo |
| 39 | `CThing_Weapon_UZI` | `QuadAmmo` | UZI+: Quad Ammo |
| 40 | `CThing_Creature_Player` | `NW_mine = "mine"` | New Weapon: Claymore (Key 7) |
| 41 | `CThing_Weapon_Shotgun` | `QuadAmmo` | Shotgun+: Quad Ammo |
| 42 | `CThing_Weapon_Grenade` | `DoubleAmmo` | Grenade+: Double Ammo |
| 43 | `CThing_Weapon_Shotgun` | `RapidFire` | Shotgun+: Rapid Fire |
| 44 | `CThing_Object_Barrel` | `BiggerBang` | Barrel+: Bigger Bang |
| 45 | `CThing_Weapon_Grenade` | `BigBang` | Grenade+: Big Bang |
| 47 | `CThing_Object_Mine` | `ClusterExplode` | Claymore+: Cluster Explode |
| 48 | `CThing_Weapon_UZI` | `DoubleDamage` | UZI+: Double Damage |
| 50 | `CThing_Creature_Player` | `NW_rocket = "rocket"` | New Weapon: Rocket (Key 8) |
| 51 | `CThing_Weapon_Shotgun` | `WiderShot` | Shotgun+: Wider Shot |
| 52 | `CThing_Weapon_Grenade` | `QuadAmmo` | Grenade+: Quad Ammo |
| 53 | `CThing_Weapon_FakeWall` | `QuadAmmo` | Fake Wall+: Quad Ammo |
| 54 | `CThing_Weapon_Mine` | `DoubleAmmo` | Claymore+: Double Ammo |
| 55 | `CThing_Creature_Player` | `NW_chargepack = "chargepack"` | New Weapon: Chargepack (Key 9) |
| 56 | `CThing_Weapon_Shotgun` | `DoubleDamage` | Shotgun+: Double Damage |
| 57 | `CThing_Weapon_Grenade` | `BiggerBang` | Grenade+: Bigger Bang |
| 58 | `CThing_Object_Mine` | `BigBang` | Claymore+: Big Bang |
| 59 | `CThing_Weapon_Rocket` | `FastFire` | Rocket+: Fast Fire |
| 61 | `CThing_Weapon_UZI` | `InfinateRange` | UZI+: Infinate Range |
| 62 | `CThing_Object_Mine` | `BiggerBang` | Claymore+: Bigger Bang |
| 63 | `CThing_Object_ChargePack` | `ClusterExplode` | Charge Pack+: Cluster Explode |
| 64 | `CThing_Weapon_Mine` | `QuadAmmo` | Claymore+: Quad Ammo |
| 66 | `CThing_Weapon_Rocket` | `DoubleAmmo` | Rocket+: Double Ammo |
| 68 | `CThing_Weapon_ChargePack` | `DoubleAmmo` | Charge Pack+: Double Ammo |
| 70 | `CThing_Creature_Player` | `NW_railgun = "railgun"` | New Weapon: Railgun (Key 0) |
| 72 | `CThing_Weapon_Rocket` | `BigBang` | Rocket+: Big Bang |
| 74 | `CThing_Object_ChargePack` | `BigBang` | Charge Pack+: Big Bang |
| 76 | `CThing_Weapon_ChargePack` | `QuadAmmo` | Charge Pack+: Quad Ammo |
| 78 | `CThing_Weapon_Railgun` | `FastFire` | Railgun+: Fast Fire |
| 80 | `CThing_Weapon_Railgun` | `DoubleAmmo` | Railgun+: Double Ammo |
| 85 | `CThing_Weapon_Rocket` | `QuadAmmo` | Rocket+: Quad Ammo |
| 90 | `CThing_Weapon_UZI` | `QuadDamage` | UZI+: Quad Damage |
| 95 | `CThing_Object_ChargePack` | `BiggerBang` | Charge Pack+: Bigger Bang |
| 100 | `CThing_Weapon_Railgun` | `RapidFire` | Railgun+: Rapid Fire |
| 105 | `CThing_Weapon_Rocket` | `BiggerBang` | Rocket+: Bigger Bang |
| 110 | `CThing_Weapon_Railgun` | `QuadAmmo` | Railgun+: Quad Ammo |
| 120 | `CThing_Weapon_Rocket` | `RapidFire` | Rocket+: Rapid Fire |
| 125 | `CThing_Weapon_Railgun` | `LongShot` | Railgun+: Long Shot |

> 注意 **105 / 110 / 120 / 125 四个档位在单局里永远拿不到**：multiplier 每杀 +1、且被钳在 999，
> 但 100 级之后不再有新的怪物配额增长，而 multiplier 在一关里能涨到多少取决于该关杀敌数
> （例如 100 级 530 只怪 → multiplier 理论上能到 ~500+，实际会不会维持住取决于 10 秒不杀就衰减的窗口）。
> 另外 `mMultipliers[tIndex]` 用的是**稀疏数组下标**，`tIndex` 就是倍率值本身。

### 9.4 掉落触发（事实）

```as2
// __Packages/World/CWorld.as:200-226 LogKill（2Play，成员名加密但数值与调用形态完整）
case "CThing_Creature_Zombie":
    mUpgrades.mZombieCount = mUpgrades.mZombieCount - 1;
    if(mUpgrades.mMultipleKill % 5 == 0) this.<DropPickup>(tThing.mPosition);      // :207
    break;
case "CThing_Creature_Devil":
    mUpgrades.mDevilCount = mUpgrades.mDevilCount - 1;
    this.<DropPickup>(tThing.mPosition);                                          // :214 必掉
    break;
case "CThing_Creature_Player":
    ... 玩家死亡数 +1；若 mGameMode == "DeathMatch" 才掉落 ...                      // :216-223
    return;
...
mHud.AddScore(GetScreenPosition(tThing.mPosition), tThing.mScore * mUpgrades.mMultiplier);  // :225
```
MoreRooms 可读版完全一致：`[MoreRooms] __Packages/World/CWorld.as:366-397`
（`:373` `if(this.mUpgrades.mMultipleKill % 5 == 0)`、`:391-393` 生成 Pickup 并 `SetDeleteCounter(CMain.mFPS * 10)`）。

**掉落规则总结**：
- **僵尸**：每 **5 连杀**（`mMultipleKill % 5 == 0`）掉 1 个补给。
- **恶魔**：**每只必掉** 1 个补给。
- **玩家死亡**：仅 DeathMatch 模式掉落。
- 掉落点必须是**非静态障碍**格：`__Packages/World/CWorld.as:230`
  （`([cell].mCollide & mCollide_StaticImpassable) == 0`，MoreRooms `:389`）。
- 掉落物生命期：`SetDeleteCounter(CMain.mFPS * 10)` = **250 tick = 10 秒**（`__Packages/World/CWorld.as:234`，MoreRooms `:393`）。
- 得分：`mScore × mMultiplier`（`:225`）。僵尸 `mScore = 100`、恶魔 `mScore = 1000`（都是事实，见 §4.2 / §3.1）。

---

## 10. `GetTicks(index)` 计时公式核对与秒数换算

### 10.1 源码（事实）

```as2
// __Packages/World/CUpgrades.as:585-590
_loc2_.GetTicks = function(index) {
    index = 100 - ((index <= 100 ? index : 100) - 1);
    var _loc1_ = Math.pow(index, 2.5) / 100000.00000000003 * (CMain.mFPS * 3 - 3) + 3;
    return _loc1_;
};
```

用户给的式子**完全正确**，等价写法：

```
i'    = 100 - (min(index, 100) - 1) = 101 - min(index, 100)
ticks = i'^2.5 / 100000.00000000003 * 72 + 3          // CMain.mFPS = 25 → 25*3-3 = 72
秒     = ticks / 25
```

`100000.00000000003` 是浮点常量（不是 100000 整），差异量级 3e-16，可忽略。

### 10.2 换算表（关键值）

| index | `i'` | ticks | **秒** | 用途 |
|---|---|---|---|---|
| 1 | 100 | 75.000 | **3.000** | multiplier=1 的衰减窗口 |
| 2 | 99 | 73.214 | 2.929 | |
| 3 | 98 | 71.454 | 2.858 | 第一个掉落（Pistol FastFire） |
| 5 | 96 | 68.015 | 2.721 | 第二个掉落（UZI） |
| 10 | 91 | 59.877 | **2.395** | 困难难度开局倍率 |
| 20 | 81 | 45.515 | 1.821 | |
| 25 | 76 | 39.255 | **1.570** | |
| 30 | 71 | 33.600 | 1.344 | 难度 3 开局倍率 |
| 50 | 51 | 16.374 | **0.655** | |
| 75 | 26 | 5.482 | 0.219 | |
| 100 | 1 | 3.001 | **0.120** | 上限（index ≥100 全按 100 算） |
| 999 | 1 | 3.001 | 0.120 | setter 钳位到 999，但 GetTicks 内部再钳到 100 |

**解释**：
- 函数把「倍率/连杀序号」映射成**反比的等待时间**：序号越小（1）等待越长（3 s），序号越大等待越短。
- `100` 这个魔数意味着**第 100 档就是最短窗口 3 tick = 0.12 s**；`index > 100` 被钳到 100，不再变短。
- 曲线是幂律 `i'^2.5`：窗口在 1→50 段从 3.0 s 掉到 0.655 s，在 50→100 段从 0.655 s 掉到 0.12 s。
- **multiple-kill 用 `GetTicks(index)/6`**（`:534`）：index 1 → 12.5 tick = **0.5 s**；index 5 → 11.34 tick ≈ 0.453 s；
  index 100 → 0.5 tick = 0.02 s。窗口更短，所以连杀奖励理论上更苛刻（但表是空的，见 9.2）。
- `mMultiplierTickRatio`（`:581-584`）与 `mMultipleKillRatio`（`:552-555`）就是给 HUD 进度条用的
  `剩余 tick / 总 tick`（倍率为 1 或连杀为 0 时返回 0，即不显示）。

### 10.3 计时器的实际运行方式

```as2
// __Packages/World/CUpgrades.as:68-75（每逻辑 tick）
if(this.mMultipleKillsTick-- < 0) this.mMultipleKill = 0;
if(this.mMultiplierTick-- < 0)    --this.mMultiplier;
```
- 用**后置自减**：先比较再减 1，所以窗口是 `ticks + 1` 次 `Process` 调用（±1 tick 的误差）。
- `--this.mMultiplier` 会走 setter，**顺带把 `mMultiplierTick` 重置成新档的窗口**（`:559`），
  于是衰减到 1 之后窗口会被重置为 `GetTicks(1)` = 3 s，而 `Process` 里仍然每 tick 检查一次 —— multiplier 停在 1 不会继续掉。
- `mMultipleKill = 0` 走 setter 的 `else` 分支，把 tick 置为 `100000`（`:544`），等于「关闭」。

---

## 11. 拾取物、回血与作弊开关

### 11.1 拾取物本体（2Play 干净文件）

`__Packages/Thing/Object/CThing_Object_Pickup.as`（111 行 / 0 记号）：

| 行为 | 值 / 机制 | 出处 |
|---|---|---|
| 触发 | 所在格 `mCollide & mCollide_Player` 就调用 `PickedUp()` | `:41-47` |
| 拾取效果 | 找到格内 `CThing_Creature_Player`，若其 `mFlags & mFlag_DEAD` 则忽略；否则调 `player.RandomPickup()` | `:77-87` |
| 音效 | `CSound.mSamples.Object_Pickup_wav` | `:88` |
| 一次性补给（空投） | 若 `mDeleteOnPickup` → 直接 `Delete()` | `:89-93` |
| 地图固定补给点 | 否则从地图上摘掉，`mReappearCount = CMain.mFPS * (mGameMode != "DeathMatch" ? 30 : 10)` → **750 tick = 30 s** 后重新出现（DeathMatch 为 **10 s**） | `:94-96` |
| 消失倒计时 | `mDeleteCounter`，每 tick -1；最后 1 秒（`< CMain.mFPS`）做渐隐 `mAlpha = counter / mFPS * 100` | `:61-76` |
| 空投补给生命期 | 由掉落方设为 `CMain.mFPS * 10` = **10 s** | `__Packages/World/CWorld.as:234` |

### 11.2 `RandomPickup()`：随机抽奖与回血规则

`RandomPickup` 在 `CThing_Creature_Player.as` 里（成员名加密）。**结构**（`:387-429`）：

1. 收集所有**已解锁且弹药未满**的武器（`:393-402`）：
   权重 = `(1 - 当前弹药/总弹药) * 0.75 + 0.25`
   → 式子可读：`:398` `_loc8_ = (1 - _loc4_[228][240] / _loc4_[228][241]) * 0.75 + 0.25;`
2. 若**当前生命 < 最大生命**，追加一个"回血"条目（`:403-408`）：
   权重 = `(1 - 生命/最大生命) * 已有权重总和`
   → 式子可读：`:405` `_loc8_ = (1 - this[127] / this[126]) * _loc5_;`
   （`[126]`/`[127]` 由 `:213` 与 `[MoreRooms] :577` 的逐字相同公式确定为 `mMaxLife`/`mLife`）
3. `_loc6_ = Math.random() * 总权重`，按累积权重轮盘选中一项（`:409-427`）。
4. 若抽中回血：`this[127] = this[126];` → **直接把生命补满（不是加固定值）**（`:415-419`）。
5. 若抽中武器：调用 `this[232](武器名)` = `NewWeapon(name)`（`:422`、`:430-439`）
   → `NewWeapon` 会**销毁并重建**该武器对象，等于**把该武器弹药重置为它的出厂值（满弹）**。

> **结论**：补给的回血是「**回满**」，不是固定数值；弹药补给是「**把某一种武器弹药补满**」，
> 具体补多少 = 该武器 `Process_Init` 的默认 `mTotalAmmo`（见武器文档，不在本文范围）。
> 抽奖权重让「越缺血越容易抽到回血、越缺弹越容易抽到武器」。
> 血满时**只**会抽到武器（回血条目不加权），且「血满 + 全武器满弹」时总权重为 0 —— 此时 `Math.random()*0 = 0`，
> 首个累积值必然 > 0，行为等价于按列表顺序取第一个（推断）。

### 11.3 作弊 / 调试开关

下表的行号是 **`frame_1/DoAction.as`（linearized 树）**；这些全局赋值在原始树里位于同一文件的第 152-157 行，两处内容一致。

| 开关 | 默认 | 出处 | 在代码里的作用 |
|---|---|---|---|
| `_global.mDebug` | `false` | `frame_1/DoAction.as:22`（原始树第 152 行） | ① `CMain` 直接从 `State_SelectWorld` 起步跳过片头（`[MoreRooms] __Packages/CMain.as:71`，可读）；② `CUpgrades.Process:65-67` 有一个空分支（原意应是 Debug 下的额外行为）；③ ⚠️ **不**影响玩家免伤（那是 `mInfinateLife` 的分支），也**不**影响关卡解锁（那是 `mHostedOnCMG`） |
| `_global.mInfinateLife` | `false` | `frame_1/DoAction.as:24`（原始树第 154 行） | ✅ **已确证**：`__Packages/Thing/Creature/CThing_Creature_Player.as:147-149` —— `if(_global.mInfinateLife) { Affect_Setup(mAffect_PlayerLineOfSight); }`，即**只保留视线检测、免疫一切伤害**（等价于无敌）。`resolved\` 树给出了成员名 |
| `_global.mCheat_OneZombie` | `false` | `frame_1/DoAction.as:26`（原始树第 156 行） | **确证**：`__Packages/World/CUpgrades.as:371` `var _loc4_ = !_global.mCheat_OneZombie ? 10 : 1;` → 每关僵尸总配额从 `5L+5` 变成 **1**（且因为 `_loc5_ += 5` 仍在跑，第 2 关起又恢复 15、20…，**只影响第 1 关**；推断） |
| `_global.mCheatsActive` | `false` | `frame_1/DoAction.as:27`（原始树第 157 行） | 只出现在 `CUpgrades.Process:65` 的空分支里，**未发现实际效果** |
| `_global.mRecordMode` | `false` | `frame_1/DoAction.as:25`（原始树第 155 行） | 录像/回放模式开关（`frame_1/DoAction.as:48` 读取），与数值无关 |

> 顺带更正一处早期猜测：`__Packages/Thing/Creature/CThing_Creature.as:354` 里的 `_root[§§constant(159)] != §§constant(160)`
> **不是** `mInfinateLife`，`resolved\` 树显示它是 `_root._quality != "LOW"`（画质判断），
> 而且那一行算的是尸体的 `mAlpha` 淡出，不是生命百分比。

其他启动期全局（同处，供参考）：`_global.mCrazyMonkeyGames = true`、`_global.mAllowLocalHost = false`、
`_global.mHostedOnCMG`（按日期/域名判定）、`_global.mProduct.*`（版本串）。

---

## 12. 给 Godot 重制的落地建议（按本文事实整理）

```gdscript
# 1) 逻辑频率
const TICK := 0.04          # 25Hz = CMain.mFPS，见 §1.1

# 2) 敌人/玩家基础值
const PLAYER_MAX_LIFE := 200      # 事实
const PLAYER_SPEED    := 0.16     # 格/tick，事实
const PLAYER_REGEN_PER_TICK := PLAYER_MAX_LIFE / (25.0 * 30.0)   # 0.2667，事实
const PLAYER_DEAD_TICKS   := 100  # 4s 尸体（基类 State_Dead_Init），事实
const PLAYER_RESPAWN_WAIT := 25   # 1s 等待（State_Respawn），事实
const PLAYER_RESPAWN_INVULN := 125  # tick（DeathMatch 为 25），事实

const ZOMBIE_LIFE   := 100   # 常量池恢复：基类 CThing_Creature.as:41，僵尸不覆写
const ZOMBIE_DAMAGE := 50    # 常量池恢复：CThing_Creature_Zombie.as:61
const ZOMBIE_SPEED_BASE  := 0.02  # 常量池恢复：:56
const ZOMBIE_SCORE  := 100   # 常量池恢复：:59
const ZOMBIE_HEIGHT := 1.5   # 常量池恢复：:60
const ZOMBIE_MASS   := 1     # 基类 ctor（CThing_Creature.as:21），僵尸不覆写
const ZOMBIE_ATTACK_RECOVER := 10 # tick = 0.4s，常量池恢复：:119
const ZOMBIE_RADIUS := 0.45       # 基类 SetRadius（僵尸文件里没有 SetRadius）

const DEVIL_LIFE    := 1000  # 事实
const DEVIL_DAMAGE  := 50    # 事实（火球打人）；拆物 10000，拆墙 100000
const DEVIL_SPEED_BASE := 0.04
const DEVIL_ATTACK_RANGE := 5      # 格
const DEVIL_MASS := 5
const DEVIL_FIRE_RATE := 0         # 每次攻击动画都能开火
const DEVIL_FIRST_SHOT_DELAY := 5  # tick
const DEVIL_RADIUS := 0.42
const DEVIL_HEIGHT := 1.8
const DEVIL_SCORE  := 1000
const FIREBALL_SPEED := 0.15       # 格/tick
const FIREBALL_RADIUS_PLAYER := 0.25
const FIREBALL_RADIUS_OBJECT := 1.0

# 3) 升级乘数（只 SpeedUp 有效）
func speed_up(level: int) -> float: return min(1.0 + level / 10.0, 5.0)

# 4) 1..100 级曲线（闭式，见 §7.2）
func zombie_spawn_rate(l): return max(26 - l, 1)
func zombie_count(l):      return min(5 * l + 5, 60)
func zombie_total(l):      return 5 * l + 5
func devil_spawn_rate(l):  return max(251 - l, 25)
func devil_count(l):       return 0 if l == 1 else min(int(1 + 0.3 * (l - 2)), 5)
func devil_total(l):       return 0 if l == 1 else int(floor(1 + 0.25 * (l - 2)))

# 5) 计时（事实，见 §10）
func get_ticks(index: int) -> float:
    var i := 100.0 - (min(index, 100) - 1)
    return pow(i, 2.5) / 100000.00000000003 * (25.0 * 3.0 - 3.0) + 3.0

# 6) 难度（事实，见 §6.1）
const DIFFICULTY := {0: {"level": 1, "mult": 1},
                     1: {"level": 10, "mult": 10},
                     2: {"level": 20, "mult": 30},
                     3: {"level": 35, "mult": 50}}
```

---

## 13. 未恢复项总表（常量池还原后已大幅清空）

### 13.1 已由 `resolved\` 常量池还原解决的项 ✅

| # | 原未恢复内容 | 结论 | 出处 |
|---|---|---|---|
| 1 | 僵尸的成员名 ↔ 字面量映射 | **全部恢复**：`mSpeed=0.02` / `mSetState(State_EnterMap)` / `mBrain_Count=mUniqueID%3` / `mScore=100` / `mHeight=1.5` / `mDamage=50` | `CThing_Creature_Zombie.as:56-65` |
| 2 | 僵尸血量 | **100**（基类，僵尸不覆写：该文件 0 处 `mLife`/`mMaxLife`） | `CThing_Creature.as:41` |
| 3 | 僵尸半径 / 质量 | **0.45 / 1**（僵尸文件里 0 处 `SetRadius`/`mRadius`/`mMass`） | `CThing_Creature.as:35`、`:21` |
| 4 | 关卡选择三个 19 元素数组的语义 | **`Single_Exclusives` / `Coop_Exclusives` / `DeathMatch_Exclusives`**，按游戏模式区分（不是难度） | `CScreen_SelectWorld.as:478`/`:498`/`:518`，判定见 `:126-131` |
| 5 | `_global.mInfinateLife` 的读取点 | **确证**：`if(_global.mInfinateLife) { Affect_Setup(mAffect_PlayerLineOfSight); }` → 免疫一切伤害 | `CThing_Creature_Player.as:147-149` |
| 6 | `CThing_Affect_*Attack` 内部成员名 | **还原**：`AffectThing(tThing) { tThing[mLife] -= this[mDamage]; return this[mDamage]; }`；`DevilAttack` 另有 `mHitDirection` | `CThing_Affect_ZombieAttack.as:14-22`、`CThing_Affect_DevilAttack.as:15-22` |
| 7 | `CThing_Object_Barrel` 血量 | **`mMaxLife = mLife = 1`**（任何伤害一击即爆）；爆炸伤害 `mDamage` 默认 **100** | `CThing_Object_Barrel.as:45`、`:25` |
| 8 | `CThing_Creature.as:354` 的 `_root[§§constant(159)]` | 是 **`_root._quality != "LOW"`**（画质判断），与 `mInfinateLife` 无关；该行是 `State_Dead` 的淡出 alpha，不是生命百分比 | `CThing_Creature.as:354` |
| 9 | 死亡动画时长里被加密的类名 `§§constant(156)` | 是 **`CThing_Creature_Player`**（玩家尸体 4 s，其他 2 s） | `CThing_Creature.as:346` |
| 10 | 玩家 `[140]` / `[192]` / `[137]` 等槽位 | 分别是 **`mInvincible`**、`mStateCount`、**`State_PlayerControl`** | `CThing_Creature_Player.as:188`、`:310`、`:209` |
| 11 | 2Play 是否调用 `CUpgrades.SetDifficulty` | **不调用**（全树 grep 只有定义；`resolved\` 树确认 `Process_Init:186-188` 无此句）→ 2Play 里难度选项不影响数值 | `CThing_Creature_Player.as:186-188` |

### 13.2 仍然未恢复的项 ❌

| # | 未恢复内容 | 已尝试路径 | 影响 |
|---|---|---|---|
| 1 | 2Play `CSaveData` 约 30 个属性的**名字与默认值**（含 `mDevilsActive` / `mCollisionsActive` / `mDamageActive` / `mGameSpeed` / `mGameAmount` / 键位） | 读 2Play `CSaveData.as`（481 行 / 808 记号）；`resolved\` 树对该文件**未能还原**（`:425-481` 仍是 `§§constant(N)`）；读 MoreRooms 干净版（只有 6 个属性）；读 `CScreen_Debrief.as:1038`、`CScreen_Debrief_Winner.as:39`、`CUpgrades.as:387`；查原始树字符串常量池 | `mDevilsActive` 是恶魔表的开关（事实：`CUpgrades.as:387`）；**其默认值未恢复**。默认值里有 3 个 `true`、多个 `1`（`CSaveData.as:431-447`），推测对应三个"公平性"开关为开，但无法证实 |
| 2 | `CMain.mFPS` 在 2Play 里的静态槽位名 | `resolved\` 树对该文件也未还原（`:288`/`:314` 仍是 `[§§constant(34)] = 25` / `[§§constant(44)] = 25`）；改用 `[MoreRooms] CMain.as:188` 的明文 `mFPS = 25` 交叉确认（且 `resolved\` 树里 `CThing_Creature_Player.as:213` 明写 `eval(CMain)[mFPS]`，证明成员名就是 `mFPS`） | 数值 25 已确证，只是 2Play 那两处静态赋值无法一一对应到名字 |
| 3 | MoreRooms 僵尸是否真的改成 1000 血 | 见 §4.3 的三条证据 + 2Play 真值对照 | 若使用 MoreRooms 数值需另行验证；本文档以 2Play 为准 |
| 4 | 原版 `random(4)` 每次调用是否消耗同一个随机序列 | 读两个音效赋值行（`:63`/`:64` 各调一次 `random(4)`） | 影响仅限音效随机性，不影响数值 |

---

## 14. 一句话速查

- **逻辑 25Hz，1 tick = 40ms。**
- **玩家**：200 血、0.16 格/tick、每 tick 回 0.2667 血（30 秒回满）、死亡 4 s 尸体 + 1 s 等待、重生无敌 5 秒（死斗 1 秒）、重生后弹药全满只留手枪。
- **僵尸**：100 血、50 伤、0.02 格/tick、半径 0.45、身高 1.5、质量 1、**100 分**、攻后收招 10 tick（0.4 s）、按 `mUniqueID % 3` 分 3 组。全部为常量池恢复后的**事实**。
- **恶魔**：1000 血、50 伤火球（弹速 0.15）、0.04 格/tick、射程 5 格、半径 0.42、身高 1.8、1000 分。
- **成长**：只有 `SpeedUp = min(1+L/10, 5)`，40 级封顶；恶魔最终 0.20 格/tick（比玩家 0.16 快）。
- **刷怪**：僵尸间隔 `max(26-L,1)` tick、总数 `5L+5`、同屏 `min(5L+5,60)`（LOW 画质 40）；恶魔间隔 `max(251-L,25)` tick、总数 `floor(0.25L+0.5)`、同屏上限 5。
- **过关**：场上无敌人 **且** 僵尸配额 ≤0 **且** 恶魔配额 ≤0。
- **升级**：靠 multiplier（每杀 +1，窗口 `GetTicks(m)`：m=1 时 3.0 s，m=50 时 0.655 s，m≥100 时 0.12 s），共 60 档奖励，绝大多数是武器强化，武器在 5/10/15/20/30/40/50/55/70 九个档位解锁。
- **连杀（multiple-kill）表是空的**，不发放任何奖励，只影响 HUD 与「每 5 连杀掉一个补给」。
- **难度在 2Play 里不生效**（`SetDifficulty` 从未被调用），但是映射表和 UI 都在；重制时按 §6.1 自行接上。
- **补给**：僵尸每 5 连杀掉 1 个、恶魔每只必掉；血包回**满血**，弹药包把某武器补满；地图固定补给点 30 秒刷新（死斗 10 秒），空投 10 秒消失。
- **油桶**：`mMaxLife = 1`（一击即爆），爆炸伤害默认 100。
