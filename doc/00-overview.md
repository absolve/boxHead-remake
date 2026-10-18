# 00 · 总览：Boxhead: 2Play Rooms 逆向架构说明

> 逆向自 `oldGame/Boxhead_2Play.swf`。所有分析基于 `oldGame/_decompiled/Boxhead_2Play/linearized/`
> （已剥离混淆外壳的 ActionScript）。关于混淆与可读性，先看 [README.md](README.md)。

## 1. SWF 元信息

用 `mcp__ffdec__get_swf_metadata` 读取：

| 项 | 值 |
|---|---|
| 文件 | `oldGame/Boxhead_2Play.swf`，磁盘 1,943,061 B |
| 头部 fileSize | 6,477,486 B（未压缩） |
| Flash 版本 | 8 |
| 压缩 | ZLIB，未加密，非 GFX |
| 舞台 | 12800 × 9600 twips = **640 × 480 px**，displayRect `[0,0,12800,9600]` |
| 帧数 / 帧率 | 63 帧 / 50 fps |
| ActionScript | **AS2**（`list_symbols` 返回 0 个 AS3 类） |

## 2. 版本与全局开关

`frame_1/DoAction.as:1-8`：

```
_global.mProduct.mName        = "Boxhead: 2Play Rooms"
_global.mProduct.mVersionName = "Final"
_global.mProduct.mMajorVersion = 1
_global.mProduct.mMinorVersion = "00110"
_global.mProduct.mCompileDate = "16/05/2007 22:37"
```

版权与站点限制（`frame_1/DoAction.as:9-52`）：

| 变量 | 值 | 说明 |
|---|---|---|
| — | `System.security.allowDomain("www.boxhead.seantcooper.com")` | 跨域白名单 |
| — | 右键菜单项 `© Sean Cooper 2007` → `http://www.games.seantcooper.com` | 内建菜单被隐藏 |
| `_global.mURLWindow` | `"_blank"` | — |
| `_global.mCrazyMonkeyGames` | `true` | 发行渠道标记 |
| `_global.mDebug` | `false` | 调试开关 |
| `_global.mAllowLocalHost` | `false` | — |
| `_global.mInfinateLife` | `false` | 无限血作弊 |
| `_global.mRecordMode` | `false` | 录像/演示模式 |
| `_global.mCheat_OneZombie` | `false` | 每级只刷 1 只僵尸 |
| `_global.mCheatsActive` | `false` | — |
| `_global.mHostedOnCMG` | 运行时计算 | 见下 |
| `Stage.scaleMode` | `"noScale"` | 不做缩放，固定 640×480 |

`mHostedOnCMG` 的判定（`frame_1/DoAction.as:30-50`）：先做**时间锁**——从
`new Date(2007,3,23,12,0,0,0)` 起超过 `timeLimit = 15552000000` ms（**180 天**）就强制置为 `true`；
否则检查 `_url` 前缀是否为 `http://www.crazymonkeygames.com` / `http://crazymonkeygames.com`。
`mRecordMode` 为真时也强制 `true`。最后 `gotoAndStop("START_LOAD")`。

> 这类站点校验对重制版没有意义，列出仅为说明原版的发行约束。

## 3. 引擎架构

`__Packages/` 下是全部类，按职责分四层：

```
__Packages/
├── scidd/                     ← 作者自研通用库，与游戏内容无关，可整体照搬
│   ├── Math/  CMath, CLine, CVector3, CRandom
│   ├── Draw/  CColor
│   └── CProfiler
├── Thing/                     ← 场景内一切"实体"
│   ├── CThing                 基类：位置/朝向/父对象/标志位/半径
│   ├── CThing_Collection      实体容器 + 分类计数器
│   ├── Creature/              玩家、僵尸、恶魔
│   ├── Weapon/                武器（持有者侧逻辑）
│   ├── Shot/                  飞行物（子弹/火箭/榴弹/激光/火球）
│   ├── Object/                场景物件（木桶、地雷、补给、可移动墙、激光节点）
│   ├── Effect/                纯视觉特效（爆炸、烟雾、血、枪口火光）
│   ├── Affect/                伤害判定体（矩形/圆/直线扫掠），命中后扣 mLife
│   └── Math/                  CThing_Position, CThing_Angle, CThing_Navigation
├── World/                     ← 一局游戏的运行时
│   ├── CWorld                 世界主控：实体集合、地图、HUD、升级、刷怪
│   ├── CHud                   界面文字/血条/提示
│   ├── CUpgrades              等级曲线、升级掉落与效果
│   ├── Map/                   CMap, CMap_Cell, CMap_Navigation, CMap_Collide,
│   │                          CMap_Mapwho(空间索引), CMap_Affect, CMap_Decal, CMap_Math
│   └── Init/                  CWorld_Init_*：各类实体与世界初始内容的生成配方
├── Screen/                    ← 界面状态机（每个 Screen 是一个状态）
├── DrawPrimitive/             ← 绘制后端
│   ├── CDrawPrimitive, _Square, _Line
│   ├── MovieClip/             用 Flash 矢量图形绘制
│   └── XSI/                   用 XSI 导出的 3D 模型数据绘制（伪 3D 角色）
├── External/                  CHighscore_Submit, CTracker（外部统计）
├── CInput, CSound, CSaveData, CMain, CContextMenu
```

顶层还有 `Main.as`、`frame_*.DoAction.as`、`Screen_*.as`、`World_Init_*.as`、`Piece/*.as`
这类时间轴脚本，它们主要负责**注册类**，例如 `World_Init_Zombie.as` 全文有效代码只有一行：

```actionscript
Object.registerClass("World_Init_Zombie",eval("World.Init.CWorld_Init_Zombie"));
```
（`World_Init_Zombie.as:2`，线性化后该文件只剩 2 行）

`Main.as:3` 则把主类挂上舞台：`Object.registerClass("Main",CMain);`（线性化后 `Main.as` 只剩 3 行）

### 类的组织方式

作者没有用 AS3 的 `package`/`class`，而是走 AS2 的 `_global` 挂载惯例：

```actionscript
if(!_global.Thing) { _global.Thing = new Object(); }
if(!_global.Thing.CThing) {
    _loc2_ = Thing.CThing = function(tPosition, tAngle, tParent) { ... }.prototype;
    _loc2_.Move = function(nPosition) { ... };
    _loc2_._CLASSID_ = "CThing";
    _loc2_._BASECLASSID_ = "CThing";
    §§push(ASSetPropFlags(Thing.CThing.prototype,null,1));
}
```
（`__Packages/Thing/CThing.as:3-109`）

每个类都带 `_CLASSID_` 与 `_BASECLASSID_` 字符串，`CUpgrades` 就靠 `tThing._CLASSID_`
按类名查升级表——**这是原版做「按类批量改数值」的钩子，重制时值得保留等价机制**。

## 4. 主循环与计时

`CMain.as` 是 Flash 时间轴上的驱动器，它的成员名几乎全被加密，但骨架可读：

- **逻辑帧率是 25 Hz**：`CMain.as:288` 有 `[§§constant(34)] = 25;`，
  `CMain.as:184` 是 `eval(...)[§§constant(34)] = 25 * _loc2_;`，
  其中 `_loc2_` 取自画质设置（`CMain.as:183`，未设置时取 `0.5`）——
  **推断**：`§§constant(34)` 就是 `mFPS`，默认 25，低画质时按系数缩小。
  舞台帧率是 50 fps，所以逻辑每两帧跑一次。
- **子步进**：`CMain.as:240-257` 的 `§§constant(35)` 是一个固定步长累加器：
  `_loc3_ = 1000 / tFrameRate`（一步多少毫秒），
  `_loc2_ = round((getTimer() - lastTimer) / _loc3_)`（该跑几步），
  然后 `_loc2_` 被 `§§constant(123)`（`CMain.as:316` 置为 `1`）夹住，避免掉帧后爆炸。
- **一帧的顺序**（`CMain.as:29-48`）：
  1. `_root[...]` 上的输入/计时推进
  2. `getTimer()` 采样
  3. 当前 Screen 的 `Process()`
  4. 用上面的步进数循环调用 Screen 的绘制
  5. HUD/统计更新

> 重制建议：Godot 里用 `_physics_process` 固定 25 Hz 作为逻辑步，`_process` 60 Hz 做插值绘制，
> 与原版语义最接近。

## 5. 实体模型 `CThing`

全部实体共享一套极简数据（`__Packages/Thing/CThing.as`）：

| 成员 | 位置 | 说明 |
|---|---|---|
| `mPosition` / `mP` | `:11` | 世界坐标（`Thing.Math.CThing_Position`） |
| `mAngle` | `:12` | 朝向（`Thing.Math.CThing_Angle`），省略时 `new CThing_Angle(0)` |
| `mParent` | `:13` | 父实体；**有父时 `mID` 继承父的 `mID`**，`sUniqueID` 仍全局唯一 |
| `mUniqueID` | `:14` | 分配自 `Thing.CThing.mAllocate_ID`（`:119` 初值 0） |
| `sUniqueID` | `:15` | `"t" + mUniqueID` |
| `mID` | `:16` | 有 `mParent` 时取 `mParent.mID`，否则取 `mUniqueID` |
| `mFlags` | `:17` | 位标志，见下表 |
| `mRadius` / `mRadius_SQR` | `:44` | 碰撞半径与其平方（避免开方） |

`mFlags` 位（`CThing.as:139-189`）：

| 常量 | 值 | 含义 |
|---|---:|---|
| `mFlag_Collidable` | 1 | 参与碰撞 |
| `mFlag_WaitForMove` | 2 | 等待移动结算 |
| `mFlag_CellMoved` | 4 | 本帧已换格 |
| `mFlag_Drawn` | 8 | 本帧已绘制 |
| `mFlag_SortFloor` | 16 | 需按地面排序 |
| `mFlag_DEAD` | 32 | 死亡 |

另外 `mAllocate_ProcessID_Count = 3`（`:129`），**推断**：把实体分成 3 组轮转处理，做负载摊分。

主要方法：`MakeIDUnique`(`:19`)、`SetRadius`(`:44`)、`GrowRadius`(`:51`，每帧 `+0.05` 增长到目标半径)、
`Move`、`Delete`、`Dispose`、`Affect_Setup` / `Affect` / `ClearAffects`、`PlaySound`。

## 6. 世界、地图与集合

- `World.CWorld`：一局世界的总控，持有 `mThing_Collection`、`mMap`、`mHud`、`mUpgrades`，
  以及 `Spawn_Zombie()` / `Spawn_Devil()` 等生成入口
  （调用点见 `__Packages/World/CUpgrades.as:48,58`）。
  它还有一个静态字段 `CWorld.mGameMode`，取值至少包含 `"DeathMatch"`（`CUpgrades.as:28`）。
- `Thing.CThing_Collection`：实体容器与**按类名计数**（`mThingCounters`），
  `CUpgrades` 判断"场上还有没有僵尸/恶魔"就是查它（`CUpgrades.as:54-55`）。
- `World.Map.CMap`：地图主体，下挂（★ = 完整可读，✗ = 成员名被 `§§constant(N)` 加密）

  | 子模块 | 2Play | 成员名还原 | 职责 |
  |---|---|---|---|
  | `CMap_Cell` | 1277 行 | ✅ pool 39，**零越界** | 格子数据 + **真正的寻路实现** |
  | `CMap_Navigation` | 970 行 | ⚠️ pool 30 只有 **12 项** | **空壳类**（只有 `mMap` / `prototype` / `toString` / `_CLASSID_` / `Dispose`），**不含算法** |
  | `CMap` | 327 行 | pool 27 | 地图主体 |
  | `CMap_Mapwho` | 60 行 | pool 315 | 空间索引，提供 `MoveThing` / `DeleteThing`（`CThing.Dispose` 会调它） |
  | `CMap_Collide` | 310 行 | pool 35（MR 版【直读】） | 碰撞 |
  | `CMap_Affect` | 127 行 | pool 342（MR 版【直读】） | 范围伤害广播 |
  | `CMap_Decal` | 287 行 | pool 346 | 地面贴花（血迹等） |
  | `CMap_Math` | 28 行 | pool 348 | 坐标换算，但**类体被 FFDec 吞掉**，还原池也补不回 |

  > **重要更正**：先前把 `CMap_Navigation.as` 写成"寻路核心 / 唯一硬缺口"是错的。
  > 该文件是把多个脚本块的输出**合并**在一起的容器（地图基类副本 + `CMap_Navigation` 空壳 + `scidd.Math.CMath` + 一个音效类），
  > 空壳类的池只有 12 项、**不含任何算法方法**。
  > 真正的寻路在 **`CMap_Cell`**：类静态的 `Nav_Update` 做 **BFS 距离场**（每帧最多 5 圈、3ms 预算、只扩四正向），
  > 消费端 `Nav_Direction` 做**每格梯度下降**。**没有 A\*、没有按需搜索。**
  > 详见 [02-pathfinding.md](02-pathfinding.md)。
  >
  > 另一个常见误读：`mCells[mPosition.mY & 0xFFFFFF][…]` 里的 `& 0xFFFFFF` 是**AS2 的 int32 取整**，不是"1 世界单位 = 1 格"。
  > 位置是**以格为单位的浮点数**，格中心是 `(x+0.5, y+0.5)`，一格的像素尺寸是 **32**（`CMap_Cell.mSize = Point(32,32)`，`:716`）。

## 7. 界面状态机

`CScreen` 是界面基类，各界面各自是一个类：
`CScreen_Init` → `CScreen_Intro` → `CScreen_Main`（主菜单）→ `CScreen_SelectWorld` →
`CScreen_LoadingWorld` → 游戏（`World`）→ `CScreen_Debrief` / `CScreen_Debrief_Winner` → 循环。
另有 `CScreen_Collection`（图鉴/统计）与 `CScreen_Transition`（转场）。

`CMain` 里有一个 `SetState(nState)` 式的切换器（`CMain.as:99-107`，成员名被加密）：
```
if(this[nState] != undefined) { ...; this[§§constant(36)] = this[nState]; }
```
以及一个按字符串 ID 创建界面的工厂（`CMain.as:108-121`）。**推断**：Screen 的 `Process`/绘制
函数以状态变量保存，切换状态即换函数指针。

## 8. 巨型数据块（不是代码）

184 个反编译文件里有几个是数据，不要当代码读：

| 文件 | 大小 | 内容 |
|---|---:|---|
| `DefineSprite_755_TMP2639qh3hat/frame_1/DoAction.as` | 3.4 MB，204 行（每行极长） | **XSI 三维模型/动画数据**：`mRotations` / `mMaterials` / `mXSIInfo`，含 `mDevil_Default_Stand`、`..._Devil_Attack`、`..._Dying`、`..._HitFront`、`..._HitRear`、`..._Dead` 等 |
| `Screen_Debrief_Winner.as` | 2.7 MB | 以数据为主，仅 17 行有效内容 |
| `__Packages/Screen/CScreen_Intro.as` | 757 KB / 8521 行 | 以数据/文本为主 |
| `__Packages/CSound.as` | 106 KB | 音效名 → 采样映射 |

**这对重制很关键**：Boxhead 的"伪 3D"角色不是位图序列，而是用 XSI 导出的多边形
（`Shape_vList` 顶点表 + `Shape_Material` + `Shape_Matrix`）配合 `DrawPrimitive/XSI/*` 实时绘制。
[XSI 渲染与模型数据] 目前**尚未单独成文**，如果重制要还原角色观感，需要补一份。

## 9. 类清单（按文件）

完整的 184 个 `.as` 文件即类清单，见
`oldGame/_decompiled/Boxhead_2Play/linearized/`。反编译后仍能读到 `_CLASSID_` 的类只有 38 个
（其余类的类体被字符串加密），例如：

```
CThing  CInput  CSound  CSaveData  CMain
CThing_Collection  CThing_Creature  CThing_Creature_Player/Zombie/Devil
CThing_Weapon(_Pistol/Shotgun/UZI/Railgun/Rocket/Grenade/Mine/Barrel/FakeWall/ChargePack/SmartBomb/Devastator)
CThing_Shot(_Bullet/Laser/Railgun/Rocket/Grenade/ClusterShell/FireBall/HomingMissile/Devastator/DLaser)
CThing_Object(_Barrel/Mine/ChargePack/Pickup/Wall/WallMovable/LaserNode)
CThing_Effect(_Explosion/SmartBomb/BloodSplat/BloodPool/MuzzleFlash/RocketSmoke/SmokeCloud/FireBall_Held)
CThing_Affect(_Bullet/Explosion/FireBall/ZombieAttack/DevilAttack)
CWorld  CWorld_Init_*  CMap  CMap_Cell  CMap_Navigation  CMap_Collide  CMap_Mapwho
CScreen_*  CDrawPrimitive_*  CDrawPrimitive_XSI_*  scidd.*
```

## 10. 尚未恢复的部分

**184 个文件里 102 个含加密记号**（其余 82 个干净，其中 57 个是 ≤30 行的按钮/存根脚本）。
判定口径与完整清单见 [README.md 的可读性矩阵](README.md#可读性矩阵)。

**关键区分**：加密分两层，可恢复性完全不同。

| 层 | 记号 | 状态 |
|---|---|---|
| **成员名** | `§§constant(N)`（2Play 共 39,628 处） | ✅ **已可还原**：`N` 是该脚本块自己的 AS2 `ActionConstantPool`（操作码 `0x88`）下标，池以明文存在 SWF 字节码里。工具 `doc/tools/as2_constpool.py` |
| **字符串字面量** | `{invalid_utf8=..}`（2Play 共 150,564 处） | ❌ **未还原**：FFDec 的 AS2 命令行去混淆不可用 |

实际缺口（按专题）：

| 内容 | 状态 | 线索 |
|---|---|---|
| `World/Map/CMap_Math.as` | **【未恢复】** | 类体被 FFDec 吞掉（文件只剩 28 行），还原常量池也补不回被吞掉的语句 |
| `Thing/Object/CThing_Object_WallMovable.as` | **【未恢复】** | 同名文件里装的其实是 **Barrel** 的类体，真正的可移动墙代码不在里面 |
| 房间格数 / 房间尺寸 | **【未恢复】** | 来自库元件的包围盒（`mWorldSize` / `mcRoomData._Size`），常量池救不了，只能量美术资源 |
| `Thing/Math/CThing_Creature_Player` 双人输入差异 | 未处理 | pool 318 可还原，但需要额外的按块切分逻辑 |
| 混淆器的字符串表（`{invalid_utf8=..}`） | 未还原 | `__Packages/CMain.as:359,370` 漏出明文 `morerooms_default.Point` / `morerooms_default.geom`，说明字符串层并非全部不可逆 |
| XSI 模型数据格式 | 未整理 | `DefineSprite_755...` 与 `DrawPrimitive/XSI/*` |
| 关卡/房间布局数据 | 未恢复 | `Piece/*.as` 与 `Piece/WallPost.as` 的反编译结果本身是乱的；`CWorld_Init_Piece.as` 含 42 处记号 |
| 音效清单 | 未整理 | `__Packages/CSound.as`（949 行，5437 处记号）+ Godot 工程里已有一批 `Creature.*` / `Weapon.*` mp3 |
| 僵尸 / 玩家 / 生物基类成员名 | **已还原**，不再算缺口 | `CThing_Creature.as` 0.995、`CThing_Creature_Zombie.as` 1.000、`CThing_Creature_Player.as` 0.978 |
| 多数武器字段名 | **已可还原** | 用 `as2_constpool.py` 对各自文件映射；`Devastator`(2P)/`Grenade`(MR) 本身【直读】 |

## 11. 与 Godot 重制工程的对照

Godot 工程在 `box-head-remake/`，已经有一批场景（`player.tscn`、`character.tscn`、
`zombie`/`devil`、`pistol`/`shotgun`/`uzi`/`railgun`/`rocket`/`grenade`/`mine`/`barrel`、
`explosion`、`map`/`level`/`room_001`、`life_bar`、`game_setting`、`map_select` …）
与从原版提取的音效（`.godot/editor/*.mp3` 里可见
`Creature.Player.Scream.1/2`、`Creature.Zombie.Attack/Hit/Ambience.1-4`、`Weapon.Pistol.Fire`、
`Weapon.ShotGun.Fire`、`Weapon.UZI.Fire`、`Weapon.Railgun.Fire`、`Weapon.Rocket.Fire`、
`Weapon.Mine.Place`、`Effect.Explosion`、`Object.Barrel.Place`、`Object.Mine.Detonate`、
`Object.Pickup`、`Shot.Grenade.Bounce`、`Shot.HitWall.1-3`、`Shot.Rocket.Fire`、
`Creature.HitFloor`、`World.End`、`CLICK`）。

也就是说资产层已经对上了，**缺的正是本文档要补的数值与规则**。
