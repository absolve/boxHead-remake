# 01 · 敌人 AI 与刷怪机制

> 逆向对象：`oldGame/Boxhead_2Play.swf`（Flash 8 / AS2，640×480，63 帧，50 fps）
> 版本串：`Boxhead: 2Play Rooms: Final.1.00110 (16/05/2007 22:37)`，© Sean Cooper 2007
> 旁证：`oldGame/boxheadmorerooms.swf`（同引擎 scidd 的另一版）
> 本文所有 `路径:行号` 均相对 `oldGame/_decompiled/Boxhead_2Play/linearized/`（旁证相对 `oldGame/_decompiled/MoreRooms/linearized/`）。

---

## 0. 证据等级说明（务必先读）

本文把每条结论的来源分成四档，正文逐条标注：

| 标记 | 含义 |
| --- | --- |
| **【直读】** | linearized 文件本身没有任何加密记号（既无 `§§constant(N)` 也无 `invalid_utf8=`），成员名与数值都能直接读到。 |
| **【常量池恢复】** | linearized 文件里成员名是 `§§constant(N)`、字符串是 `{invalid_utf8=..}`。我用 SWF 的 AS2 常量池把索引还原成了真实名字。 |
| **【推断】** | 我的解释/推导，代码里没有直说。 |
| **【未恢复】** | 试过但读不到。 |

### 0.1 「常量池恢复」是怎么做的（重要，影响可信度判断）

原始反编译产物里，加密类的每个成员访问都长成 `this[§§constant(5)]`。
`§§constant(N)` 是 **FFDec 对 AS2 `ActionPush` 的 `constant8/constant16` 类型常量的占位**，其 `N` 就是该
`DoInitAction` 块内 `ActionConstantPool`（操作码 `0x88`）的数组下标。该常量池**明文存在 SWF 字节码里**，
因此可以直接解析出来（`DoInitAction` tag 载荷前 2 字节是 sprite id，之后是动作流）：

* 已对两个 SWF 逐个 `DoAction(12)` / `DoInitAction(59)` 脚本块扫描 `0x88`，2Play 得到 116 个候选池、
  MoreRooms 得到 1765 个候选池。
* 文件→池的配对不靠猜：要求池头严格等于 `_global, <包路径第1段>, Object, <包路径其余段>, <类名>`
  （这一结构对 100+ 个池都成立，例如 `CThing_Creature` 池头是
  `_global / Thing / Object / Creature / CThing_Creature`）。
* 再用「占用下标上界 = 池长度 - 1」做二次校验。

自校验（可作为该方法正确性的证据）：`CThing_Creature` 池还原后，
下标 5 = `mFlags`、6 = `CThing`、7 = `mFlag_Collidable`，而代码是
`this[§5] = ... [§6][§7]` → 还原为 `this.mFlags = CThing.mFlag_Collidable`，
与已知基类事实**完全吻合**（`__Packages/Thing/CThing.as:139`）。类似地 `Zombie` 池还原出
`mSpeed / mDamage / mScore / mHeight / mBrain_Count` 等成体系字段。因此判定该还原是可靠的。

各关键文件的还原质量（clean = 占用下标中能还原成合法标识符的比例）：

| 文件 | 加密记号数 | 占用下标 | 下标上界 | 池长度 | clean | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| `__Packages/Thing/CThing.as` | 0 | — | — | — | — | 【直读】 |
| `__Packages/Thing/Creature/CThing_Creature_Devil.as` | 0 | — | — | — | — | 【直读】 |
| `__Packages/World/CUpgrades.as` | 0 | — | — | — | — | 【直读】 |
| `__Packages/Thing/Creature/CThing_Creature.as` | 709 | 184 | 185 | 186 | 0.995 | 【常量池恢复】完整 |
| `__Packages/Thing/Creature/CThing_Creature_Zombie.as` | 286 | 114 | 117 | 118 | 1.000 | 【常量池恢复】完整 |
| `__Packages/Thing/Creature/CThing_Creature_Player.as` | 899 | 268 | 271 | 272 | 0.978 | 【常量池恢复】完整 |
| `__Packages/World/CWorld.as` | 986 | 282 | 282 | 283 | 0.986 | 【常量池恢复】完整 |
| `__Packages/Thing/CThing_Collection.as` | — | 50 | 54 | 55 | 1.000 | 【常量池恢复】完整 |
| `__Packages/World/Map/CMap_Cell.as` | 2740 | 176 | 178 | 179 | 1.000 | 【常量池恢复】完整 |
| `__Packages/World/Map/CMap_Mapwho.as` | — | 19 | 24 | 25 | 1.000 | 【常量池恢复】完整 |
| `__Packages/Thing/Affect/CThing_Affect_ZombieAttack.as` | — | 10 | 12 | 13 | 1.000 | 【常量池恢复】完整 |
| `__Packages/Thing/Affect/CThing_Affect_DevilAttack.as` | — | 12 | 13 | 14 | 1.000 | 【常量池恢复】完整 |
| `__Packages/World/Init/CWorld_Init_Zombie.as` | — | 7（含 1 处 trailer 垃圾） | 45 | 9 | 0.857 | 【常量池恢复】正文完整 |
| `__Packages/World/Init/CWorld_Init_Devil.as` | — | 9 | 8 | 9 | 1.000 | 【常量池恢复】完整 |
| `__Packages/Thing/Math/CThing_Navigation.as` | — | 24 | 58 | 24 | 0.792 | 文件头 4–8 行是**别的脚本的残片**，正文已还原 |
| `__Packages/World/Map/CMap_Navigation.as` | 522 | 174 | 282 | 12 | 0.069 | **该文件不含导航算法**：它是多个脚本块输出的合并容器，其中的 `CMap_Navigation` 是只有 12 项的**空壳类**（`mMap` / `prototype` / `toString` / `_CLASSID_` / `Dispose`）。真正的寻路在 `CMap_Cell`（pool 39，零越界，完整恢复）→ 见 [02-pathfinding.md](02-pathfinding.md) |
| `__Packages/Thing/Affect/CThing_Affect.as` | 2741 | 176 | 178 | 90 | 0.489 | **部分未恢复**，但 `mAffect_*` 常量值已完整取到 |
| MoreRooms `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Zombie.as` | 535 | — | — | — | — | **不能当旁证用**：该文件本身被加密（535 处记号），且混淆器嵌套的状态机默认不拆（残留 4 个 `while(true)` 骨架）。注意这不是"线性化失败"——工具对它成功且 token 校验通过，只是默认**保守地不拆嵌套**。 |

> ⚠️ 关于 MoreRooms 旁证：它的 `CWorld.as`（`[MoreRooms] __Packages/World/CWorld.as`，505 行，**【直读】**）
> 与 `CUpgrades.as` 是可用的干净旁证，我已用它交叉验证了 2Play 的刷怪逻辑（两者一致，见 §6.7）。
> 但 MoreRooms 的 `CThing_Creature_Zombie.as`（535 处加密记号）**不能用于补 2Play 的僵尸逻辑**。

> **复核补正（2026-10-16，上级复核时加入）**
> 上表里 `CMap_Navigation.as` 一行原写成「【未恢复】，寻路核心读不到」，这是**误判**，已改写。
> 复核结论：该文件是把多个脚本块输出合并在一起的容器（地图基类副本 + `CMap_Navigation` 空壳 +
> `scidd.Math.CMath` + 一个音效类），空壳类的池只有 12 项、不含任何算法方法。
> 寻路实现在 `CMap_Cell.as`（`Nav_Update` = 类静态 BFS 距离场，`Nav_Direction` = 每格梯度下降），
> 已由常量池完整还原并逐行复核。**本文其余结论不受此更正影响。**

---

## 1. 引擎侧前提：实体、格子与主循环

### 1.1 实体基类要点（【直读】`__Packages/Thing/CThing.as`）

| 事项 | 出处 |
| --- | --- |
| 构造：`mPosition`、`mAngle`、`mParent`、`mUniqueID = ++mAllocate_ID`、`sUniqueID = "t"+mUniqueID`、`mID = mParent != undefined ? mParent.mID : mUniqueID`、`mFlags = 0` | `__Packages/Thing/CThing.as:110` |
| 标志位：`mFlag_Collidable=1`、`mFlag_WaitForMove=2`、`mFlag_CellMoved=4`、`mFlag_Drawn=8`、`mFlag_SortFloor=16`、`mFlag_DEAD=32` | `:139` `:149` `:159` `:169` `:179` `:189` |
| `SetRadius(r)` → `mRadius = r; mRadius_SQR = r*r` | `:44` |
| `GrowRadius(r)`：每帧 +0.05，未达目标返回 true | `:49` |
| `Move(p)`：拷 x/y/z 后调 `mWorld.mMap.mMapwho.MoveThing(this)` | `:67` |
| `Affect_Setup(flags)`：`mAffectors = new Array(); mAffectFlags = flags` | `:77` |
| `Affect(a)`：`mAffectors.push(a)` | `:82` |
| `ClearAffects()`：`mAffectFlags = 0`（注意**不清空** `mAffectors`） | `:86` |
| `Delete()`：`delete this.Process; mThing_Collection.DeleteThing(this)` | `:62` |
| `Dispose()`：`mWorld.mMap.mMapwho.DeleteThing(this)` | `:40` |

### 1.2 地图格子（【常量池恢复】`__Packages/World/Map/CMap_Cell.as`）

* 格子像素尺寸 `mCellSize = 32`（`:703`），`mSize = Point(32,32)`（`:716`）。
* 相邻格数组 `mAdjacentCells`，并且有别名 `ac`（`:26`–`:29`，`this.ac = this.mAdjacentCells`）。
  **方向索引 0..7**，0=东，顺时针：0=E 1=SE 2=S 3=SW 4=W 5=NW 6=N 7=NE。
* 方向位掩码：`mDirection_E=1` `:976`、`SE=2` `:989`、`S=4` `:1002`、`SW=8` `:1015`、
  `W=16` `:1028`、`NW=32` `:1041`、`N=64` `:1054`、`NE=128` `:1067`。
* 格子碰撞位：

| 常量 | 值 | 出处 |
| --- | --- | --- |
| `mCollide_None` | 0 | `:729` |
| `mCollide_Solid` | 1 | `:742` |
| `mCollide_Ledge` | 2 | `:755` |
| `mCollide_Shot` | 4 | `:768` |
| `mCollide_Path` | 8 | `:781` |
| `mCollide_Road` | 16 | `:794` |
| `mCollide_Creature` | 32 | `:807` |
| `mCollide_Player` | 64 | `:820` |
| `mCollide_Object` | 128 | `:833` |
| `mCollide_EdgeOfMap` | 256 | `:846` |
| `mCollide_StaticImpassable` | 2\|1 = **3** | `:859` |
| `mCollide_NonShootable` | 1 | `:872` |
| `mCollide_NonMovable` | 3\|32\|128\|64 = **227** | `:885` |
| `mCollide_Moving` | 32\|64 = **96** | `:898` |
| `mCollide_NonMovablePlayer` | 227 | `:911` |
| `mCollide_NoSpawn` | 32\|128 = **160** | `:924` |
| `mCollide_Navigation` | 3\|128 = **131** | `:937` |

* 格子把落在里面的实体存在 `mObjects[sUniqueID]`：`AddThing` `:98`、`DeleteThing` `:93`。
* `CollideFlagsInDirection(d)`：偶数方向只取 `ac[d].mCollide`，奇数（斜向）方向额外 OR 上两侧格（`:115`–`:119`）。
* `NavReal_0..7`（`:507`–`:538`）是同一件事的手写展开：偶方向 1 格，斜方向 3 格。
* `Affect(tAffect)`：遍历本格 `mObjects`，当
  `obj.mAffectFlags & tAffect.mType && tAffect.mAffector.mID != obj.mID` 时调用 `obj.Affect(tAffect)`（`:103`–`:114`）。
  → **伤害判定是「整格命中」，不是圆/扇形的精细判定**；`mID` 不等是为了不误伤自己（子弹/武器挂在持有者 ID 上，见任务给定的基类事实）。

### 1.3 主循环节拍（【常量池恢复】`__Packages/CMain.as`）

* `CMain.mFPS` 是**逻辑帧率**（每秒世界 tick 数）：
  `mFPS = 25 * (mGameSpeed != 0 ? mGameSpeed : 0.5)`（`:181`–`:184`），`mGameSpeed ∈ {0=Slow,1=Normal,2=Fast}`，
  默认 `_GameSpeed = 1`（`__Packages/CSaveData.as:436`，`__Packages/Screen/CScreen_SelectWorld.as:216`–`:218`）。
* 主循环 `Process()` 每 SWF 帧算 `ProcessFrames(CMain.mFPS)` 得到本次要跑的 tick 数并循环调用世界 `Process`（`:29`–`:48`）。
  → **mFPS = 每个真实秒的逻辑 tick 数**。

**本文所有「帧」= 逻辑 tick。** 换算：`秒 = tick / mFPS`。默认 Normal 档 `mFPS = 25`，故 1 tick = 40 ms。
（SWF 头是 50 fps，`mFPS` 默认 25 —— 逻辑帧 ≠ 播放帧，不要混淆。）

### 1.4 世界 Process 顺序（【常量池恢复】`__Packages/World/CWorld.as:531`–`:546`）

```
CWorld.Process():
  if (暂停键被按) 切换 mPaused
  if (mPaused) return
  mThing_Collection.Process()   // 先跑所有 Thing
  mUpgrades.Process()           // 再跑刷怪节奏
  mHud.Process()
  mTick++
```

`CThing_Collection.Process()`（`__Packages/Thing/CThing_Collection.as:144`–`:169`）：
1. 三个时间片计数器自增：`mTimeSlice_25 % 25`、`mTimeSlice_8 & 7`、`mTimeSlice_4 & 3`（`:146`–`:148`）。
2. 先把 `mDeleteThings` 队列里的东西逐个 `Dispose()` 并删除（`:149`–`:154`）。
3. 遍历 `mThings` 逐个 `Process()`（`:155`–`:158`）。
4. `CMap_Cell.Nav_Restart()`（`:159`）。
5. 收集所有玩家的格子，`CMap_Cell.Nav_Update(玩家格列表)`（`:160`–`:168`）。

> 顺序要点：**导航距离场在敌人 Process 之后、基于玩家「本帧移动前」的格子重算**，
> 因此敌人用的是上一帧的玩家位置（【推断】）。

---

## 2. 感知：敌人怎么发现玩家（问题 1）

### 2.1 结论速览

| 敌人 | 感知方式 | 半径 / 角度 | 出处 |
| --- | --- | --- | --- |
| 僵尸 | **不用距离、不用视野角**，只看格子碰撞位 `mCollide_Player` | 8 方向邻居格（正向 1 格，斜向 3 格中任一）；1 格 = 32 px | `__Packages/Thing/Creature/CThing_Creature_Zombie.as:91`–`:96` |
| 恶魔 | 圆距离 + **严格 8 方向对齐** + 视线（LOS）射线 | 距离 ≤ `mAttackRange = 5` 格 = 160 px；方向必须完全等于 `atan2` 求出的方向 | `__Packages/Thing/Creature/CThing_Creature_Devil.as:66` `:147` `:151` |

**重要：敌人没有任何「发现/警觉」阈值，也没有搜索状态。** 二者只要在世界里就每一帧重算目标并朝玩家移动
（僵尸 `State_GotoPlayer` 每帧调 `Brain()`，`:84`–`:104`；恶魔同理 `:106`–`:108`），
不存在巡逻→发现→追击的过渡条件。可用「永远已知玩家位置」来描述。

### 2.2 玩家这一侧：玩家怎么「被看见」

玩家每逻辑帧把自己所在格标记为 `mCollide_Player`：

* `__Packages/Thing/Creature/CThing_Creature_Player.as:190`–`:193`
  `Process_Normal()` → `this.SetCollideDirection(this.mPosition, CMap_Cell.mCollide_Player)`。

`SetCollideDirection` 的实现（【常量池恢复】`__Packages/Thing/Creature/CThing_Creature.as:369`–`:375`）：

```as
SetCollideDirection(p, tCollideFlags) {
    this.mNewCell.mCollide &= ~tCollideFlags;   // 清掉自己上一次占用的格
    this.mNewCell_Flags = tCollideFlags;
    this.mNewCell = this.mMap.GetCell(p.mX, p.mY);
    this.mNewCell.mCollide |= this.mNewCell_Flags;   // 标记新格
}
```

**这是整套敌人感知的地基**：玩家的「可见性」= 自己格子上的那一个 bit。

### 2.3 僵尸的感知细节（【常量池恢复】，`__Packages/Thing/Creature/CThing_Creature_Zombie.as`）

`State_GotoPlayer`（`:84`–`:104`）每帧：

```
_loc2_ = this.mAngle.mDirection                       // 当前朝向（0..7）
this.mCurrentCell = mMap.mCells[mY & 0xFFFFFF][mX & 0xFFFFFF]
this.mTarget_Angle.mAngle = Math.atan2((target.Y & 0xFFFFFF)+0.5 - mY,
                                       (target.X & 0xFFFFFF)+0.5 - mX)
this.mTarget_Direction = this.mTarget_Angle.mDirection
_loc3_ = this.mCurrentCell["NavReal_" + this.mTarget_Direction]()
if (_loc3_ & CMap_Cell.mCollide_Player)  →  进入攻击（见 §4.2）
```

* 传入 `atan2` 的是**格子整数+0.5**，即目标格中心、且格坐标被 `& 0xFFFFFF` 取整（`:89`）。
* `NavReal_d`：`d` 为偶数 → 相邻 1 格；`d` 为奇数（斜向）→ 本格 + 两侧格共 3 格（`CMap_Cell.as:507`–`:538`）。
* 因此僵尸的有效「视野」= 以自身为中心、朝玩家方向的那 1（或 3）个格子。由于它还要求 `mTarget_Direction`
  正好是朝玩家的方向，**等价于「玩家在我 8 邻格内」**（【推断】）。

僵尸**没有视线遮挡判定**：隔着墙也照样进入攻击状态，只是攻击动作打在墙上（`CMap_Cell.Affect` 只作用在
那一格里已有的对象）。

### 2.4 恶魔的感知细节（【直读】，`__Packages/Thing/Creature/CThing_Creature_Devil.as`）

`State_Attack_Decision()`（`:136`–`:161`），四个条件全部满足才算「看见」：

| # | 条件 | 代码 | 行号 |
| --- | --- | --- | --- |
| 1 | 冷却已好且未被禁用 | `if (!this.mCanAttack \|\| this.mFireRateCount > 0) return false;` | `:138` |
| 2 | 目标还活着 | `if (this.mTarget_Player.mLife <= 0) return false;` | `:142` |
| 3 | 朝向与目标方向**完全相等** | `if (this.mPosition.CAngleToPosition(_loc2_).mDirection != this.mAngle.mDirection) return false;` | `:147` |
| 4 | 距离平方 ≤ 25 | `if (this.mPosition.Distance_SQR(_loc2_) > this.mAttackRange * this.mAttackRange) return false;` | `:151` |

再补一次视线检测（`:155`）：

```as
_loc3_ = this.mWorld.mMap.mCollide.Collide_Line(
             this, this.mPosition, _loc2_,
             Thing.Shot.CThing_Shot_FireBall.mCollideRadius,     // 0.1
             Thing.Affect.CThing_Affect.mAffect_PlayerLineOfSight);
if (_loc3_.mThing._CLASSID_ != this.mTarget_Player._CLASSID_) return false;
```

* `mAttackRange = 5`（`:66`），单位是**格** → 160 px。
* 第 3 条不含容差：`mDirection` 是 8 方向量化值，恶魔必须已经转向目标方向才能开火（转向由
  `SetState_WithDirection` / `State_Turn` 完成）。
* 火球碰撞半径 `mCollideRadius = 0.1`（`__Packages/Thing/Shot/CThing_Shot_FireBall.as:74`），
  用它当视线射线的粗细。
* 视线用一个**类型为 `mAffect_PlayerLineOfSight` 的 affect** 去问「沿这条线第一个能被该类型打中的东西是谁」，
  只有第一个命中物是同为玩家的 classID 才算通视（墙/桶会挡住）。
  玩家的 `mAffectFlags` 里含 `mAffect_PlayerLineOfSight`
  （`__Packages/Thing/Creature/CThing_Creature_Player.as:153`），所以对玩家生效。

**没读到的东西（【未恢复】）**：`Collide_Line` 本身在 `__Packages/World/Map/CMap_Collide.as`
（该文件 89 处加密记号，池未配上），因此射线是「格步进」还是「连续检测」无法从代码确认；
只知道它按 `mCollideRadius` 膨胀、返回 `{mThing, mPOI, mCollideType}`（由调用方用法反推，【推断】）。

---

## 3. 目标选择：多目标时打谁（问题 2）

**结论：最近的非死亡玩家优先，没有固定玩家、没有仇恨表。**（【常量池恢复】`__Packages/Thing/CThing_Collection.as:97`–`:132`）

```as
GetClosestPlayer(p) {
    if (this.mThingCounters[CThing_Creature_Player] == 1) {   // 场上只有 1 个玩家
        for (var k in this.mPlayerThings) return this.mPlayerThings[k];
    }
    var _loc3_ = 1.7976931348623157e+308;                     // 初值：Number.MAX_VALUE
    for (k in this.mPlayerThings) {
        _loc2_ = this.mPlayerThings[k];
        if (!(_loc2_.mFlags & CThing.mFlag_DEAD)) {           // 跳过死亡玩家
            if ((_loc4_ = p.Distance2D_SQR(_loc2_.mPosition)) < _loc3_) {
                _loc3_ = _loc4_; _loc5_ = _loc2_;
            }
        }
    }
    if (!_loc5_) {                                            // 全死了 → 随便返回一个
        for (k in this.mPlayerThings) return this.mPlayerThings[k];
    }
    return _loc5_;
}
```

* 距离用 **平方距离** `Distance2D_SQR`（`:116`），无开方，无权重、无「最后攻击者」记忆。
* 调用方：僵尸 `__Packages/Thing/Creature/CThing_Creature_Zombie.as:73`
  `this.mTarget_Player = this.mThing_Collection.GetClosestPlayer(this.mPosition);`
  恶魔 `__Packages/Thing/Creature/CThing_Creature_Devil.as:86`（同样传 `mPosition`）。
* 两者都是**每帧重新选**，所以玩家在两人之间跑动时目标会即时切换。
* 边界情况：僵尸/恶魔的 `Brain()` 里写着 `this.mTarget_Position = this.mTarget_Player.mPosition;` 之后才
  `if (this.mTarget_Player == undefined) {}`（僵尸 `:74`–`:77`，恶魔 `:87`–`:90`）——
  **判空写在取值之后，是原版的一个空 if（无效判空）**；若玩家全灭会先抛异常（【推断】，
  实际上 `PlayerDead` 会立刻结束游戏，见 `__Packages/World/CWorld.as:237`–`:256`，所以很难触发）。
* **【推断】** 双人模式下「两人都活着」时，敌人的目标会在两人间距变化时来回切换；
  文档化的实现若想还原手感，应保留这一「无锁定」行为。

---

## 4. 状态机：从发现到靠近到攻击（问题 3）

### 4.1 状态机骨架（【常量池恢复】`__Packages/Thing/Creature/CThing_Creature.as`）

每个 Creature 有一个「当前状态函数」指针 `fState`，`Process_Normal()` 每帧调它：

```as
Process_Normal() {                       // :44
    if (this.mAffectors.length) this.ProcessAffects();
    this.fState();
}
```

切换状态（`:86`–`:96`）：

```as
SetState(nState) {
    if (this[nState] != undefined) {     // 状态函数必须存在，否则整个 SetState 变成空操作
        this.mReturnStateID = this.mStateID;
        this.mStateID       = nState;
        this.mStateCount    = 0;
        this.fState         = this[nState];
        this[nState + "_Init"]();        // 约定：<状态名>_Init 是进入回调
    }
}
```

关键字段：`mStateID`（当前）、`mReturnStateID`（上一状态，被 `State_Sleep/Wait/攻击` 用来回退）、
`mBaseStateID`（**长期意图**，`CellToCell`/`Turn`/`Sleep` 结束后回到它）、`mStateCount`（倒计时）、
`mTarget_Angle`（`CThing_Angle`，目标朝向）、`mTarget_Direction`（0..7）。

### 4.2 僵尸状态迁移表

| 状态 | 进入回调 `_Init` | 每帧逻辑 | 迁移条件 → 目标状态 |
| --- | --- | --- | --- |
| `State_EnterMap` | `:127`–`:146`：`SetCollideDirection(pos, mCollide_Creature)`；清 `mFlag_Collidable`；`mBaseStateID = mStateID`；`mCurrentCell = mNewCell`；扫描 8 个邻格（步长 2，只看正方向）找第一个不含 `mCollide_StaticImpassable` 的格，把朝向设过去 | `:147`–`:158` | 若 `mDirectionCell.mCollide & mCollide_Creature` → `State_Wait`（入口被占）<br>否则 `Affect_Setup(Bullet\|Explosion\|FireBall)`、置 `mFlag_Collidable`、`mBaseStateID = State_GotoPlayer`，再转 `State_RemoveObject`（若存在）否则 `State_CellToCell`（`:157`） |
| `State_GotoPlayer` | `:79`–`:83`：`mBaseStateID = mStateID`；动画 `walk` | `:84`–`:104`：`Brain()` 选目标 → 算 `mTarget_Direction` → 查 `NavReal_<dir> & mCollide_Player` | ① 邻格有玩家 → `SetState_WithDirection(State_Attack, 当前方向, 目标方向)`（`:94`）<br>② `Nav_Direction(...)` 返回 −1（无路）→ `State_Wait`（`:99`）<br>③ 否则 `SetState_WithDirection_Wait(State_CellToCell, 当前方向, 目标方向)`（`:102`） |
| `State_Attack` | `:105`：动画 `attack` | `:109`–`:122`：`Animate(min(0.3*(mSpeed*25*1.5),1))`；动画播完（返回 true）时对 `mAdjacentCells[mAngle.mDirection]` 施加 `CThing_Affect_ZombieAttack(this, mDamage)` | 施加伤害后 → `State_Sleep`，`mStateCount = 10`，`mReturnStateID` 还原为进入攻击前的状态（`:117`–`:120`） |
| `State_CellToCell` | `:159`–`:167`：算 `mDelta`、`mStateCount = 1/mSpeed`（直）/`1.4142/mSpeed`（斜） | `:168`–`:181`：每帧扣 `mStateCount` 并推进 `mPosition`；`QAnimate(mAnimSpeed)` | 计数 ≤0 → 吸附到 `CellCentre()`、`MoveThing`、`SetState(mBaseStateID)`（回到 `State_GotoPlayer`） |
| `State_Turn` | `:182`–`:187`：`mAngleDelta = mSpeed*10*TurnAngle(mTarget_Angle)`；`mStateCount = \|AngleDifference\| / mAngleDelta`；动画 `stand` | `:188`–`:197`：`mAngle.Add(mAngleDelta)` | 计数 ≤0 → 角度对齐 → `SetState(mBaseStateID)` |
| `State_Wait` | `:228`–`:232`：`mStateCount = CMain.mFPS`（**1 秒**）；动画 `stand` | `:233`–`:239` | 计数 ≤0 → `SetState(mBaseStateID)` |
| `State_Sleep` | `:217`–`:220`：动画 `stand` | `:221`–`:227` | 计数 ≤0 → `SetState(mReturnStateID)` |
| `State_TurnAndMove` | 转调 `State_Turn_Init`（`:198`） | `:202`–`:213`：转向完成后用 `CollideFlagsInDirection` 判定是否可走 | 可走 → `State_CellToCell`；否则回 `mBaseStateID` |
| `State_WaitToMove` | `:240`–`:244`：`mStateCount = CMain.mFPS` | `:245`–`:254` | 计数 ≤0 或前方不再被 `mCollide_Creature` 挡住 → `State_CellToCell`（若 `mCollide_NonMovable` 则回 `mBaseStateID`） |
| `State_ZombieHit` / `State_ExplosionHit` | 转调 `State_BulletHit_Init`（`:255` `:263`） | 转调 `State_BulletHit`（`:259` `:267`） | 同受击 |
| `State_BulletHit` | `:271`–`:290` | 见 §5 | 见 §5 |
| `State_Dying` / `State_Dead` | `:325` / `:344` | 见 §5 | 见 §5 |
| `State_Stand` | — | `:214` 空函数 | — |

僵尸在同一基类上还「继承」了 `State_GotoPosition`、`State_Wander`（`:97` `:112`），
但僵尸的初始化直接 `SetState(State_EnterMap)`（`__Packages/Thing/Creature/CThing_Creature_Zombie.as:57`）
且 `mBaseStateID` 被设为 `State_GotoPlayer`，因此**这两个漫游状态在僵尸身上不会被用到**（【推断】）。

`SetState_WithDirection` / `SetState_WithDirection_Wait`（`:58` `:69`）：

```as
SetState_WithDirection(nState, cDirection, tDirection):
    if (tDirection == cDirection) SetState(nState)          // 已经朝着目标 → 直接进
    else { mTarget_Angle.mDirection = tDirection; SetState(State_Turn) }

SetState_WithDirection_Wait(nState, cDirection, tDirection):
    if (tDirection == cDirection) SetState(nState)
    else if (mReturnStateID == State_Turn) {                // 刚转完一次又不对 → 罚站
        SetState(State_Sleep); mStateCount = CMain.mFPS / 3 // 1/3 秒
    } else { mTarget_Angle.mDirection = tDirection; SetState(State_Turn) }
```

> 这条 `_Wait` 分支是原版的**防抖/防抖振**机制：转向后再判断方向仍不匹配就停 1/3 秒。

### 4.3 僵尸的攻击触发点（`__Packages/Thing/Creature/CThing_Creature_Zombie.as:84`–`:104` 展开）

```
每帧（State_GotoPlayer）:
  mTarget_Player     = GetClosestPlayer(mPosition)
  mTarget_Position   = mTarget_Player.mPosition
  curDir             = mAngle.mDirection
  mCurrentCell       = cell(mPosition)
  mTarget_Angle.mAngle = atan2( (tY&0xFFFFFF)+0.5 - mY , (tX&0xFFFFFF)+0.5 - mX )
  mTarget_Direction  = mTarget_Angle.mDirection
  if (NavReal_<mTarget_Direction>() & mCollide_Player):
        SetState_WithDirection(State_Attack, curDir, mTarget_Direction)   // 先转向再打
        return
  mTarget_Direction = mCurrentCell.Nav_Direction(curDir, mTarget_Direction,
                                                  mCollide_NonMovable /*227*/, false)
  if (mTarget_Direction == -1):  SetState(State_Wait); return
  SetState_WithDirection_Wait(State_CellToCell, curDir, mTarget_Direction)
```

### 4.4 恶魔状态迁移表（【直读】`__Packages/Thing/Creature/CThing_Creature_Devil.as`）

| 状态 | 行为 | 行号 |
| --- | --- | --- |
| `State_EnterMap` | 继承基类；`Affect_Setup` 被重写为「基类掩码 \| `mAffect_PlayerLineOfSight`」 | `:56`–`:59`（重写）+ `CThing_Creature.as:127` |
| `State_GotoPlayer` | 先 `if (this.Brain()) return;`；然后与僵尸同构地算 `mTarget_Direction`；**但检测的是 `mCollide_Object`（128）而不是 `mCollide_Player`** → 前方有可破坏物时改成「拆墙」攻击 | `:106`–`:135`（`:120`） |
| `State_Attack` | 播 `attack` 动画，在 `mFrameIndex == 3` 那一帧发射火球 | `:166`–`:195` |
| `State_TrackTarget` | 只把动画设为 `stand`，函数体空 | `:196`–`:202` |
| `State_RemoveObject` | 若 `mAdjacentCells[mAngle.mDirection].mCollide & mCollide_Object` → 对该格施加 `CThing_Affect_DevilAttack(this, this, 100000, this.mAngle)`；否则回 `State_GotoPlayer` | `:203`–`:218` |
| `State_Attack_Decision`（**不是状态，是谓词**） | 见 §2.4 | `:136`–`:161` |

恶魔的 `Brain()`（`:84`–`:100`）：

```as
Brain() {
    mTarget_Player   = mThing_Collection.GetClosestPlayer(mPosition);
    mTarget_Position = mTarget_Player.mPosition;
    if (mTarget_Player == undefined) { }            // 又是空判空
    if (State_Attack_Decision()) {                  // 已冷却 + 同向 + ≤5 格 + 通视
        mDamageMulitply = false;
        mAttackAngle    = mPosition.CAngleToPosition(mTarget_Player.mPosition);
        SetState("State_Attack");
        return true;                                // 本帧不移动
    }
    mCanAttack = true;                              // 允许下次攻击
    return false;
}
```

> 注意 `mDamageMulitply`（原版拼写错误，少一个 `t`）只有「打墙」分支会置 true（`:124`），
> 打玩家时是 false（`:93`）。

### 4.5 转向与移动参数

| 参数 | 僵尸 | 恶魔 | 出处 |
| --- | --- | --- | --- |
| `mSpeed`（格/tick） | `0.02` | `0.04` | Zombie`:56` / Devil`:63` |
| 一格耗时（直行，tick） | `1/0.02 = 50` | `1/0.04 = 25` | `CThing_Creature.as:163` |
| 一格耗时（斜行，tick） | `1.4142135623730951/0.02 ≈ 70.7` | `≈ 35.4` | 同上 |
| 换算成 px/s（mFPS=25） | `32/(50/25) = 16 px/s` | `32/(25/25) = 32 px/s` | 【推断】，基于 §1.3 的换算 |
| 转向角速度 | `mAngleDelta = mSpeed * 10 * TurnAngle(目标)`，即 `0.2 * 角差`（僵尸） | `0.4 * 角差` | `CThing_Creature.as:184` |
| 转向帧数 | `\|AngleDifference\| / mAngleDelta` = `1/(mSpeed*10)` = **5 tick**（僵尸）；恶魔 2.5 tick | | `:185` |
| 半径 | `SetRadius(0.45)`（=14.4 px） | `SetRadius(mDefault_Scale = 0.42)`（=13.44 px） | `CThing_Creature.as:35` / Devil`:64` `:226` |
| `mHeight` | `1.5`（Process_Init 与自身各写一次） | `1.8` | `CThing_Creature.as:36`、Zombie`:60` / Devil`:71` |
| `mMass` | `1`（基类默认） | `5` | `CThing_Creature.as:21` / Devil`:68` |
| `mAnimationSpeed` | `1`（基类静态） | `1` | `CThing_Creature.as:477` |
| 僵尸行走动画速率 | `mAnimSpeed = 0.34 * CThing_Creature.mAnimationSpeed = 0.34` | — | `CThing_Creature.as:166` |
| 僵尸攻击动画速率 | `Animate(min(0.3*(mSpeed*25*1.5),1)) = min(0.225,1) = 0.225` | — | Zombie`:113` |
| 恶魔攻击动画速率 | — | `Animate_RetObj(min(0.2*(mSpeed*25*1.5),1)) = min(0.3,1) = 0.3` | Devil`:168` |

### 4.6 寻路：格子距离场 + 局部绕行（【常量池恢复】`__Packages/World/Map/CMap_Cell.as`）

**不是 A\*，是「从玩家出发的多源 BFS 距离场 + 当前格贪心下降」**：

1. `Nav_Reset()`（`:551`）：状态置 `restart`。
2. `Nav_Restart()`（`:569`）：由 `CThing_Collection.Process` 每帧调用；若上帧已 `finished` 就重新开始，
   并 `nSID++`（**session id**，用于让上帧的距离场立刻失效）。
3. `Nav_Update(sCellList)`（`:589`–`:678`）：`nSTimer = getTimer()`；把玩家格从距离 0 开始做 4 邻域
   （只扩散 `ac[0]/ac[2]/ac[4]/ac[6]`，即东南西北，`:613`–`:616`）逐层 BFS，每帧最多扩 5 层，
   并按时间预算（`nTimeOut`）分帧继续；遇到 `mCollide_Navigation`(=131，即静态障碍+物体) 的格就跳过。
   每格记 `nID = nSID`、`nDist = 当前层号`（`NF_4()`，`:679`–`:688`）。
4. `Nav_Direction(cDir, tDir, tCollideFlags, tForceIt)`（`:280`–`:335`）：
   * 若距离场新鲜（`nSTimer - this.nID < 2000` 毫秒）：
     * 直取 `tDir`：若 `ac[tDir].nDist < this.nDist` 且 `NavReal_tDir() & tCollideFlags == 0` → 返回 `tDir`；
     * 再试 `cDir`（保持当前方向）同样条件 → 返回 `cDir`；
     * `tForceIt == false` 时累计全扫描计数 `nFullScanCount`，超过 5 次直接返回 −1（**放弃，进入 `State_Wait`**）；
     * 否则按 `ac[*].nDist` 降序排序，取第一个 `nVD` 允许的方向（`Nav_VD` 用 `mDirectionM_*` 掩码排除被挡的 8 方向，`:387`–`440`）。
   * 若距离场过期 → `NavReal_Dir(tDir, cDir, tCollideFlags)`（`:336`–`:386`，纯局部绕行）：
     先 `tDir`、再 `cDir`，再按「偶方向偏 2、奇方向偏 1/3」的顺序做 ± 扫描，环绕 `& 7`；全被挡返回 −1。
5. **参数约定**：僵尸传 `mCollide_NonMovable`(=227)、`tForceIt = false`；恶魔传同样的 flags 但 `tForceIt = true`
   （`__Packages/Thing/Creature/CThing_Creature_Zombie.as:97` vs `CThing_Creature_Devil.as:128`）。
   `tForceIt = true` 时不受 5 次全扫描上限约束，绕路更执着。

> **给 Godot 的提示**：这套「距离场 + 贪心下降」在开放房间里表现就是「大致朝玩家走、撞墙就贴墙找缝」，
> 会出现贴着墙角来回抖的典型行为；`State_Wait`(1 s) 是它唯一的「卡住」兜底（`CThing_Creature.as:230`）。

---

## 5. 攻击判定、冷却与伤害施加（问题 4）

### 5.1 affect 类型常量表（【常量池恢复】`__Packages/Thing/Affect/CThing_Affect.as`）

| 常量 | 值 | 行号 |
| --- | --- | --- |
| `mAffect_None` | 0 | `:40` |
| `mAffect_Bullet` | 1 | `:47` |
| `mAffect_Electricuted` | 2 | `:54` |
| `mAffect_Explosion` | 4 | `:61` |
| `mAffect_Punched` | 8 | `:68` |
| `mAffect_Push` | 16 | `:75` |
| `mAffect_Vapourize` | 32 | `:82` |
| `mAffect_ZombieAttack` | **64** | `:89` |
| `mAffect_PlayerLineOfSight` | **128** | `:96` |
| `mAffect_DevilAttack` | **256** | `:103` |
| `mAffect_FireBall` | **512** | `:110` |

受击方的 `mAffectFlags` 决定「我吃不吃这种伤害」，攻击方的 `tAffect.mType` 决定「我是什么伤害」，
匹配逻辑在 `CMap_Cell.Affect`（`__Packages/World/Map/CMap_Cell.as:109`）。

| 实体 | `mAffectFlags` | 出处 |
| --- | --- | --- |
| 僵尸 | `Bullet \| Explosion \| FireBall` = 1\|4\|512 = **517** | `__Packages/Thing/Creature/CThing_Creature.as:154` |
| 恶魔 | 517 \| `PlayerLineOfSight`(128) = **645** | `__Packages/Thing/Creature/CThing_Creature_Devil.as:56`–`:59` |
| 玩家（正常） | `Bullet \| Explosion \| ZombieAttack \| PlayerLineOfSight \| FireBall` = **709** | `__Packages/Thing/Creature/CThing_Creature_Player.as:153` |
| 玩家（`_global.mInfinateLife` 作弊） | 仅 `PlayerLineOfSight` = **128** | `:149` |

**由此可推出的三条战斗规则**（均【推断】，依据上面的掩码）：

1. 僵尸打不到僵尸（僵尸掩码不含 `mAffect_ZombieAttack`）。
2. **恶魔的火球会打伤僵尸**（僵尸掩码含 `mAffect_FireBall`，火球用的正是 `CThing_Affect_FireBall`）。
3. 恶魔拆墙用的 `mAffect_DevilAttack`（伤害 10000）**打不到僵尸**（僵尸掩码不含 256）。

### 5.2 僵尸的攻击

* 判定形状：**整格**。`State_Attack` 动画播完那一帧执行（**【常量池恢复】**）：

```as
_loc3_ = mMap.mCells[mPosition.mY & 0xFFFFFF][mPosition.mX & 0xFFFFFF];   // 自己所在格
_loc3_.mAdjacentCells[mAngle.mDirection].Affect(
        new Thing.Affect.CThing_Affect_ZombieAttack(this, this.mDamage));
```
`__Packages/Thing/Creature/CThing_Creature_Zombie.as:115`–`:116`

* 伤害 = `mDamage = 50`（`__Packages/Thing/Creature/CThing_Creature_Zombie.as:61`）。
* 作用的格子 = **自己朝向方向的那一个相邻格**（`mAdjacentCells[dir]`，斜向也是单格）。
* 命中半径：无。落在该格里的任何 `mAffectFlags & 64` 且 `mID` 不同的实体都会吃到伤害
  （`__Packages/World/Map/CMap_Cell.as:109`）。
* **冷却**：没有独立冷却计时器。攻击动作播完后 `SetState(State_Sleep); mStateCount = 10;`
  （`:117`–`:120`）→ 命中后固定停 **10 tick**（0.4 s @mFPS=25），然后回 `State_GotoPlayer`
  重新判断；也就是说下一帧若邻格还有玩家会再次进入攻击。**实际攻击间隔 ≈ 攻击动画时长 + 10 tick**
  （【推断】；动画时长取决于 XSI 动画帧数与速率 `0.225`，未逐帧统计）。

### 5.3 恶魔的攻击

* 触发帧：`Animate_RetObj(...)` 返回的 `mNewFrame && mFrameIndex == 3`
  （`__Packages/Thing/Creature/CThing_Creature_Devil.as:173`）。
* 发射位置：优先用右手 + 左手模型的平均位置（`:179`–`:181`）：

```as
_loc2_ = mXSI_Animation.XSI_Info.XSI_Model_Hand_Right.nPosition;
_loc2_ = _loc2_.Add(mXSI_Animation.XSI_Info.XSI_Model_Hand_Left.nPosition);
_loc2_ = mPosition.Add(_loc2_.ScaleN(0.5));
// 若手部位置非法(NaN)：退回「自身位置 + 朝向方向 * (mRadius*1.5)」，并强制 z = 0.84
```

* 命中判定：**投射物碰撞**，不是扇形。`CThing_Shot_FireBall`
  （`__Packages/Thing/Shot/CThing_Shot_FireBall.as`）：
  * 半径 `SetRadius(!mDamageMultiply ? 0.25 : 1)`（`:38`），即 0.25 格 = 8 px（正常）/ 1 格 = 32 px（拆墙）。
  * 每帧 `mDelta.ScaleN(1.02)` 加速（`:45`）；`mDelta = mAngle.mDelta.ScaleN(tSpeed != undefined ? tSpeed : 0.15)`
    （`:23` / `:71`）—— **默认速度 0.15 格/tick = 4.8 px/tick ≈ 120 px/s @mFPS=25**。
  * 命中后按 `mRadius` 取一个正方形区域并 `AffectArea`（`:49`–`:50`）：

```as
rect = new flash.geom.Rectangle(mPosition.mX - mRadius, mPosition.mY - mRadius,
                                mRadius*2, mRadius*2);
mAffect.AffectArea(rect, !mDamageMultiply
        ? new CThing_Affect_FireBall (mParent, this, mDamage,  mAngle)     // 伤害 = mAttackDamage
        : new CThing_Affect_DevilAttack(mParent, this, 10000,   mAngle));  // 拆墙固定 10000
```

* 伤害：`mAttackDamage = 50`（`CThing_Creature_Devil.as:67`）；`mDamageMultiply` 时固定 **10000**（`:212` 用的是 100000）。
  > ⚠️ 数值不一致已在原文确认：`State_RemoveObject` 里写的是 **100000**（`:212`），
  > 火球拆墙分支写的是 **10000**（`CThing_Shot_FireBall.as:50`）。两者都是「秒杀级」，行为上等价。
* `tSpeed` 传入的是 `this.mAttackSpeed`（`:189` 附近的 `_loc6_`），**但恶魔 `Process_Init` 从未给
  `mAttackSpeed` 赋值**（`:60`–`:78` 只设 mSpeed/mMaxLife/mLife/mAttackRange/mAttackDamage/mMass/
  mFireRate/mScore/mHeight/mFireRateCount）→ `undefined` → 走默认 0.15 格/tick。
  （`ApplyUpgrade_Creature_Devil` 也读它做倍率，`__Packages/World/CUpgrades.as:155`。）
  **这是原版的一个未初始化字段，文档化时应照抄默认值 0.15。**
* **冷却**：`mFireRate = 0`（`:69`），`mFireRateCount` 初始 `5`（`:72`），每逻辑帧
  `mFireRateCount--`（`:82`），攻击后 `mFireRateCount = mFireRate = 0`（`:189`）
  → 因为 `State_Attack_Decision` 要求 `mFireRateCount <= 0`（`:138`），**恶魔开完一炮后可以立刻再开**
  （只要动画走到第 3 帧）。**唯一的攻击节奏来自攻击动画的时长**（【推断】）。

### 5.4 伤害真正怎么落地（【常量池恢复】）

两个攻击 affect 的 `AffectThing` 完全一样：

```as
// __Packages/Thing/Affect/CThing_Affect_ZombieAttack.as:18
AffectThing(tThing) { tThing.mLife -= this.mDamage; return this.mDamage; }
// __Packages/Thing/Affect/CThing_Affect_DevilAttack.as:20
AffectThing(tThing) { tThing.mLife -= this.mDamage; return this.mDamage; }
```

`CThing_Affect_ZombieAttack` 构造时把 `mType` 设为 `mAffect_ZombieAttack`（`:16`），
`DevilAttack` 设为 `mAffect_DevilAttack`（`:17`）并多存一个 `mHitDirection`（`:18`）。

**受伤方血量**：

| 实体 | `mMaxLife` / `mLife` | 出处 |
| --- | --- | --- |
| Creature 基类默认 | 100 | `__Packages/Thing/Creature/CThing_Creature.as:41` |
| 僵尸 | 沿用 100 | 同上（僵尸未覆写） |
| 恶魔 | **1000** | `__Packages/Thing/Creature/CThing_Creature_Devil.as:65` |
| 玩家 | **200**，且每 tick 回 `mMaxLife/(mFPS*30)` ≈ 0.267（30 秒回满） | `CThing_Creature_Player.as:180` `:211`–`:213` |

→ 僵尸 4 下（50×4=200）打死满血玩家；恶魔火球也是 4 发。玩家重生无敌：
`mInvincible = 25 * (mGameMode != DeathMatch ? 5 : 1)` = **125 tick（5 s）** 非死斗 / **25 tick（1 s）** 死斗
（`CThing_Creature_Player.as:327`；初始出生时是 200，`:188`）。

**得分**：僵尸 `mScore = 100`（`CThing_Creature_Zombie.as:59`），恶魔 `mScore = 1000`（`CThing_Creature_Devil.as:70`），
`LogKill` 里 `AddScore(..., mScore * mUpgrades.mMultiplier)`（`__Packages/World/CWorld.as:225`）。

---

## 6. 受伤、死亡、尸体与血迹（问题 5）

### 6.1 受伤管线

`CThing.Affect(a)` 只是把 affect 压进 `mAffectors`（`__Packages/Thing/CThing.as:82`）；
下一帧 `Process_Normal` 里由 `ProcessAffects()` 统一结算（`__Packages/Thing/Creature/CThing_Creature.as:414`–`:466`）：

```as
ProcessAffects() {
    mReturn_Angle = mAngle.Clone();
    if (!mInvincible) {
        for (var k in mAffectors) {
            _loc2_ = mAffectors[k];
            _loc3_ = _loc2_.AffectThing(this);            // ← 这里真正扣血
            switch (_loc2_.mType) {
                case mAffect_Bullet:                       // 1，会 fallthrough 到 FireBall
                    if (_CLASSID_ == CThing_Creature_Player && !CThing_Creature.mDamageActive) break;
                case mAffect_FireBall:                     // 512
                    mStateCount = Math.round(_loc3_ / 5 * 2);
                    mDelta = (mPosition - _loc2_.mAffector.mPosition)
                                .Normalize(Math.max(_loc3_/5*2 / CMap_Cell.mSize.x, 0.3) / mMass);
                    mDelta.mZ = 0;
                    mAngle.mAngle = mDelta.toAngleZ() + Math.PI;
                    mHitAngle = _loc2_.mAffector.mAngle;
                    SetState(State_BulletHit);   break;
                case mAffect_Push:               break;          // 16：什么都不做
                case mAffect_Explosion:                          // 4
                    if (!(_CLASSID_ == CThing_Creature_Player && !CThing_Creature.mDamageActive)) {
                        ... Normalize(Math.min(_loc3_/5*2 / mSize.x / mMass, 0.3)) ...
                        SetState(State_ExplosionHit); break;
                    } break;
                case mAffect_ZombieAttack:                       // 64
                    mStateCount = Math.round(_loc3_ / 5);
                    mDelta = (mPosition - affector.mPosition)
                                .Normalize(Math.max(_loc3_/5 / mSize.x / mMass, 0.3));
                    mAngle.mAngle = mDelta.toAngleZ() + Math.PI;
                    SetState(State_ZombieHit);
            }
        }
    }
    mAffectors = new Array();      // 结算完清空
}
```

要点（可直接抄成公式）：

| 参数 | 公式 |
| --- | --- |
| 子弹/火球击退帧数 | `round(damage / 5 * 2)` |
| 爆炸击退帧数 | 同上，但**不设置** `mStateCount`（`:446` 没有赋值行）→ 沿用旧值 |
| 僵尸抓击退帧数 | `round(damage / 5)` |
| 击退向量长度 | `max(damage/5*2 / 32, 0.3) / mMass`（子弹）<br>`min(damage/5*2 / 32 / mMass, 0.3)`（爆炸，注意是 min）<br>`max(damage/5 / 32 / mMass, 0.3)`（僵尸） |
| 击退方向 | `(自身位置 − 攻击者位置)` 归一化，然后 `mAngle.mAngle = 方向角 + π`，`mDelta.mZ = 0` |
| `mDamageActive` | 全局静态开关，`CScreen_SelectWorld` 按存档设置：`Thing.Creature.CThing_Creature.mDamageActive = (mMode != DeathMatch) ? CMain.mSaveData.mDamageActive : true`（`__Packages/Screen/CScreen_SelectWorld.as:144`；2Play 默认 true，`CThing_Creature.as:486`）。为 false 时**玩家对子弹/火球完全免伤**。 |
| `mInvincible` | 非 0 时**跳过整段结算**（`ProcessAffects` 的 `if(!this.mInvincible)`），且 `mAffectors` 仍会被清空（`:465`） |

### 6.2 受击状态

`State_BulletHit_Init`（`CThing_Creature.as:271`–`:290`）：

```as
mStateCount = 0;
var _loc2_ = mDelta.mLength;  while (_loc2_ >= 0.01) { mStateCount++; _loc2_ *= 0.65; }  // 击退距离→帧数
mWorld.mMap.mDecal.Draw_BloodSplat(mPosition, 1);
ClearCollideCell();                                    // 释放自己占的格子
mXSI_Animation.SetAnimation("shothit_" + (random(2)+1));   // 1 或 2（前后受击）
PlaySound(mSound.Damage);
if (所在格 mCollide & mCollide_StaticImpassable) { mDelta.mX = mDelta.mY = mDelta.mZ = 0; }
```

`State_BulletHit`（`:291`–`:324`）逐帧：

```as
_loc3_ = mPosition.Clone();
_loc2_ = mWorld.mMap.mCollide.CreatureCollide(this);       // 生物专用碰撞+反弹
if (isNaN(_loc2_.mX)) {                                     // 被挤出地图
    mFlags |= CThing.mFlag_DEAD;
    mThing_Collection.mThingCounters.INVALIDPOSITION++;      // 计数器：非法位置
    SetState(State_Dying); return;
}
Move(_loc2_);
mDelta.ScaleN(0.65);                                       // 每帧衰减 35%
if (mStateID != State_ExplosionHit) mMap.mDecal.Draw_BloodSplat(mPosition);  // 一路洒血
if (mLife <= 0) { ClearAffects(); mFlags |= CThing.mFlag_DEAD; }
if (--mStateCount < 0) {
    if (CheckForDead()) return;
    mAngle.mAngle = mReturn_Angle.mAngle;                   // 恢复受击前朝向
    SetState(State_Sleep); mStateCount = 3;                 // 3 帧无敌式硬直
    mReturnStateID = mBaseStateID;
}
```

`CheckForDead()`（`:360`–`:368`）：`mLife <= 0 || (mFlags & mFlag_DEAD)` → `SetState(State_Dying)` 并返回 true。

> 注意 `State_ExplosionHit` **不会**一路洒血（`:304` 的 if），因为爆炸本身已经画了血。

### 6.3 死亡与尸体

| 阶段 | 行为 | 行号 |
| --- | --- | --- |
| `State_Dying_Init` | `PlaySound(mSound.Death)`；`ClearCollideCell()`；清 `mFlag_Collidable`；`ClearAffects()`；动画 `dying`；`mStateCount = 0`；**`mWorld.LogKill(this)`**（计分 + 递减关卡配额） | `:325`–`:334`（LogKill 在 `:333`） |
| `State_Dying` | 每帧 `Draw_BloodSplat(mPosition, 1)`；`Animate(0.34 * CThing_Creature.mAnimationSpeed)` 播完 → 播 `Creature_HitFloor_wav` 落地音 → `State_Dead` | `:335`–`:343` |
| `State_Dead_Init` | `mStateCount = (_CLASSID_ != CThing_Creature_Player) ? CMain.mFPS*2 : CMain.mFPS*4`（**尸体停留 2 秒 / 玩家尸体 4 秒**）；置 `mFlag_SortFloor`；`ClearCollideCell()`；动画 `dead`；`Draw_BloodSplat(mPosition, 5)` | `:344`–`:351` |
| `State_Dead` | 最后 1 秒淡出：`mAlpha = (mStateCount < CMain.mFPS && _root._quality != "LOW") ? mStateCount/CMain.mFPS*100 : 100`；计数 < 0 → **`Delete()`** | `:352`–`:359` |
| `Delete()` | `delete this.Process; mThing_Collection.DeleteThing(this)` | `__Packages/Thing/CThing.as:62` |
| 真正移除 | `CThing_Collection.Process` 下一帧遍历 `mDeleteThings` 调 `Dispose()` 并从 `mThings` 删除（`__Packages/Thing/CThing_Collection.as:149`–`:154`） | — |

**尸体 = 原地播放 `dead` 动画的同一个 Thing**，不是独立 decal；只有血是 decal。
血由 `mWorld.mMap.mDecal.Draw_BloodSplat(position[, scale])` 画进贴花位图
（`CThing_Effect_BloodSplat` / `CMap_Decal`，本次未展开，属另一篇文档的范围）。

**死亡时的额外效果（`LogKill`，【常量池恢复】`__Packages/World/CWorld.as:200`–`:226`）**：

```as
switch (tThing._CLASSID_) {
  case CThing_Creature_Zombie:
      mUpgrades.mZombieCount -= 1;                       // 触发配额递减
      if (mUpgrades.mMultipleKill % 5 == 0) _CreatePickup(tThing.mPosition);   // 每 5 连杀掉一个补给
      break;
  case CThing_Creature_Devil:
      mUpgrades.mDevilCount -= 1;
      _CreatePickup(tThing.mPosition);                   // 恶魔必掉补给
      break;
  case CThing_Creature_Player:
      mUpgrades.mPlayerCount -= 1;
      mHud["mPlayer" + (mPlayerIndex+1) + "_Deaths"]++;
      if (mGameMode == DeathMatch) _CreatePickup(tThing.mPosition);
      return undefined;                                  // 玩家不记分
}
mHud.AddScore(GetScreenPosition(tThing.mPosition), tThing.mScore * mUpgrades.mMultiplier);
```

`_CreatePickup(p)`（`:227`–`:236`）：若该格 `mCollide_StaticImpassable` 为 0，生成 `CThing_Object_Pickup`，
`mDeleteOnPickup = true`，`SetDeleteCounter(CMain.mFPS * 10)`（**10 秒后自动消失**）。

---

## 7. 刷怪机制（问题 6）

### 7.1 数据流总览

```
关卡地图里的 CWorld_Init_Zombie / CWorld_Init_Devil 标记
        │  (CWorld.InitThings 遍历 mInitList)
        ▼
CWorld.AddSpawnPoint_Zombie(p) / AddSpawnPoint_Devil(p)
        │  存成 {mPosition, mCell}
        ▼
CWorld.Spawn_ValidateAll()        ← 世界初始化末尾调用一次
        │  为每点预计算 mNextCell = mCell.ValidMoveDirection()；算不出来的点直接删掉
        ▼
CUpgrades.Process() 每逻辑帧按节奏调用
        ▼
CWorld.Spawn_Zombie() / Spawn_Devil()
        │  Spawn_ValidPosition / Spawn_ValidPosition_NonStrict 挑一个合法点
        ▼
new CThing_Creature_Zombie(point.mPosition.Clone()) / _Devil(...)
        │  → CThing_Creature.Process_Init → 置 mSpeed/mLife → SetState(State_EnterMap)
        ▼
关卡配额：mUpgrades.mZombieCount++ / mDevilCount++
```

### 7.2 刷怪点是怎么登记的

* `CWorld_Init_Zombie` / `CWorld_Init_Devil` **本身只是空壳**（【常量池恢复】）：

```as
// __Packages/World/Init/CWorld_Init_Zombie.as:11
if (!_global.World.Init.CWorld_Init_Zombie) {
    World.Init.CWorld_Init_Zombie extends World.Init.CWorld_Init;
    _loc2_ = World.Init.CWorld_Init_Zombie = function() { super(); }.prototype;
    _loc2_._CLASSID_ = "CWorld_Init_Zombie";
    ASSetPropFlags(World.Init.CWorld_Init_Zombie.prototype, null, 1);
}
```

  （`CWorld_Init_Devil.as:11`–`:19` 完全同构。行 21+ 是线性化器留下的 trailer 垃圾，可忽略。）
  顶层的 `World_Init_Zombie.as` / `World_Init_Devil.as` 只是 `Object.registerClass(...)` 存根（如任务描述）。
* 真正的登记发生在世界初始化循环（【常量池恢复】`__Packages/World/CWorld.as:462`–`:490`）：

```as
case CWorld_Init_Zombie: this.AddSpawnPoint_Zombie(_loc2_.CellCentre()); break;   // :473
case CWorld_Init_Devil:  this.AddSpawnPoint_Devil (_loc2_.CellCentre()); break;   // :476
case CWorld_Init_Player1: this.AddSpawnPoint_Player(_loc2_.CellCentre(), _loc5_, true);  // :479
```

  `_loc2_` 是标记物经过 `mPosition.ConvertScreenToCell()` 的格坐标；**生成点 = 该格中心**。
* `AddSpawnPoint_Zombie/Devil`（`:7`–`:11` `:22`–`:26`）把 `{mPosition, mCell}` push 进
  `mSpawnPoint_Zombie` / `mSpawnPoint_Devil` 数组。
* 初始化末尾 `Spawn_ValidateAll()`（`:494`）→ `Spawn_ValidateAll`（`:32`–`:50`）：
  对两个数组里每个点算 `mNextCell = mCell.ValidMoveDirection()`（`CMap_Cell.as:158`），
  **`undefined` 的点从数组里 splice 掉**。`ValidMoveDirection` 返回第一个不含
  `mCollide_StaticImpassable` 的邻格（`CMap_Cell.as:158`–`:166`），所以「四面被墙围死的刷怪点」会被剔除。

### 7.3 选点算法

| 用途 | 函数 | 合法条件 | 出处 |
| --- | --- | --- | --- |
| 僵尸 | `Spawn_ValidPosition(tList)` | `!((点.mCell.mCollide \| 点.mNextCell.mCollide) & mCollide_NoSpawn /*160*/)` | `CWorld.as:51`–`:68` |
| 恶魔 | `Spawn_ValidPosition_NonStrict(tList)` | `!((点.mCell.mCollide \| 点.mNextCell.mCollide) & mCollide_Creature /*32*/)` | `:69`–`:86` |
| 玩家（Close/Coop） | `Spawn_ValidPosition_Close(tList, p)` | 排除 `mCollide_NoSpawn\|mCollide_Player`，在合格点里取**距 p 最近**且 ≥ `mSpawnDist_Min` | `:87`–`:114` |
| 玩家（Far/DeathMatch） | `Spawn_ValidPosition_Far(tList, p)` | 同上但取**最远** | `:115`–`:142` |
| 玩家范围限制 | `Spawn_ValidPosition_WithinPlayerScope(p1,p2)` | `!(abs(dx) > 19 \|\| abs(dy) > 13)`（19×13 格窗口） | `:143`–`:146` |

三者都是同一形状：`idx = random(len)` 起手，然后**最多扫满整个数组一遍**（`_loc2_ = len; while(_loc2_) {...; _loc3_=(_loc3_+1)%len; _loc2_--}`），
返回第一个合法点；扫完没有就返回 `undefined`。

* `mCollide_NoSpawn = 160`（生物 32 + 物体 128）→ 僵尸不会刷在别的僵尸/玩家/物件所占的格，也不会刷在有物体的格。
* `mCollide_Creature = 32` → 恶魔只避开生物，**允许刷在有静态物体的格**（更宽松，保证恶魔一定刷得出来）。
* `mSpawnDist_Min = 4`（格）只在玩家重生选点里用（`CWorld.as:338`）。

### 7.4 Spawn_Zombie / Spawn_Devil

```as
// __Packages/World/CWorld.as:147
Spawn_Zombie() {
    var _loc2_ = this.Spawn_ValidPosition(this.mSpawnPoint_Zombie);
    var _loc3_;
    if (_loc2_) {
        this.mUpgrades.mZombieCount += 1;                       // → 触发 __set__mZombieCount
        _loc3_ = this.mThing_Collection.AddThing(
                     new Thing.Creature.CThing_Creature_Zombie(_loc2_.mPosition.Clone()));
        return true;
    }
    return false;
}
// :159 Spawn_Devil 与之同构，用 Spawn_ValidPosition_NonStrict + mDevilCount + CThing_Creature_Devil
```

* 构造函数只传位置，**不传角度**（僵尸/恶魔的角度默认 `new CThing_Angle(0)`，见 `CThing.as:113`）。
* 返回 `false` 时**调用方不会重置节奏计数器**（见 §7.5）→ 下一帧继续尝试。

### 7.5 刷怪节奏与上限（【直读】`__Packages/World/CUpgrades.as:26`–`:76`）

```as
CUpgrades.Process() {
    if (World.CWorld.mGameMode == "DeathMatch") return undefined;      // :28 死斗不刷怪
    this.mTick = this.mTick + 1;                                       // :32
    var _loc4_ = this.mWorld.mThing_Collection.mThingCounters;
    _loc4_ = !_loc4_.CThing_Creature_Devil && !_loc4_.CThing_Creature_Zombie;  // :34 场上已无敌人
    var _loc5_ = !this.Level.Devil_Count ? 0 : this.Level.Devil_Count;         // :35
    var _loc6_ = this.Level.Zombie_Count;                                      // :36
    if (_loc6_ <= 0 && _loc5_ <= 0 && _loc4_) {
        ++this.mLevel;                              // :39 过关 → 触发 __set__mLevel
        CSound.mSamples.Click.PlaySound();
    } else {
        if (this.Level.mZombieCount < Math.min(this.Level.Zombie_Count,
                                               _root._quality != "LOW" ? 60 : 40)) {   // :44
            if (this.Level.mSpawnCount_Zombie-- <= 0) {                            // :46
                if (this.mWorld.Spawn_Zombie()) {
                    this.Level.mSpawnCount_Zombie = this.Level.Zombie_SpawnRate;   // :50
                }
            }
        }
        if (this.Level.mDevilCount < this.Level.Devil_Count) {                     // :54
            if ((this.Level.mSpawnCount_Devil -= this.Level.Zombie_Count != 0 ? 1 : 10) <= 0) {  // :56
                if (this.mWorld.Spawn_Devil()) {
                    this.Level.mSpawnCount_Devil = this.Level.Devil_SpawnRate;     // :60
                }
            }
        }
    }
    if (this.mMultipleKillsTick-- < 0) this.mMultipleKill = 0;    // :68
    if (this.mMultiplierTick-- < 0) --this.mMultiplier;           // :72
}
```

逐条规则：

| # | 规则 | 公式 / 数值 |
| --- | --- | --- |
| R1 | 死斗模式**完全不刷怪** | `mGameMode == "DeathMatch"` 直接 return（`:28`） |
| R2 | 僵尸并发上限 | `min(Level.Zombie_Count, quality != "LOW" ? 60 : 40)`（`:44`） |
| R3 | 僵尸节奏 | 计数器每帧 −1（后置递减）；`<= 0` 时尝试生成；成功则重置为 `Level.Zombie_SpawnRate`。**净周期 = Zombie_SpawnRate + 1 tick**（成功时） |
| R4 | 生成失败不重置 | `Spawn_Zombie()` 返回 false 时计数器保持负值 → 之后**每帧都尝试**直到某点空出来（`:46`–`:52`） |
| R5 | 恶魔并发上限 | `Level.mDevilCount < Level.Devil_Count`（`:54`），**无 quality 相关上限** |
| R6 | 恶魔节奏（双速） | 每帧递减 `(Level.Zombie_Count != 0 ? 1 : 10)`：僵尸配额还没打完时按 1 递减（慢），**僵尸配额打完后按 10 递减（快 10 倍）**（`:56`） |
| R7 | 过关 | 僵尸配额 ≤0 **且** 恶魔配额 ≤0 **且** `mThingCounters` 里已无存活的僵尸/恶魔 → `++mLevel`（`:37`–`:41`）。注意计数器在 `AddThing` 时 +1、`DeleteThing` 时 −1，而僵尸尸体要等 `State_Dead` 播完才 `Delete`，**所以必须等所有尸体消失才过关**（【推断】，依据 `__Packages/Thing/CThing_Collection.as:46` `:71`） |
| R8 | 关卡上限 100 | `__set__mLevel` 取 `mLevels[min(index,100)]`（`:512`），超过 100 级沿用第 100 级数值 |

### 7.6 等级数值表（【直读】`__Packages/World/CUpgrades.as:365`–`:401`）

```as
InitLists() {
    this.mMultipleKills = []; this.mMultipliers = []; this.mLevels = [];
    var _loc8_ = 1  * CMain.mFPS;            // :370  Zombie_SpawnRate 初值
    var _loc4_ = !_global.mCheat_OneZombie ? 10 : 1;   // :371  Zombie_Count 初值
    var _loc5_ = 10;                         // :372  Zombie_TotalCount 初值
    var _loc6_ = 10 * CMain.mFPS;            // :373  Devil_SpawnRate 初值
    var _loc7_ = 0;                          //       Devil_Count 累加器
    var _loc9_ = 0;                          //       Devil_TotalCount 累加器
    var _loc12_ = 0;
    var _loc3_ = 1;
    while (_loc3_ <= 100) {
        AddToLevel(_loc3_, {mClassID:"Level", mProp:"Zombie_SpawnRate",  mValue:Math.floor(_loc8_)});  // :380
        AddToLevel(_loc3_, {mClassID:"Level", mProp:"Zombie_Count",      mValue:Math.floor(_loc4_)});  // :381
        AddToLevel(_loc3_, {mClassID:"Level", mProp:"Zombie_TotalCount", mValue:Math.floor(_loc5_)});  // :382
        AddToLevel(_loc3_, {mClassID:"CThing_Creature_Zombie", mProp:"SpeedUp",
                            mValue:Math.min(1 + _loc3_/100*10, 5)});                                   // :383
        _loc8_ = Math.max(_loc8_ - 1, 1);                                              // :384
        _loc4_ = Math.min(_loc4_ + 5, 60);                                             // :385
        _loc5_ += 5;                                                                   // :386
        if (CMain.mSaveData.mDevilsActive) {
            AddToLevel(_loc3_, {… "Devil_SpawnRate",  mValue:Math.floor(_loc6_)});      // :389
            AddToLevel(_loc3_, {… "Devil_Count",      mValue:Math.floor(_loc7_)});      // :390
            AddToLevel(_loc3_, {… "Devil_TotalCount", mValue:Math.floor(_loc9_)});      // :391
            AddToLevel(_loc3_, {… "SpeedUp", mValue:Math.min(1 + _loc3_/100*10, 5)});   // :392
            _loc7_ = Math.min(_loc3_ != 1 ? _loc7_ + 0.3 : 1, 5);                       // :393
            _loc9_ = _loc3_ != 1 ? _loc9_ + 0.25 : 1;                                   // :394
            _loc6_ = Math.max(_loc6_ - 1, CMain.mFPS);                                  // :395
        }
        _loc3_ = _loc3_ + 1;
    }
    this.CreateUpgradeClass("Level");   // :399
    this.mLevel = 1;                    // :400 → 走 addProperty 的 setter，立刻应用第 1 级
    this.mMultiplier = 0;               // :401
```

写成闭式（`n` = 等级，`F` = `CMain.mFPS`）：

| 量 | 公式 | 说明 |
| --- | --- | --- |
| `Zombie_SpawnRate(n)` | `max(F - (n-1), 1)` tick | 即 1 秒起，每级 −1 tick，下限 1 tick |
| `Zombie_Count(n)` | `min(10 + 5(n-1), 60)` | 并发上限（还要再与 quality 上限取 min） |
| `Zombie_TotalCount(n)` | `10 + 5(n-1)` | **本关需击杀的僵尸总数** |
| `Devil_SpawnRate(n)` | `max(10F - (n-1), F)` tick | 10 秒起，每级 −1 tick，下限 1 秒（n ≤ 100 时下限不会触发） |
| `Devil_Count(n)` | `n == 1 ? 0 : floor(min(1 + 0.3(n-2), 5))` | 并发上限，**封顶 5** |
| `Devil_TotalCount(n)` | `n == 1 ? 0 : floor(1 + 0.25(n-2))` | 本关需击杀的恶魔总数，**无上限** |
| `SpeedUp(n)` | `min(1 + n/10, 5)` | 敌人 `mSpeed` 的倍率（`n/100*10`），僵尸/恶魔各一份 |
| 恶魔是否参与 | 仅 `CMain.mSaveData.mDevilsActive` 为真时写入 | `__Packages/CSaveData.as:135`–`:143`，默认由 `CScreen_SelectWorld.as:270` 设为 1 |

**`SpeedUp` 如何生效**：

```as
// __Packages/World/CUpgrades.as:157   ApplyUpgrade_Creature_Zombie
tThing.mSpeed = _loc4_.mSpeed * ((this.v = _loc2_.SpeedUp) != undefined ? this.v : 1);
// :144 ApplyUpgrade_Creature_Devil 额外还有 FireRateUp / AttackSpeedUp
tThing.mFireRate     = _loc4_.mFireRate     * (FireRateUp     ?? 1);
tThing.mAttackSpeed  = _loc4_.mAttackSpeed  * (AttackSpeedUp  ?? 1);
```

`_loc4_.mOriginalStats` 是敌人**第一次注册时**抓的快照
（`Register_Creature_Zombie`，`:293`–`:309`，由僵尸 `CThing_Creature_Zombie.as:65` 调用；
恶魔也在 `CThing_Creature_Devil.as:73` 调用同名函数——它内部用 `tThing._CLASSID_` 分流，
所以恶魔走的是 `ApplyUpgrade_Creature_Devil`）。

**等级数值表（mFPS = 25 的 Normal 档）**：

| 等级 n | Zombie_SpawnRate (tick / 秒) | Zombie_Count (并发) | 本关僵尸总数 | Devil_SpawnRate (tick / 秒) | Devil_Count | 本关恶魔总数 | SpeedUp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 25 / 1.00 s | 10 | 10 | 250 / 10.0 s | 0 | 0 | 1.1 |
| 2 | 24 / 0.96 s | 15 | 15 | 249 / 9.96 s | 1 | 1 | 1.2 |
| 5 | 21 / 0.84 s | 30 | 30 | 246 / 9.84 s | 1 | 1 | 1.5 |
| 10 | 16 / 0.64 s | 55 | 55 | 241 / 9.64 s | 3 | 3 | 2.0 |
| 11 | 15 / 0.60 s | 60 | 60 | 240 / 9.60 s | 3 | 3 | 2.1 |
| 12 | 14 / 0.56 s | 60 | 65 | 239 / 9.56 s | 4 | 3 | 2.2 |
| 20 | 6 / 0.24 s | 60 | 105 | 231 / 9.24 s | 5（封顶） | 5 | 3.0 |
| 35 | 1 / 0.04 s | 60 | 180 | 216 / 8.64 s | 5 | 9 | 4.5 |
| 50 | 1 / 0.04 s | 60 | 255 | 201 / 8.04 s | 5 | 13 | 5.0（封顶） |
| 100 | 1 / 0.04 s | 60 | 505 | 151 / 6.04 s | 5 | 25 | 5.0 |

> 秒数按 `tick / mFPS`，`mFPS = 25`（Normal）。若玩家把游戏速度调到 Fast（`mGameSpeed = 2` → `mFPS = 50`），
> **tick 数不变、秒数减半**（`__Packages/CMain.as:181`–`:184`）。

**配额递减机制**（决定「本关到底要杀多少」，【直读】`__Packages/World/CUpgrades.as:591`–`:624`）：

```as
__set__mZombieCount(a) {                    // :591  a 是 Set 之后的新存活数
    var _loc2_ = a - this.Level.mZombieCount;      // 负数 = 刚死了一个
    if (_loc2_ < 0) {
        this.Level.Zombie_TotalCount += _loc2_;              // 剩余配额 −1
        if (this.Level.Zombie_TotalCount < this.Level.Zombie_Count)
            this.Level.Zombie_Count = this.Level.Zombie_TotalCount;   // 配额低于并发上限时把上限压下来
        this.LogKills(1);                                    // ++mMultipleKill; ++mMultiplier
    }
    this.Level.mZombieCount = a;
}
// __set__mDevilCount 同构（:610）
```

→ **每关需击杀数 = `Zombie_TotalCount`（`10+5(n-1)`）与 `Devil_TotalCount` 之和**，
且 `Zombie_Count`/`Devil_Count` 会在配额见底时被压到剩余配额，所以最后几只一定是「逐个刷、杀完就过关」。
`__set__mLevel`（`:509`–`:523`）在每次升级时：

```as
this.Level.mZombieCount     = 0;                                   // :517
this.Level.mDevilCount      = 0;                                   // :518
this.Level.mSpawnCount_Zombie = this.Level.Zombie_SpawnRate;       // :519
this.Level.mSpawnCount_Devil  = this.Level.Devil_SpawnRate;        // :520
mHud.AddMessage_Level("-+-+-+- LEVEL " + n + " -+-+-+-");          // :521
```

→ **每次升级节奏计数器重置为该级的 SpawnRate**，即新等级第一个僵尸在 `SpawnRate+1` tick 后出现。

### 7.7 MoreRooms 旁证交叉验证（【直读】`[MoreRooms] __Packages/World/CWorld.as`）

MoreRooms 的 `CWorld.as` 未加密，可以逐行比对，结果是**逻辑完全同构**：

| 项 | 2Play | MoreRooms |
| --- | --- | --- |
| `Spawn_ValidPosition` 条件 | `mCollide_NoSpawn`（`__Packages/World/CWorld.as:60`） | `mCollide_NoSpawn`（`[MoreRooms] __Packages/World/CWorld.as:308`） |
| `Spawn_ValidPosition_NonStrict` 条件 | `mCollide_Creature`（`__Packages/World/CWorld.as:78`） | `mCollide_Creature`（`[MoreRooms] __Packages/World/CWorld.as:326`） |
| `Spawn_Zombie` | `mZombieCount += 1` 后 `AddThing(new CThing_Creature_Zombie(p.Clone()))`（`__Packages/World/CWorld.as:147`） | 同（`[MoreRooms] __Packages/World/CWorld.as:335`） |
| `Spawn_Devil` | 同构（`__Packages/World/CWorld.as:159`） | 同（`[MoreRooms] __Packages/World/CWorld.as:347`） |
| `Spawn_ValidateAll` | `mNextCell = mCell.ValidMoveDirection()`，undefined 则 splice（`__Packages/World/CWorld.as:32`） | 同（`[MoreRooms] __Packages/World/CWorld.as:280`） |
| `LogKill` 僵尸每 5 连杀掉补给 / 恶魔必掉 | 同（`__Packages/World/CWorld.as:200`） | 同（`[MoreRooms] __Packages/World/CWorld.as:366`） |
| `CUpgrades` 等级表 | 见 §7.6；`Zombie_Count` 初值条件 `!_global.mCheat_OneZombie ? 10 : 1`（`__Packages/World/CUpgrades.as:371`） | 同公式；初值条件为 `!_global.mDebug ? 10 : 1`（`[MoreRooms] __Packages/World/CUpgrades.as:386`） |

**结论：两个 build 的刷怪规则一致；2Play 只是把调试开关从 `mDebug` 改成了 `mCheat_OneZombie`。**
（【推断】MoreRooms 没有双人模式，所以 2Play 多出了 `mSpawnDist_Min = 4`、
`Spawn_ValidPosition_Close/Far`、`WithinPlayerScope(19×13)` 这套**玩家重生**选点逻辑，
`[MoreRooms] __Packages/World/CWorld.as:359` 的 `Spawn_Player` 只是直接取 `mSpawnPoint_Player[0]`。）

---

## 8. 难度（0/1/2/3）的影响（问题 7）

### 8.1 难度的唯一作用点：跳级 + 得分倍率（【直读】`__Packages/World/CUpgrades.as:77`–`:120`）

```as
SetDifficulty(tDifficulty) {
    var _loc3_ = 1;   // 额外推进的等级数（含 1 的基数）
    var _loc2_ = 1;   // 额外推进的倍率数（含 1 的基数）
    if (World.CWorld.mGameMode == "DeathMatch") {
        _loc2_ = 200;
    } else {
        switch (tDifficulty) {
            case 0: _loc3_ = 1;  _loc2_ = 1;   break;
            case 1: _loc3_ = 10; _loc2_ = 10;  break;
            case 2: _loc3_ = 20; _loc2_ = 30;  break;
            case 3: _loc3_ = 35; _loc2_ = 50;
        }
    }
    this.mWorld.mHud.mSilentMessages = true;
    _loc3_ = _loc3_ - 1;  while (_loc3_) { ++this.mLevel;      _loc3_ = _loc3_ - 1; }
    _loc2_ = _loc2_ - 1;  while (_loc2_) { ++this.mMultiplier; _loc2_ = _loc2_ - 1; }
    this.mWorld.mHud.mSilentMessages = false;
}
```

| 难度 | UI 名称 | 起始等级 | 额外等级 | 起始倍率 |
| --- | --- | --- | --- | --- |
| 0 | `_Level_Beginner` | **1** | +0 | 0 |
| 1 | `_Level_Intermediate` | **10** | +9 | 9 |
| 2 | `_Level_Expert` | **20** | +19 | 29 |
| 3 | `_Level_Nightmare` | **35** | +34 | 49 |
| — | DeathMatch | 1 | +0 | 199 |

出处：难度按钮 `__Packages/Screen/CScreen_SelectWorld.as:209`–`:212`；默认值 `difficulty = 0`、`devilsActive = 1`
（`CScreen_SelectWorld.as:268` `:270`）；设置写入存档 `__Packages/CSaveData.as:115`–`:123`；
世界读回并应用：`__Packages/World/CWorld.as:516` `this.mUpgrades.SetDifficulty(CMain.mSaveData.mDifficulty)`，
调用时机在世界初始化 `InitCleanUp` 末尾（`CWorld.as:503`–`:525`）。

### 8.2 难度**不**影响的东西

* **AI 逻辑完全不变**：感知方式、目标选择、状态机、攻击判定、冷却结构都走同一份代码；
  难度只通过 `mLevel` 间接改变 `SpeedUp`（敌人 `mSpeed` 倍率）与刷怪率/上限（见 §7.6）。
* 难度不改变敌人血量、伤害、`mAttackRange`、`mFireRate`（这些是类的常量，与等级无关）。
* 难度不改变玩家属性。

### 8.3 各难度开局的实际数值（mFPS = 25）

| 难度 | 等级 | 僵尸刷怪间隔 | 僵尸并发上限 | 本关僵尸总数 | 僵尸 mSpeed（格/tick → px/s） | 恶魔刷怪间隔 | 恶魔并发 | 本关恶魔总数 | 得分倍率起始 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 1 | 25 tick / 1.00 s | 10 | 10 | `0.02*1.1 = 0.022` → 17.6 px/s | 250 tick / 10.0 s | 0 | 0 | 0 |
| 1 | 10 | 16 tick / 0.64 s | 55 | 55 | `0.02*2.0 = 0.04` → 32 px/s | 241 tick / 9.64 s | 3 | 3 | 9 |
| 2 | 20 | 6 tick / 0.24 s | 60 | 105 | `0.02*3.0 = 0.06` → 48 px/s | 231 tick / 9.24 s | 5 | 5 | 29 |
| 3 | 35 | 1 tick / 0.04 s | 60 | 180 | `0.02*4.5 = 0.09` → 72 px/s | 216 tick / 8.64 s | 5 | 9 | 49 |

（px/s = `mSpeed * 32 * mFPS`；`SpeedUp` 见 §7.6；`mMultiplier` 每杀一个 +1，见 `LogKills` `:500`–`:508`。）

---

## 9. 给 Godot 4 的实现建议（【推断】性质的设计映射）

1. **格子层**：`CMap_Cell` 等价物建议做成一张 `PackedInt32Array` 的 collide 位图 +
   一个 `Dictionary[Vector2i, Array[Node]]` 的格内实体表；方向索引固定 0..7（E 起顺时针），
   位掩码照抄 §1.2。攻击判定直接用「查目标格里的实体列表」，不要改成立体碰撞——**原版就是整格判定**。
2. **导航**：不要上 `NavigationAgent2D`。按 §4.6 复刻「玩家格为源的多源 BFS 距离场（4 邻域）+
   当前格贪心下降 + 局部绕行兜底」，并把「每帧最多扩 5 层 / 有时间预算」改成「每帧最多扩 N 格」
   以便和原版性能特征一致；`Nav_Restart/Nav_Update` 的时序照抄 `CThing_Collection.Process` 的顺序
   （**先跑敌人、再更新距离场**）。
3. **状态机**：用「`fState: Callable` + `<StateName>_Init()` 进入回调 + `mStateCount/mReturnStateID/
   mBaseStateID`」的三段式（§4.1）。这是把原版逻辑搬过来最省事的结构，
   `SetState` 里那句 `if (this[nState] != undefined)` 的隐式守卫要保留（否则僵尸的
   `State_GotoPosition/State_Wander` 会被误触发）。
4. **感知**：僵尸不要加视野/听觉；恶魔的「严格 8 方向对齐 + 5 格距离 + 视线」三件套照抄
   （§2.4），其中视线用 `mAffect_PlayerLineOfSight` 那套「第一个被打中的东西必须是玩家」的语义。
5. **节奏**：把 `CUpgrades.Process` 的计数器语义（**后置递减、失败不重置**）原样保留，
   否则「刷怪点被占满时敌人会晚出来」的手感会丢。
6. **可调参数集中在两张表**：等级表（§7.6 的闭式）与难度表（§8.1 的 4 行）。
   原版把这两张表写死在 `InitLists` 与 `SetDifficulty` 里，重制时建议做成 `Resource`。
7. **注意原版的三个「怪但要去抄」的点**：
   * 恶魔 `mAttackSpeed` 未初始化 → 火球速度取默认 0.15 格/tick。
   * 恶魔 `mFireRate = 0` → 攻击间隔只由动画时长决定。
   * `Brain()` 里 `mTarget_Position = mTarget_Player.mPosition` 写在判空之前（无效判空）。

---

## 10. 未恢复 / 存疑清单

| 项 | 状态 | 说明与已尝试的路径 |
| --- | --- | --- |
| `__Packages/World/Map/CMap_Navigation.as`（970 行，522 处记号） | **不含算法**（不是缺口） | 该文件的 `§§constant(N)` 上界 282，而同名类池只有 12 个条目 —— 说明这个 `.as` 把**多个脚本块的输出合并**在了一起，且其中的 `CMap_Navigation` 本身是个**空壳类**。池内容已确认只有 `_global World Object Map CMap_Navigation mMap prototype toString _CLASSID_ Dispose _BASECLASSID_ ASSetPropFlags`，**没有任何导航方法**。真正实现见 `CMap_Cell.as` §4.6。**本文未引用该文件任何一行。** |
| `__Packages/Thing/Affect/CThing_Affect.as`（1576 行，2741 处） | **部分未恢复** | 同一问题（上界 178，池长 90）。但 `mAffect_*` 全部 11 个常量值位于文件前 110 行、已被正确解析，见 §5.1。 |
| `__Packages/Thing/Math/CThing_Navigation.as` | **部分** | 文件头 4–8 行（`§§constant(49/57/52/53/9/58)`）属于**另一个脚本的残片**（线性化器把它们排到了前面），不是本类代码；正文（`:19`–`:64`）已恢复正常，`MoveInDirection2 / CollideFlagsInDirection / ValidMoveDirection` 三个方法可见。本文未依赖它（寻路实际走 `CMap_Cell.Nav_*`）。 |
| MoreRooms `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Zombie.as`（1315 行） | **不能当旁证用** | 该文件本身被加密（535 处记号），且默认不拆嵌套状态机（残留 4 个 `while(true)` 骨架与大量 `set("\x01",...)`）。这**不是**线性化失败：`as2_delinearize.py` 对它成功且 token 校验通过，只是默认保守地保留嵌套机器的完整外形。**结论：不作为旁证。** |
| MoreRooms `[MoreRooms] __Packages/Thing/Creature/CThing_Creature.as` | 部分可用 | 上界 183、池长 184、clean 0.989，可读但线性化同样有残留（`loop1/loop2`），本文仅在 §7.7 用其 `CWorld.as` 做刷怪旁证，未用它的 Creature。 |
| `CMap_Collide.Collide_Line` 的具体实现 | **【未恢复】** | `__Packages/World/Map/CMap_Collide.as` 89 处加密记号且未配上池。只能从调用方推断它返回 `{mThing, mPOI, mCollideType}`、按 `mCollideRadius` 膨胀、返回射线上第一个「接受该 affect 类型」的实体。恶魔视线的**逐格/连续**语义因此无法确认。 |
| 僵尸攻击动画的实际帧数与时长 | **【未恢复】** | XSI 动画数据在二进制里（`CDrawPrimitive_XSI_DI`），需要单独逆向资源才可能确知。因此「僵尸两次攻击的精确间隔」只能写成「攻击动画时长 + 10 tick」。 |
| `mHitAngle` 的下游用途 | **【未恢复】** | `ProcessAffects` 会写 `mHitAngle`（`CThing_Creature.as:437` `:449` `:460`），但 2Play 里未见读取点（被加密的 `CThing_Creature_Player.as` 里可能有受击方向判定，未能确认）。 |
| `__Packages/World/CUpgrades.as` 的 `AddUpgrade` 对数值型升级也调用 `player.NewWeapon(tValue)` | 存疑 | `:121`–`:140`：`if (tValue != true) { for (玩家) player.NewWeapon(tValue); }`。对 `SpeedUp`/`Zombie_SpawnRate` 这类数值型升级看起来是原版的粗糙写法（【推断】），未影响刷怪数值。 |
