# 02 · 地图表示与寻路 / 导航方式

> 目标 SWF：`oldGame/Boxhead_2Play.swf`（Flash 8 / AS2，640×480 舞台，63 帧，50fps，
> 产品串 `Boxhead: 2Play Rooms: Final.1.00110 (16/05/2007 22:37)`，© Sean Cooper 2007）。
> 旁证 SWF：`oldGame/boxheadmorerooms.swf`（同作者、同一套 scidd 引擎，单人名版）。
>
> **引用约定**
> - 不带前缀的路径 = 相对 `oldGame/_decompiled/Boxhead_2Play/linearized/`
> - 带 `[MoreRooms]` 前缀的路径 = 相对 `oldGame/_decompiled/MoreRooms/linearized/`
> - 行号均为该文件（linearized 产物）中的行号。
> - **2026-10-22 起有全量明文源码 `F:\scripts`**（每类一个 `.as`，零加密、无文件名错位）；
>   本文所有结论已对照它复核，正文中标 `F:\scripts` 的引用即来自该提取（行号为明文文件中的行号）。
>
> **读法约定**
> - 【事实】= 直接在反编译产物中读到的语句 / 数值。
> - 【推断】= 由结构、调用形态或两版对照得出的结论，未经原文确认。
> - 【未恢复】= 被字符串加密/成员名加密吞掉的内容，已注明尝试过的路径。

---

## 0. 一句话结论

> **本节的每一条都已被「常量池恢复」确证（方法见 §1.3，源码见 §5.0.1）。**

原版**没有 A*、没有 open/closed 表、没有 waypoint 图，也没有真正的“寻路请求”**。
它是 **以玩家为源的格子图上的 BFS 距离场（flow field / distance field）**：
`CMap_Cell.Nav_Update(sCellList)` 是**类静态**方法，**整局游戏只有一张共享流场**，
由 `CThing_Collection.Process` 每帧把所有玩家所在格子当种子喂进去
（`__Packages/Thing/CThing_Collection.as:159-168`），**分帧增量铺开**
（每帧最多 `nInterations = 5` 圈、`nTimeOut = 3` ms 预算），
代价写在**格子自己身上**（`nDist`），访问去重用 `nSID`（会话戳）。
生物每帧只查**自己所在格**：`Nav_Direction(cDir, tDir, mCollide_NonMovable, true)`
先看邻居 `nDist` 是否更小（下坡），再按 `sortOn(nDist, RETURNINDEXEDARRAY|NUMERIC|DESCENDING)`
取"可通行且代价最小"的方向；流场不新鲜时退到局部绕行 `NavReal_Dir`。
拿到方向后交给"格到格"状态机做平滑位移。
物理层的贴墙滑动、圆-圆分离、反弹是**另一套独立系统**（`CMap_Collide`）。

---

## 1. 资料可靠性与可读性分级（先看这个）

FFDec 26.3.0 的 AS2 导出把**一个 SWF 分节里的多个类塞进同一个 `.as` 文件**，
所以 **文件名不等于文件内容**。已确认的三处错位（本文引用时会特别标注）：

| 文件名 | 实际内容 | 证据 |
|---|---|---|
| `__Packages/Thing/Object/CThing_Object_WallMovable.as` | 里面定义的是 `Thing.Object.CThing_Object_Barrel`（木桶） | `__Packages/Thing/Object/CThing_Object_WallMovable.as:51`、`:54` |
| `__Packages/World/Map/CMap_Navigation.as` | ① 地图基类副本(32-107) ② `CMap_Navigation` 空壳类(108-137) ③ `scidd.Math.CMath`(222-573) ④ 一个含 5 路并发音效/声源衰减的类(603-970) | `:224`、`:557`（CMath 的 CLASSID 是明文）、`:876-919` |
| `__Packages/World/Init/CWorld_Init.as` | 内容是加载器/高分提交相关代码，不是世界初始化 | `:65-97` |

### 1.1 加密计数（`§§constant(` = 成员名占位，`invalid_utf8=` = 加密字符串）

计数方式：对 linearized 文件做正则计数。**0/0 才是真干净**。

| 文件 | 行数 | `§§constant(` | `invalid_utf8=` | 可用性 |
|---|---|---|---|---|
| `__Packages/World/Map/CMap_Decal.as` | 287 | 0 | 0 | **完全干净** |
| `__Packages/Thing/Creature/CThing_Creature_Devil.as` | 228 | 0 | 0 | **完全干净**（本次最关键的可读证据） |
| `__Packages/World/Map/CMap_Cell.as` | 1277 | 2793 | 2 | 严重加密（**但数值/控制流可读**） |
| `__Packages/World/Map/CMap_Navigation.as` | 970 | 532 | 16 | 严重加密，且**其中没有导航算法**（见 §1 表） |
| `__Packages/World/Map/CMap.as` | 327 | 286 | 195 | 严重加密 |
| `__Packages/World/Map/CMap_Collide.as` | 310 | 337 | 46 | 严重加密 |
| `__Packages/World/Map/CMap_Mapwho.as` | 60 | 46 | 38 | 严重加密 |
| `__Packages/World/Map/CMap_Math.as` | 28 | 8 | 31 | 几乎全加密（类体被吞） |
| `__Packages/Thing/Math/CThing_Position.as` | 360 | 548 | 0 | 成员名全加密，数值可读 |
| `__Packages/Thing/Math/CThing_Navigation.as` | 65 | 44 | 54 | 支离破碎 |
| `__Packages/Thing/CThing_Collection.as` | 180 | 117 | 33 | 加密，但控制流完整可读 |
| `__Packages/Thing/Object/CThing_Object_WallMovable.as` | 283 | 23 | 13 | 关键几行**可读** |
| `[MoreRooms] __Packages/World/Map/CMap_Collide.as` | 312 | 0 | 0 | **完全干净（成员名全明文）** |
| `[MoreRooms] __Packages/World/CWorld.as` | 505 | 0 | 0 | **完全干净（主循环 + 生成入口）** |
| `[MoreRooms] __Packages/Thing/Math/CThing_Navigation.as` | 782 | 647 | 160 | 严重加密（但 424-480 一小段明文） |
| `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as` | 625 | 336 | 40 | 加密，但关键 3 行明文 |

**这就是本文能给出确切命名的地方**：`Nav_Direction` / `NavReal_*` / `mAdjacentCells` /
`mCollide_*` / `ConvertScreenToCell` / `CellCentre` / `MarkArea_PP` / `mObjects` /
`ValidMoveDirection` / `GetClosestPlayer` 这些名字来自**完全干净的**
`CThing_Creature_Devil.as`、`[MoreRooms] CMap_Collide.as`、`[MoreRooms] CWorld.as`。

> 两版差异提示：MoreRooms 是**单人版**
> （`[MoreRooms] __Packages/World/CWorld.as:359-365` 只生成 `mSpawnPoint_Player[0]`），
> 所以凡是与“双玩家 / 移动墙”有关的结论，**只能以 2Play 为准**，或明确标注来源。

### 1.2 ⚠️ 证据分级与「FFDec 乱码」陷阱（务必先读）

引用本文（或自己继续挖）时，**只信这三档证据**：

| 档 | 判据 | 例 |
|---|---|---|
| **A 档：可确证** | 引用的那一行**本身**是明文的完整语句 | `__Packages/Thing/Creature/CThing_Creature_Devil.as:128`（整句明文） |
| **B 档：结构可读** | 成员名是 `§§constant(N)`，但**表达式 / 数值 / 控制流**完整 | `__Packages/World/Map/CMap_Cell.as:606`（`while(_loc3_ < 5 && …)`，`5` 是明文） |
| **C 档：不可引用** | 类名被塞进 `§§constant(N)` 的位置，产生**语法通顺但语义完全错误**的语句 | 见下 |

**C 档乱码的三种典型形态（看到就跳过，绝对不要引用）**：

1. 类名被当成构造函数：
   `[MoreRooms] __Packages/Thing/Math/CThing_Navigation.as:316`
   `case "GetCell": return new Thing.Math.GetCell(tPosition,tAngle,tParent);`
   —— 真实类不叫 `Thing.Math.GetCell`。
2. `prototype` / `toString` 槽位被塞了类名：
   `[MoreRooms] __Packages/Thing/Math/CThing_Navigation.as:292`
   `Thing.Math.CThing_Navigation extends Thing._CLASSID_;`
   与 `:298` `this.mWorld = this.prototype = Thing.Math.CThing_Navigation.toString;`
3. **两套 API 被揉进一条下标链**：
   `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Zombie.as:206`
   `this.SetState_WithDirection = this.mCollide_NonMovable.Nav_Direction[this.mCurrentCell.State_Wait & 0xFFFFFF][…];`
   —— `Nav_Direction` 是**方法**（`__Packages/Thing/Creature/CThing_Creature_Devil.as:128` 明文可证），
   不可能是 `mCollide_NonMovable` 的属性，也不是二维数组。

**判别口诀**：一行里出现 `X.Y` 形式的类名被当作构造函数、或 `a.b[...]` 套得离谱 ⇒ C 档。
**优先引用「明文文件里的完整语句」，不要引用「加密文件里偶尔漏出的标识符」。**

需要特别说明：本文的 `Nav_Reset` / `Nav_Direction` 证据**全部来自 A 档明文行**
（`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:563` 与 `:606`，
以及 `__Packages/Thing/Creature/CThing_Creature_Devil.as:128`），
不是从乱码里捞出来的。相反，在 `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Zombie.as`、
`[MoreRooms] __Packages/Thing/Math/CThing_Navigation.as`、
`[MoreRooms] __Packages/DrawPrimitive/MovieClip/CDrawPrimitive_MovieClip_Animation.as`、
`[MoreRooms] __Packages/Thing/Weapon/CThing_Weapon_UZI.as` 里搜到的 `Nav_Direction` 命中**几乎全是 C 档乱码**。

### 1.3 ✅ 常量池恢复（本文档的关键升级，方法可复现）

`§§constant(N)` 里的 `N` **就是该脚本块自己的 `ActionConstantPool`（AS2 操作码 `0x88`）数组下标**，
而这个常量池**以明文存放在 SWF 字节码里**。恢复步骤（我已实现并跑通，2Play 共解出 **501** 个池）：

1. `CWS` 头 → `zlib` 解压；跳过 8 字节文件头 + RECT / 帧率 / 帧数；
2. 顺序读 tag stream（`code = rh >> 6`、`len = rh & 0x3F`；`len == 0x3F` 时后面再跟 4 字节长度），
   `DefineSprite(39)` 要递归进去；
3. 在 `DoAction(12)` / `DoInitAction(59)` 的负载里逐条读 action record
   （`op >= 0x80` 时后跟 2 字节长度字段；`op < 0x80` 里只有 `0x35` WaitForFrame 有 3 字节负载），
   遇到 `0x88` 即常量池：`UI16 count` + count 个 NUL 结尾字符串；
4. 池头结构固定为 `_global, <包第1段>, Object, <包其余段…>, <类名>, …`，
   用它把池与类配对；然后把 `.as` 里的 `§§constant(N)` 就地替换为 `pool[N]`（不改变行号）。

> 复现工具：仓库里已固化同方法的脚本 `doc/tools/as2_constpool.py`（扫描/导出）与
> `doc/tools/as2_resolve.py`（回填）；本文数值可用它们逐条复核。
> 本文写作时的独立实现（临时脚本，未入库）在同一份 SWF 上也解出 **501** 个池，结果一致。

**自校验（三处独立互证，全部通过）**：

| 池内容 | 明文代码 | 结论 |
|---|---|---|
| `CMap_Cell` 池 `[45] = mCollide_Solid`，`:742` 赋值 `1`；`[161] = mCollide_Navigation`，`:937` = `StaticImpassable \| Object` = **131** | 结构推断时我算出 BFS 阻挡掩码 `[161] = 131` | 一致 |
| `CMap_Cell` 池 `[97]/[98]/[99] = RETURNINDEXEDARRAY / NUMERIC / DESCENDING` | `:318` 的 `sortOn(nDist, …)` | 一致（排序选项推断被证实） |
| `CThing_Creature` 池 `[5] = mFlags`、`[6] = CThing`、`[7] = mFlag_Collidable` | `CThing.as:139` 的 `mFlag_Collidable = 1` | 一致 |

⇒ 本文原先标为「成员名加密，未能恢复」的结论**大部分已升级为 A 档事实**；
下列文件现在都能读出真名：`CMap_Cell.as`（pool 39）、`CMap.as`（pool 27）、
`CMap_Collide.as`（pool 35）、`CMap_Mapwho.as`（pool 315）、`CMap_Math.as`（pool 348）、
`CThing_Position.as`（pool 38）、`CThing_Navigation.as`（pool 261）、`CMap_Navigation.as`（pool 30）。

**两个仍存在的限制**：
- **文件名与类内容的错位修不了**（§1 表那里的三个错位是 FFDec 的导出问题，常量池只补名字）；
- `CMap_Navigation.as` 这种**一个 `.as` 里混了多个脚本块**的文件，**单一池映射会失败**
  （用 pool 30 替换后有 20 个索引越界：`[12,13,14,15,16,20,23,25,28,30,31,33,35,39,41,44,45,46,48,49]`
  —— 这些属于文件里另外那个"地图基类"块的池）。**可行做法是按块切开、每块各用它的池**；
  本文涉及导航的部分**不依赖该文件**（导航真身在 `CMap_Cell`，且其池覆盖完整、零越界）。

---

## 2. Q1 · 地图如何离散化

### 2.1 格子尺寸 = 32 世界像素

| 常量 | 值 | 出处 |
|---|---|---|
| `CMap_Cell.mCellSize`（整型标量） | `32` | `__Packages/World/Map/CMap_Cell.as:703`：`}[§§constant(162)] = 32;` |
| `CMap_Cell.mSize`（Point） | `new Point(32, 32)` | `__Packages/World/Map/CMap_Cell.as:716`：`[§§constant(46)] = new ...Point(§§constant(162),§§constant(162))` |
| 独立复现 | `tp.mX * 32`、`tp.mY * 32` | `[MoreRooms] __Packages/World/CWorld.as:400`（`DrawCircle`） |

【事实】格子在“世界像素空间”里是 32×32；格子的**格坐标**是整数，**格中心**是 `(x+0.5, y+0.5)`
（`__Packages/World/Map/CMap_Cell.as:18`：`new Vector3(x + 0.5, y + 0.5, 0)`）。

【事实】引擎里存在两套坐标：
- **格坐标（cell units，float）**：`CThing_Position.mX/mY/mZ`（`CThing_Position` 就是 scidd 的 `CVector3` 子类）。
- **像素坐标**：格坐标 × 32。
  证据：`__Packages/World/Map/CMap_Decal.as:39-40`、`:52-53`
  （`(p.mY + …) * World.Map.CMap_Cell.mSize.y`）；
  `__Packages/Thing/Object/CThing_Object_WallMovable.as:121-122`
  （`pDraw.y = (mPosition.mY + mPosition.mZ * CThing_Position.mPFactor) * CMap_Cell.mSize.y - mDrawPosition.y`）。
  高度的换算因子是 `CThing_Position.mPFactor = 1`（`__Packages/Thing/Math/CThing_Position.as:306`：[§§constant(18)] = 1）。

#### ⚠️ 常见误读纠正：`& 0xFFFFFF` **不是**“1 世界单位 = 1 格”

`__Packages/Thing/Creature/CThing_Creature_Devil.as:113` 写的是
```actionscript
this.mCurrentCell = this.mMap.mCells[this.mPosition.mY & 0xFFFFFF][this.mPosition.mX & 0xFFFFFF];
```
**不要**据此得出“位置就是整数格号、地图没有 32 倍换算”。理由（三条独立证据）：

1. `& 0xFFFFFF` 在 AS2 里是**按位与 → 强制转 int32**，对正数等价于 `Math.floor`，
   它同时承担了**取整**和**下标合法化**。位置值是**格单位下的浮点数**：
   `__Packages/World/Map/CMap_Cell.as:18` 把格中心定义为 `(x + 0.5, y + 0.5)`；
   `__Packages/Thing/Creature/CThing_Creature_Devil.as:114` 用
   `Math.atan2((target.mY & 0xFFFFFF) + 0.5 - pos.mY, …)` 计算“朝**目标格中心**”的角度
   —— 若位置本来就是整数格号且 1:1，这个 `+ 0.5` 毫无意义。
2. 渲染时**必须乘 32** 才是像素：
   `__Packages/Thing/Object/CThing_Object_WallMovable.as:121-122`
   （`pDraw.x = mPosition.mX * CMap_Cell.mSize.x - mDrawPosition.x`，而 `mDrawPosition`
   是像素量级的滚动偏移，见 `[MoreRooms] __Packages/World/CWorld.as:57`、`:167-169`）。
3. 房间标记（放在房间 MC 里的舞台实例）是**像素坐标**，加载时显式做了一次“屏幕 → 格”换算：
   `[MoreRooms] __Packages/World/CWorld.as:90-91`
   `_loc2_ = _loc3_.mPosition.ConvertScreenToCell();`，
   对应实现就是除以 `mSize`：`__Packages/Thing/Math/CThing_Position.as:23-28`
   （`this[5] /= mCellSize.x; this[6] /= mCellSize.y;`）。

**正确结论**：地图是 `mCells[y][x]` 的稠密二维数组（这一条是对的，
`__Packages/World/Map/CMap.as:39-50`、`:157-160`），而下标由
`floor(格单位坐标) = 浮点位置 & 0xFFFFFF` 得到；**格单位坐标 × 32 = 像素坐标**。

### 2.2 地图尺寸：**由房间美术决定，脚本里没有数值**

- 【事实】`CMap` 构造时算出格子矩阵尺寸：
  `__Packages/World/Map/CMap.as:17`
  `this[9] = new Point(floor(this[6][14] / CMap[11][9][14]), floor(this[6][10] / CMap[11][9][10]))`
  → `mMapSize = floor(worldSize / cellSize)`，`[14]`=width、`[10]`=height。
- 【事实】`worldSize` 来自 SWF 库里一个叫 `mWorldSize` 的元件（按 CLASSID 向上找 10 层原型）：
  `__Packages/World/Map/CMap.as:265`：`this.mWorld = this.mArea("mWorldSize");`
  查找实现见 `__Packages/World/Map/CMap.as:268-282`（最多 10 层）。
- 【事实】房间的像素尺寸在 MoreRooms 里可直接读到：
  `[MoreRooms] __Packages/World/CWorld.as:50`
  `this.mArea = new flash.geom.Rectangle(0,0,this.mcRoomData._Size._width,this.mcRoomData._Size._height);`
  即**房间 MC 的包围盒**；视口尺寸是 `[MoreRooms] __Packages/World/CWorld.as:49`
  （`this._Size`，SWF 头显示 12800×9600 twips = **640×480**）。
- 【未恢复】**具体房间是几格 × 几格，未能恢复。** 尝试过的路径：
  1. grep 两棵 linearized 树的 `mWorldSize|mWorldSize|_Size|mcRoomData|mMapSize|InitCells` → 只命中上面两行；
  2. grep 2Play `__Packages/World/Init/*`、`Piece/*.as` → 这些文件只做 `Object.registerClass`，没有坐标或尺寸
     （例：`__Packages/World/Init/CWorld_Init_CollisionSolid.as:18`、`World.as:3`）；
  3. 尺寸不是脚本常量而是库元件包围盒 ⇒ **只能从 SWF 美术/舞台实例上量**。
  4. Godot 重制建议：把地图尺寸做成房间资源参数（例如 40×30 格 = 1280×960 px）。

### 2.3 边界

【事实】初始化时给最外一圈格子打上边界标志：

- `__Packages/World/Map/CMap.as:51`：`var _loc7_ = CMap_Cell[37] | CMap_Cell[38];`（两个静态标志的并集）
- `__Packages/World/Map/CMap.as:53-59`：`mCells[0][x]` 与 `mCells[H-1][x]` 全部 `[23] = _loc7_`
- `__Packages/World/Map/CMap.as:60-65`：`mCells[y][0]` 与 `mCells[y][W-1]` 全部 `[23] = _loc7_`
- 名称出处：【事实】`[MoreRooms] __Packages/World/Map/CMap_Collide.as:74`、`:131`
  用 `World.Map.CMap_Cell.mCollide_EdgeOfMap` 判定“撞到地图边界”。

---

## 3. Q2 · 每个格子存了什么

`CMap_Cell` 的构造函数（`__Packages/World/Map/CMap_Cell.as:13-25`，明文结构 + `§§constant` 成员名）：

```
CMap_Cell(x, y) {
    this[5]  = new Point(x, y);                       // 格坐标（整数）
    this[9]  = this[5];                               // 同一对象的别名
    this[10] = new Point(x + 1, y + 1);               // 右下角（格坐标）
    this[11] = new Vector3(x + 0.5, y + 0.5, 0);      // 格中心（scidd CVector3）
    this[15] = new Rectangle(this[5].x, this[5].y, 1, 1); // 1×1 格的矩形
    this[19] = this[5];                               // 别名
    this[20] = 0;                                     // mObjects 计数
    this[21] = CMap_Cell[22];                         // mCollide 位掩码，初值 0（:729 [22] = 0）
    this[23] = new <集合类>();                         // mObjects：按 uniqueID 索引的对象字典
    this[25] = -1;                                    // 访问戳（Nav 会话标记）
}
```

对照 `§§constant` 编号与明文别名（两版一致，且能被完全干净的 MoreRooms 代码交叉确认）：

| §索引 | 角色 | 名称证据 |
|---|---|---|
| `[5]/[9]/[19]` | 格坐标 Point | `__Packages/World/Map/CMap_Cell.as:15-20` |
| `[10]` | 右下角 | `:17` |
| `[11]` | 格中心 Vector3 | `:18` |
| `[15]` | 1×1 矩形 | `:19` |
| `[20]` | 对象计数 | `:21`、`:96`、`:101` |
| `[21]` | **`mCollide` 位掩码** | `[MoreRooms] __Packages/World/Map/CMap_Collide.as:41`（`_loc3_[_loc2_].mCollide \|= cFlags`）↔ `CMap_Cell.as:36` |
| `[23]` | **`mObjects` 对象字典** | `[MoreRooms] __Packages/World/Map/CMap_Collide.as:176`、`:208`（`_loc8_[_loc11_].mObjects`） |
| `[28]/[29]` | **`mAdjacentCells` 8 邻居数组** | `__Packages/Thing/Creature/CThing_Creature_Devil.as:210`（明文 `mAdjacentCells`） |
| `[30]/[31]/[32]/[33]` | 邻居 0/2/4/6（即四正向） | `CMap_Cell.as:30-33` |
| `[25]` | 访问戳 | `CMap_Cell.as:24`（初值 -1）、`:681-684` |
| `[93]` | 导航代价（流场值） | `CMap_Cell.as:684`、`:318` 排序键 |
| `[101]` | 由 `[96]` 算出的“可行方向位掩码” | `CMap_Cell.as:389`、`:443-506` |
| `[94]` | 动态方法名前缀（`"NavReal_"`） | `CMap_Cell.as:341`、`:347`；`CThing_Creature_Devil.as:116` 用 `"NavReal_" + dir` 调用，可反推前缀 |

**8 邻居的排布（事实，且很重要）**：
`__Packages/World/Map/CMap_Cell.as:26-35`
```
mAdjacentCells(tList) { this[28] = tList; this[29] = tList;
    this[30] = tList[0]; this[31] = tList[2]; this[32] = tList[4]; this[33] = tList[6];
    this[34] = tList[0]; }
```
⇒ 邻居数组长度 8，**偶数下标 = 四正向（0/2/4/6）**，**奇数下标 = 对角（1/3/5/7）**。
方向索引用 `& 7` 取模回绕（`CMap_Cell.as:130`、`:145`、`:363-380`）。

### 3.1 `mCollide` 的 9 个位 + 全部复合掩码（**常量池恢复，已确证**）

下表由「常量池恢复」得到（方法见 §1.3），**名字与数值都是 A 档事实**。
行号 = `__Packages/World/Map/CMap_Cell.as`（恢复前后行号不变）。

**基础 9 位**（`:729-846`）：

| 成员名 | 值 | 行号 | 语义（由调用点读出） |
|---|---|---|---|
| `mCollide_None` | 0 | `:729` | 默认值（构造函数 `:548` 用它初始化 `mCollide`） |
| `mCollide_Solid` | 1 | `:742` | 房间静态实体（`MarkArea_PP` 刷出来的矩形） |
| `mCollide_Ledge` | 2 | `:755` | 台阶/棱边（与 Solid 合成 `StaticImpassable`） |
| `mCollide_Shot` | 4 | `:768` | 子弹（`mCollide_*` 里唯一与射击物相关的位） |
| `mCollide_Path` | 8 | `:781` | 通路 |
| `mCollide_Road` | 16 | `:794` | 道路 |
| `mCollide_Creature` | 32 | `:807` | 生物占位 |
| `mCollide_Player` | 64 | `:820` | 玩家占位（玩家每帧写自己所在格） |
| `mCollide_Object` | 128 | `:833` | **动态障碍（木桶）占位** |
| `mCollide_EdgeOfMap` | 256 | `:846` | 地图边界 |

**复合掩码**（`:859-937`，全部由上面 9 位按位或得到）：

| 成员名 | 定义 | 值 | 行号 |
|---|---|---|---|
| `mCollide_StaticImpassable` | `Ledge \| Solid` | **3** | `:859` |
| `mCollide_NonShootable` | `Solid` | 1 | `:872` |
| `mCollide_NonMovable` | `StaticImpassable \| Creature \| Object \| Player` | **227** | `:885` |
| `mCollide_Moving` | `Creature \| Player` | 96 | `:898` |
| `mCollide_NonMovablePlayer` | 同 `NonMovable` | 227 | `:911` |
| `mCollide_NoSpawn` | `Creature \| Object` | 160 | `:924` |
| `mCollide_Navigation` | `StaticImpassable \| Object` | **131** | `:937` |

> ✅ **两条此前的推断被证实**：
> ① BFS 铺场的固定阻挡掩码 `[161]` 就是 `mCollide_Navigation = 131`（`CMap_Cell.as:937` ↔ `:681`）；
> ② 恶魔寻路传入的 `mCollide_NonMovable`（`CThing_Creature_Devil.as:128`）= **227**
> （= 静态不可通行 + 生物 + 木桶 + 玩家，即"所有非我方实体"）。

**方向位**（`:976-1067`；方向 0..7 = E, SE, S, SW, W, NW, N, NE，y 轴向下）：

| 方向 | 名 | 值 | 行号 |
|---|---|---|---|
| 0 | `mDirection_E` | 1 | `:976` |
| 1 | `mDirection_SE` | 2 | `:989` |
| 2 | `mDirection_S` | 4 | `:1002` |
| 3 | `mDirection_SW` | 8 | `:1015` |
| 4 | `mDirection_W` | 16 | `:1028` |
| 5 | `mDirection_NW` | 32 | `:1041` |
| 6 | `mDirection_N` | 64 | `:1054` |
| 7 | `mDirection_NE` | 128 | `:1067` |
| — | `mDirections_Diagonal` | 170 | `:1080` |
| — | `mDirections_Straight` | 85 | `:1093` |
| — | `mDirections_All` | 255 | `:1106` |

"遮蔽掩码" `mDirectionM_*` = 去掉该方向**及其两侧邻接方向**（`:1119-1210`）：
`mDirectionM_E = ~(E|NE|SE) = ~131`、`mDirectionM_S = ~(S|SE|SW) = ~14`、
`mDirectionM_W = ~(W|SW|NW) = ~56`、`mDirectionM_N = ~(N|NW|NE) = ~224`；
对角只需去掉自己：`mDirectionM_SE = ~2`、`mDirectionM_SW = ~8`、`mDirectionM_NW = ~32`、`mDirectionM_NE = ~128`。
⇒ 语义是"**一个正向被堵，则通往它的两条对角也不可走**"（`Nav_VD` 用它们做掩码收窄）。

其余静态成员：`mCellSize = 32`（`:703`）、`mSize = Point(32,32)`（`:716`）、
`mAdjacentCells_Amount = 8`（`:950`）、`mCurrentSessionID = 0`（`:963`）、
`xPOI/yPOI` = 两个复用的 Point（`:1223`、`:1236`）、`nSDist = 0`（`:1249`）、
`nInterations = 5`（`:1262`）、`nTimeOut = 3`（`:1275`）。


---

## 4. Q3 · “可通行”如何判定

### 4.1 判定式（事实）

**按方向探测**：`CMap_Cell.CollideFlagsInDirection(d)`（`__Packages/World/Map/CMap_Cell.as:115-119`，§索引 `[60]`）

```
CollideFlagsInDirection(d):
    f = mAdjacentCells[d].mCollide
    if (d 是偶数，即四正向) return f
    else return f | mAdjacentCells[(d-1)&7].mCollide | mAdjacentCells[(d+1)&7].mCollide
```
> 即：**对角方向只有在两个相邻正向都空时才算空**。名字来自
> `[MoreRooms] __Packages/Thing/Math/CThing_Navigation.as:454`（明文调用 `_loc6_.CollideFlagsInDirection(tDirection)`）。

**同一语义的 8 个零参版本**（事实，`CMap_Cell.as:507-538`，§索引 `[137]`-`[144]`）：

| §索引 | 返回 | 行号 |
|---|---|---|
| `[137]` | `mAdjacentCells[0].mCollide` | `:507-510` |
| `[138]` | `[1] \| [0] \| [2]` 的 mCollide | `:511-514` |
| `[139]` | `mAdjacentCells[2].mCollide` | `:515-518` |
| `[140]` | `[3] \| [2] \| [4]` | `:519-522` |
| `[141]` | `mAdjacentCells[4].mCollide` | `:523-526` |
| `[142]` | `[5] \| [4] \| [6]` | `:527-530` |
| `[143]` | `mAdjacentCells[6].mCollide` | `:531-534` |
| `[144]` | `[7] \| [6] \| [0]` | `:535-538` |

**这就是 `NavReal_<d>()`**：
- 【事实】调用形态：`var _loc3_ = this.mCurrentCell["NavReal_" + this.mTarget_Direction]();`
  `__Packages/Thing/Creature/CThing_Creature_Devil.as:116`
- 【事实】返回值被当成**碰撞标志位**用：`:117`（`!(_loc3_ & mCollide_Player)`）、`:120`（`_loc3_ & mCollide_Object`）
- 【事实】内部等价用法：`__Packages/World/Map/CMap_Cell.as:341`、`:347`
  `if(!(this[§§constant(94) + d2]() & tCollideFlags)) return d2;`
  （`[94]` 是字符串前缀，`+ d2` 拼出 `"NavReal_0".."NavReal_7"`）

⇒ **可通行判定 = `NavReal_<d>() & 阻挡掩码 == 0`**，即“目标方向（对角含两侧正向）的 `mCollide` 与掩码无交集”。

### 4.2 两张“可通行”掩码表（事实）

1. **BFS 铺场时**用固定掩码 `[161] = 131`（`CMap_Cell.as:935`）：
   `CMap_Cell.as:681` `if(!(this[21] & CMap_Cell[161] || this[25] == CMap_Cell[148]))` → 命中 131 的格子不入队。
2. **移动决策时**用调用方给的掩码：恶魔传 `mCollide_NonMovable`
   （`__Packages/Thing/Creature/CThing_Creature_Devil.as:128`）。

### 4.3 与 `CThing.mFlag_Collidable` 的关系（事实：两套独立系统）

| | 导航 / 格子 | 物理碰撞 |
|---|---|---|
| 数据 | 格子的 `mCollide` 位掩码 | `CThing.mFlags` 的 `mFlag_Collidable` |
| 谁写 | 房间初始化（`MarkArea_PP`）、玩家每帧、木桶生灭 | 对象自己 `this.mFlags \|= …mFlag_Collidable` |
| 谁读 | `NavReal_*` / `CollideFlagsInDirection` / BFS | `CMap_Collide.Collide_Mapwho` |
| 证据 | `[MoreRooms] __Packages/World/CWorld.as:95`；`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:573`；`__Packages/Thing/Object/CThing_Object_WallMovable.as:72,82` | `[MoreRooms] __Packages/World/Map/CMap_Collide.as:180`（`_loc2_.mFlags & Thing.CThing.mFlag_Collidable`）；阈值表 `__Packages/Thing/CThing.as:139-189` |

【重要 观察】`mCollide_*`（格子标志）与 `mFlag_*`（CThing 标志）**数值空间重叠**（都是 1,2,4,…），
但作用域完全不同：前者是“格子被谁占用/阻挡”，后者是“这个 thing 参不参与圆-圆分离”。
`CMap_Collide` 里两种都很自然地同时出现（`__Packages/World/Map/CMap_Collide.as:45` vs `:36`），
移植时**务必分成两个独立字段**，不要合并。

### 4.4 物理碰撞（另一套，供参考）

- 【事实】矩形取格：`this.mMap.GetCellList_Area(new Rectangle(p.x-r, p.y-r, 2r, 2r), tMinArea)`
  （`__Packages/World/Map/CMap.as:179-202`；`[MoreRooms] __Packages/World/Map/CMap_Collide.as:157,169,200,284`）
- 【事实】圆-圆分离：`if(dist < main_r + other.mRadius) { push apart }`
  （`[MoreRooms] __Packages/World/Map/CMap_Collide.as:182-187`、`:215-220`）
- 【事实】**贴墙滑动**（轴分离）：先整向量试，失败则只试 x、再只试 y
  （`[MoreRooms] __Packages/World/Map/CMap_Collide.as:126-153`）
- 【事实】**反弹**：`d' = d - 2(d·n)n`
  （`[MoreRooms] __Packages/World/Map/CMap_Collide.as:110-113`）
- 【事实·2026-10-22 修正】玩家移动迭代 **3** 次，生物 **1** 次；对墙检测是**玩家**用 `mRadius * 0.85` 收缩、
  **生物用完整 `mRadius`**（原文写反了，已对照 `F:\scripts\__Packages\World\Map\CMap_Collide.as` 确证：
  `PlayerCollide :58` 用 `mRadius*0.85` 且循环 3 次；`CreatureCollide :82` 用完整半径且循环 1 次）。
  另：玩家的圆-圆分离（`Collide_Mapwho`）步骤受设置项 `CMain.mSaveData.mCollisionsActive` 开关控制
  （`:52-57`），生物无条件分离。
- 【事实】射线/线段碰撞是**步进采样**：`_StepSize = 1`（`[MoreRooms] __Packages/World/Map/CMap_Collide.as:310`），
  步数 `= |p2-p1| / 1`，每步做 `LineIntersection`（`:231-255`、`:282-303`）。
  细节已由 `F:\scripts` 同文件 `:242-317` 确证：墙只判 `mCollide_Solid`（**Ledge 不挡视线**）；
  生物命中 = 点线距离² `< mRadius²` 且 `mAffectFlags` 与查询掩码匹配；多命中取离起点最近；
  返回的 `mPOI` 沿射线回退命中物的 `mRadius`。

---

## 5. Q4 · 寻路算法到底是什么

### 5.0 先排除：**不是 A\***（也没有按需搜索）

- 【事实】**没有 A\* 的任何特征**：全树（两版 linearized）没有 open/closed 表、
  没有 `g/h/f`、没有 priority queue / heap、没有“路径数组”回传。
  生物每帧只调一次 `Nav_Direction` 并立刻得到一个**方向**，没有把路径存下来的地方
  （`__Packages/Thing/Creature/CThing_Creature_Devil.as:128-133`）。
- 【事实】**没有按需搜索**：没有“给定起点终点做一次搜索”的入口。
  唯一的搜索是**全局周期性铺场**（§5.1），入口是"把玩家所在格作为种子"的静态函数
  （`__Packages/Thing/CThing_Collection.as:168`）。
- 因此原版的架构是：
  **① 每帧全局铺一次「到最近玩家的距离场」（分帧增量） → ② 每格自带方向决策 `Nav_Direction` → ③ 生物只查自己所在格。**
  外加 **④ 区域查询带 session id 去重**（§5.4）。

> ✅ **后续已用「常量池恢复」（§1.3）把这一层升级为 A 档事实**：
> `CMap_Cell` 的池（pool 39，零越界）把 `CMap_Cell.as` 全部还原成真名，
> 于是 `Nav_Update` / `NF_4` / `Nav_Direction` / `Nav_VD` / `NavReal_*` / `NavDir_CW_*` 的可读源码全部到手。
> 下面 §5.0.1 是**恢复后的确证实现**（行号与原文件一致）。

### 5.0.1 常量池恢复后的确切实现（A 档，源码片段）

**① 分帧增量铺场**（`__Packages/World/Map/CMap_Cell.as:589-621`，静态方法 `Nav_Update`）：

```actionscript
[CMap_Cell.Nav_Update] = function(sCellList)
{
    CMap_Cell.nSTimer = getTimer();                    // :591
    CMap_Cell.nFullScanCount = 0;                       // :592
    if(CMap_Cell.nState == restart || CMap_Cell.nState == undefined) {      // :596
        CMap_Cell.nList = new Array();                                          // :598
        CMap_Cell.nSID = CMap_Cell.nSTimer;                                     // :599
        CMap_Cell.nSDist = 0;                                                   // :600
        for(var _loc5_ in sCellList) { sCellList[_loc5_].NF_4(); }               // :601-604 种子
        _loc3_ = 0;
        while(_loc3_ < 5 && CMap_Cell.nList.length) {                           // :606  每帧 5 圈
            CMap_Cell.pList = CMap_Cell.nList; CMap_Cell.nList = new Array();    // :608-609
            for(var _loc2_ in CMap_Cell.pList) {
                _loc1_ = CMap_Cell.pList[_loc2_].ac;                            // :612  邻居数组
                _loc1_[0].NF_4(); _loc1_[2].NF_4(); _loc1_[4].NF_4(); _loc1_[6].NF_4();  // :613-616 只扩四正向
            }
            CMap_Cell.nSDist++;                                                 // :618  环数 = 代价
            _loc3_ = _loc3_ + 1;
        }
        CMap_Cell.nState = !CMap_Cell.nList.length ? finished : resume;         // :621
    }
    else if(CMap_Cell.nState == resume) { /* :623-654 继续，带 nInterations / nTimeOut 预算 */ }
    else if(CMap_Cell.nState == continue) { /* :655-677 超时续跑 */ }
};
```

**② 入队**（`:679-688`，实例方法 `NF_4`）：

```actionscript
[Nav_Update] 里用到的实例方法：
NF_4 = function() {
    if(!(this.mCollide & CMap_Cell.mCollide_Navigation            // :681  = 131
         || this.nID == CMap_Cell.nSID)) {                        //      本会话已访问
        this.nID   = CMap_Cell.nSID;                              // :683  打会话戳
        this.nDist = CMap_Cell.nSDist;                            // :684  记代价 = 环数
        CMap_Cell.nList.push(this);                               // :685  入队
    }
};
```

**③ 梯度下降 + 排序**（`:280-335`，实例方法 `Nav_Direction`）：

```actionscript
[Nav_Direction] = function(cDir, tDir, tCollideFlags, tForceIt) {
    if(CMap_Cell.nSTimer - this.nID < 2000) {                     // :287  流场新鲜？
        if(this.ac[tDir].nDist < this.nDist) {                    // :290  期望方向是下坡
            if(!(this["NavReal_" + tDir]() & tCollideFlags)) return tDir;   // :292-294
        }
        if(this.ac[cDir].nDist < this.nDist) {                    // :297  原方向是下坡
            if(!(this["NavReal_" + cDir]() & tCollideFlags)) return cDir;   // :299-301
        }
        if(tForceIt == false && ++CMap_Cell.nFullScanCount > 5) return -1;  // :304-309
        if(this.Nav_VD(tCollideFlags) == 0) return -1;            // :311-316  全堵
        _loc4_ = this.ac.sortOn(nDist,                           // :318  ★ 排序选项已确证
                   eval(Array)[RETURNINDEXEDARRAY] | eval(Array)[NUMERIC] | eval(Array)[DESCENDING]);
        _loc2_ = _loc4_[length] - 1;                              // :319
        while(_loc2_ >= 0) {                                      // :320
            _loc3_ = _loc4_[_loc2_];
            if(this.nVD & 1 << _loc3_) return _loc3_;              // :323-326  代价最小且可行
            _loc2_ = _loc2_ - 1;
        }
        return -1;                                                // :332
    }
    return this[NavReal_Dir](tDir, cDir, tCollideFlags);          // :334  流场不新鲜 → 局部兜底
};
```

**④ 可行方向掩码**（`:387-442`，`Nav_VD`）与 **⑤ 局部兜底**（`:336-386`，`NavReal_Dir`）
与 **⑥ 16 个方向解析器**（`:443-506`，`NavDir_CW_0..7` / `NavDir_CCW_0..7`）
与 **⑦ 8 个碰撞探测**（`:507-538`，`NavReal_0..7`）—— 结构与我此前的 B 档读数完全一致，
现在只是把 `[90]/[96]/[102]/[117]…[144]` 换成了真名：

| §索引 | 真名 | 行号 | 作用 |
|---|---|---|---|
| `[90]` | `Nav_Direction(cDir,tDir,mask,forceIt)` | `:280-335` | 主决策 |
| `[96]` | `Nav_VD(mask)` | `:387-442` | 算出可行方向位掩码 `nVD` |
| `[101]` | `nVD` | `:389` | 可行方向位掩码 |
| `[102]` | `NavReal_Dir(d2,d1,mask)` | `:336-386` | 局部方向试探（贴墙绕行） |
| `[117]-[128]` | `NavDir_CW_0/2/4/6/1/3/5/7` | `:443-474` | 顺时针偏好：期望方向堵了往哪边绕 |
| `[129]-[136]` | `NavDir_CCW_0/2/4/6/1/3/5/7` | `:475-506` | 逆时针偏好（另一个方向） |
| `[137]-[144]` | `NavReal_0..7` | `:507-538` | 方向 d 的碰撞位（对角 = 三个格子按位或） |
| `[145]` | `Nav_Reset()` | `:551-556` | 失效：`nState=restart; nSID=0; delete pList` |
| `[150]` | `Nav_Restart()` | `:569-576` | `nState = (nState != finished) ? nState : restart`，若 restart 则 `nSID++` |
| `[152]` | `Nav_Update(sCellList)` | `:589-678` | 铺场状态机 |
| `[155]` | `NF_4()` | `:679-688` | 入队（4 邻域扩展用） |
| `[60]` | `CollideFlagsInDirection(d)` | `:115-119` | 方向 d 的碰撞位 |
| `[64]` | `ValidMoveDirection()` | `:158-170` | 第一个可走的正向（刷怪点校验用） |
| `[61]` | `GetClearMoveDirection()` | 见 `:171-197` 区段 | 沿线段找第一个可通行点 |

**⑧ 状态常量**（池中明文）：`restart`（`:147`）、`finished`（`:151`）、`resume`（`:156`）、`continue`（`:160`）；
`nInterations = 5`（`:1262`）、`nTimeOut = 3`（`:1275`）、`nSDist = 0`（`:1249`）、`mCurrentSessionID = 0`（`:963`）。

### 5.1 距离场机制（B 档：结构可读，成员名加密）

证据链（除注明外均为事实）：

1. **数据结构**
   - 每个格子有 `[93]`（代价）与 `[25]`（访问戳）：`__Packages/World/Map/CMap_Cell.as:24`、`:684`
   - 流场状态**挂在类上（静态）**：`__Packages/World/Map/CMap_Cell.as:553-556`、`:591-600`、`:618`、`:675`
     全部写作 `CMap_Cell[146] / [148] / [149] / [153] / [154] / [91] / [95] = …`
     ⇒ 全局唯一一份，不是每个生物一份。
2. **种子 + 分环推进**（`__Packages/World/Map/CMap_Cell.as:589-678`，静态函数 `[152](sCellList)`）
   - `:591` `[91] = getTimer()`（本次铺场的起始时间）
   - `:592` `[95] = 0`（本轮放弃计数清零）
   - `:596` 仅当状态 `[146] == [147]` 或 `undefined`（即上一轮已铺完）时**重新播种**
   - `:598-604` `[153] = 新数组(); [148] = [91]; [154] = 0; for each cell in sCellList: cell.[155]();`
   - `:606-620` `while(_loc3_ < 5 && [153].length) { [149] = [153]; [153] = 新数组();
     for each c in [149]: c.mAdjacentCells[0/2/4/6].[155]();  [154]++; }`
     → **每轮只扩四正向 = 4 连通**；**每帧最多 5 圈**
   - `:621`/`:653`/`:676` `[146] = [153].length ? 继续 : 完成`
   - `:641-651`、`:655-677` 有 `getTimer() - [91] <= [159]` 的**时间预算**分支（超时就下帧继续）
3. **入队/访问函数**（`__Packages/World/Map/CMap_Cell.as:679-688`，实例方法 `[155]`）
   ```
   Visit() {
       if (!(mCollide & CMap_Cell[161]   /* =131 */
             || this[25] == CMap_Cell[148] /* 本会话已访问 */)) {
           this[25] = CMap_Cell[148];    // 打会话戳（= 本轮起始 getTimer()）
           this[93] = CMap_Cell[154];    // 记当前环数 = 代价
           CMap_Cell[153].push(this);    // 入下一圈
       }
   }
   ```
4. **代价 = BFS 环数**：`:684` `this[93] = CMap_Cell[154]`，`:618`/`:675` 每圈 `[154]++`。
   ⚠️ 注意一个**事实性怪癖**：`[154]` 的 `++` 在“扩展邻居”之后，所以
   源格与第 1 圈都拿到 0，第 2 圈拿 1 …… 等价于 `cost = 环数 - 1`（`__Packages/World/Map/CMap_Cell.as:600,610-618`）。
5. **梯度下降**（`__Packages/World/Map/CMap_Cell.as:311-332`，`Nav_Direction` 的“新鲜流场”分支）
   ```
   _loc4_ = mAdjacentCells[100]( /*[93]*/ , [97]|[98]|[99] );   // :318-319
   _loc2_ = _loc4_.length - 1;
   while (_loc2_ >= 0) {
       _loc3_ = _loc4_[_loc2_];
       if (this[101] & (1 << _loc3_)) return _loc3_;   // 可行方向里取排序末尾
       _loc2_--;
   }
   ```
   - 【推断】`mAdjacentCells[100](fieldName, options)` 形态 = AS2 `Array.sortOn(field, options)`
     （参数就是“字段名 + 排序选项按位或”），返回值被 `1 << x` 当作**方向下标**用
     ⇒ 排序选项里必定含 `Array.RETURNINDEXEDARRAY`（否则 `1 << 格子对象` 恒为 0，代码失效）。
     于是“取数组末尾”必须是**代价最小**者 ⇒ 选项里必含 `DESCENDING`。
     **具体选项常量值 `[97]/[98]/[99]` 被成员名加密，未能恢复**（`CMap_Cell.as:318-319`）。
   - 【推断】`[101]` 是“可行方向位掩码”，见下一条。
6. **可行方向位掩码 `[101]`**（`CMap_Cell.as:387-442`，方法 `[96](tCollideFlags)`）
   ```
   [101] = 255                              // :389，[103] = [108]|[177] = 170|85 = 255 (:1106)
   for d in {0,2,4,6}:
       if (mAdjacentCells[d].mCollide & tCollideFlags)
           [101] &= 去掉(d 及其两侧对角) 的掩码   // :390-405, 常量 :1117,1143,1169,1195
   // 然后再按对角可用性二次收窄 :410-440
   ```
   相关常量（事实）：方向位 `[118]=1,[109]=2,[119]=4,[111]=8,[122]=16,[113]=32,[120]=64,[115]=128`
   （`CMap_Cell.as:976,989,1002,1015,1028,1041,1054,1067`）；
   `[108] = 对角并 = 170`（`:1078`）、`[177] = 正向并 = 85`（`:1091`）、`[103] = 全 = 255`（`:1104`）；
   收窄掩码 `[104]=~131`、`[105]=~14`、`[106]=~56`、`[107]=~224`、`[110]=~2`、`[112]=~8`、`[114]=~32`、`[116]=~128`
   （`:1117,1143,1169,1195`、`:1130,1156,1182,1208`）。

### 5.2 `Nav_Direction` 的四参数含义 + 两条分支（事实 + 时间常量）

`__Packages/World/Map/CMap_Cell.as:280-335`（§索引 `[90]`，形参名 `(cDir, tDir, tCollideFlags, tForceIt)`）；
**唯一可确证的调用点**是 A 档明文 `__Packages/Thing/Creature/CThing_Creature_Devil.as:128`：

```actionscript
this.mTarget_Direction = this.mCurrentCell.Nav_Direction(
        _loc2_,                       // ① = this.mAngle.mDirection（上一帧的朝向）
        this.mTarget_Direction,        // ② = 期望方向（直线朝目标，见 :114-115）
        World.Map.CMap_Cell.mCollide_NonMovable,   // ③ = 阻挡掩码
        true);                         // ④ = forceIt
```

| # | 形参 | 调用点实参 | 含义（由代码读出） |
|---|---|---|---|
| ① | `cDir` | `this.mAngle.mDirection`（`CThing_Creature_Devil.as:112` 取，`_loc2_`） | **上一帧方向**。`Nav_Direction` 把它当“次优候选”：期望方向被堵时优先沿原方向继续（`:297-303`），
对外表现为贴墙滑行/转向平滑，而不是每帧重新选边。 |
| ② | `tDir` | `this.mTarget_Direction`（`:115` 由 `Math.atan2` 得到，再被本调用的**返回值覆盖**） | **期望方向** = “朝目标格中心直线”量化到 8 向。返回值写回同一字段 ⇒ 方向在生物身上**每帧缓存一次**。 |
| ③ | `tCollideFlags` | `CMap_Cell.mCollide_NonMovable` | 阻挡掩码，交给 `NavReal_<d>() & mask` 与 `ComputeOpenMask(mask)` 使用（`:290-317`）。 |
| ④ | `tForceIt` | `true` | 【推断】“强制”：为 `true` 时跳过 `++[95] > 5` 的提前放弃（`:304-310` 只在 `tForceIt == false` 时计数），
即允许它把“绕障”尝试做满。若为 `false`，同一轮铺场里累计失败 5 次就直接返回 -1。 |

```
Nav_Direction(cDir, tDir, mask, forceIt) {
    if (CMap_Cell[91] - this[25] < 2000) {          // :287  ← 2000 ms
        if (!(NavReal_<tDir>() & mask) && 邻居代价更优) return tDir;   // :290-296
        if (!(NavReal_<cDir>() & mask) && 邻居代价更优) return cDir;   // :297-303
        if (forceIt == false && (++CMap_Cell[95]) > 5) return -1;      // :304-310  ← 上限 5
        if (ComputeOpenMask(mask) == 0) return -1;                     // :311-317
        ... 排序取代价最小且可行的方向 ...                              // :318-328
        return -1;                                                     // :332
    }
    return LocalDirectionPreference(tDir, cDir, mask);                 // :334 → :336-386
}
```

- 【推断】判据 `CMap_Cell[91] - this[25] < 2000`：`[91]` 是本轮流场的起始 `getTimer()`，
  `this[25]` 是该格子的访问戳。**本轮流场访问过的格子**（`[25] >= [91]`）差值为负 ⇒ 走“梯度下降”分支；
  **没被本轮访问过（或属于更早的轮次）**的格子 ⇒ 走局部的方向试探分支。
  即：**“流场新鲜就用流场，不新鲜就用局部贪心”。** 2000ms 是这两条策略的分界（具体单位=毫秒，由 `getTimer()` 保证）。
- 【事实】`nFullScanCount`（原 `[95]`）是“本轮全局放弃计数”，每轮播种时清零（`:592`），超 5 次后 `Nav_Direction` 开始返回 -1。
- 【事实】局部试探分支 `:336-386`（`NavReal_Dir`）：先试目标方向，再试当前方向；都堵则按
  `d2 + n*sign & 7` 与 `d2 - n*sign & 7` 对称扩展（正向步长 2、对角步长 1，最多 ±3），全堵返回 -1。
  旋转侧 `sign` 在 `d1 != d2` 时按两方向间的劣弧侧选择；**`d1 == d2` 时随机**取侧
  （`random(2)*2-1`，`F:\scripts CMap_Cell.as:419`）。
- ✅ 【已确证·常量池恢复】那 **16 个零参方向解析方法**（`__Packages/World/Map/CMap_Cell.as:443-506`）
  的真名是 **`NavDir_CW_0/2/4/6/1/3/5/7`（`:443-474`）与 `NavDir_CCW_0/2/4/6/1/3/5/7`（`:475-506`）**：
  前者"顺时针"偏好，后者"逆时针"偏好；每个方法形如
  `return !(nVD & mDirection_<A>) ? (!(nVD & mDirection_<B>) ? (!(nVD & mDirection_<C>) ? -1 : D) : E) : F;`
  —— 即"沿着期望方向不行时，按固定手性依次退到两侧方向"。示例（`:443-446`）：
  ```actionscript
  _loc2_[NavDir_CW_0] = function() {
      return !(this[nVD] & CMap_Cell.mDirection_E) ? (!(this[nVD] & CMap_Cell.mDirection_S)
             ? (!(this[nVD] & CMap_Cell.mDirection_N) ? -1 : 6) : 2) : 0;
  };
  ```

### 5.3 一句话伪码（可直接照抄进 Godot）

```text
# 每帧（CThing_Collection.Process 末尾）
cells = [ world.map.get_cell(p.position) for p in players ]
CMap_Cell.nav_advance(cells)     # 见下

# CMap_Cell.nav_advance(seeds) —— 静态，全局唯一
if state == DONE or state == null:
    frontier_next = []
    stamp = Time.get_ticks_msec()
    ring = 0
    for c in seeds: c.visit()
while rings_done < 5 and frontier_next.size() > 0:
    frontier = frontier_next; frontier_next = []
    for c in frontier:
        for d in [0,2,4,6]:
            c.adjacent[d].visit()          # 4 连通
    ring += 1; rings_done += 1
    if elapsed_since_start > 3 ms: state = TIMEOUT; return

func visit():
    if (collide & 131) != 0 or self.stamp == class_stamp: return
    self.stamp = class_stamp
    self.cost  = class_ring
    frontier_next.append(self)

# 生物每帧
desired  = angle_to(target_cell) / 45°          # 8 方向
current  = my_angle.direction
d = Nav_Direction(current, desired, NonMovable, true)
if d == -1: state = Wait
else:       move_cell_to_cell(d)                 # 平滑插值到下一格中心
```

### 5.4 区域查询的 session-id 去重（事实）

地图/碰撞层的"矩形取格"接口有两个版本：

| 接口 | 签名 | 出处 |
|---|---|---|
| `CMap.GetCellList_Area(tArea, tMinArea)` | 返回矩形覆盖的所有格子 | `__Packages/World/Map/CMap.as:179-202`（§4.4 已引） |
| `CMap.GetCellList_Area_FilterSessionID(rArea, tMinArea, tSessionID)` | **同一 session 内每格只返回一次** | `__Packages/World/Map/CMap.as:203-232`；`[MoreRooms] __Packages/World/Map/CMap_Collide.as:284`；`[MoreRooms] __Packages/World/Map/CMap_Affect.as:110` |

机制（`__Packages/World/Map/CMap.as:215-232`）：遍历矩形内每个格子，
`if (cell[72] != tSessionID) { cell[72] = tSessionID; result.push(cell); }`
—— 名字已由常量池确证为 **`CMap_Cell.mCurrentSessionID`**（`CMap_Cell.as:963`，初值 0），
调用方每次查询前 `mCurrentSessionID++`（`[MoreRooms] __Packages/World/Map/CMap_Collide.as:244`）。

**为什么重要**：线段碰撞是**步进采样**（每步 1 单位，`[MoreRooms] __Packages/World/Map/CMap_Collide.as:310`），
一条穿过 10 格的子弹射线会把同一格查很多次；session-id 保证**每格只被处理一次**，
既省时间又避免同一格对同一发子弹重复触发（因为物体列表 `mObjects` 会被改动）。
**Godot 移植建议**：射线/爆炸扫描用 `PhysicsDirectSpaceState2D` 的 `intersect_*` 一次搞定，
或者照抄这个"帧内 session id"模式；不要每步都重新收集一次格子。

---

## 6. Q5 · 从格子到实际移动方向

【事实】生物拿到的是**方向索引 0..7**，然后交给“格到格”状态：

`__Packages/Thing/Creature/CThing_Creature_Devil.as:106-135`

```
State_GotoPlayer() {
    if (Brain()) return;                                        // :108 攻击优先
    _loc2_ = this.mAngle.mDirection;                            // :112 当前朝向
    this.mCurrentCell = this.mMap.mCells[this.mPosition.mY & 0xFFFFFF]
                                      [this.mPosition.mX & 0xFFFFFF];      // :113
    this.mTarget_Angle.mAngle = Math.atan2((target.mY & 0xFFFFFF) + 0.5 - pos.mY,
                                          (target.mX & 0xFFFFFF) + 0.5 - pos.mX); // :114
    this.mTarget_Direction = this.mTarget_Angle.mDirection;     // :115 直线方向 → 8 向
    var _loc3_ = this.mCurrentCell["NavReal_" + this.mTarget_Direction]();     // :116
    if (_loc3_ & CMap_Cell.mCollide_Object) {                   // :120 目标方向有木桶
        this.mAttackAngle = this.mAngle.Clone();                // :122
        this.SetState_WithDirection("State_Attack", _loc2_, this.mTarget_Direction); // :125
        return;
    }
    if ((this.mTarget_Direction = this.mCurrentCell.Nav_Direction(
             _loc2_, this.mTarget_Direction, CMap_Cell.mCollide_NonMovable, true)) == -1) { // :128
        this.SetState("State_Wait"); return;                    // :130 完全堵死 → 待机
    }
    this.SetState_WithDirection_Wait("State_CellToCell", _loc2_, this.mTarget_Direction); // :133
}
```

要点：
- **目标不是寻路算出来的路径点，而是一个方向**；移动是“当前格 → 相邻格中心”的逐格推进
  （`:133` 进入 `State_CellToCell`；格中心 = 格坐标 + 0.5，见 `CMap_Cell.as:18`、`:114`）。
- **平滑**由动画/插值层负责，不在导航层：`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:610`
  用 `Animate((myCell.y + 0.5 - cell.y), (myCell.x + 0.5 - cell.x))` 把“格间偏移”喂给动画做位置插值。
- **贴墙滑动 = 两层**：
  1. 方向层：`Nav_Direction` 的局部试探分支（`CMap_Cell.as:336-386`）与
     `Thing.Math.CThing_Navigation.MoveInDirection2(tDirection)`——
     先试 `dir`，再 `dir±1`、`dir±2`、`dir±3`，找到第一个不是 `mCollide_NonMovable` 的方向：
     `[MoreRooms] __Packages/Thing/Math/CThing_Navigation.as:447-476`（完全明文，可直接照抄）
  2. 物理层：`CMap_Collide.Collide_Map` 的轴分离滑动（§4.4）
- 【事实】`CThing_Navigation` 极薄：只有 `mOwner` / `mMap` 两个字段和 `MoveInDirection2`
  （`[MoreRooms] __Packages/Thing/Math/CThing_Navigation.as:434-438`：
  `this.mOwner = tOwner; this.mMap = this.mOwner.mWorld.mMap;`）。

---

## 7. Q6 · 多生物是否共享同一张导航数据？每帧重算还是缓存？

【事实】**全游戏一张共享流场，逐帧增量推进，不是每帧从零重算，也不是每个生物一份。**

1. 流场状态是**类静态成员**（常量池恢复后真名如下，`__Packages/World/Map/CMap_Cell.as`）：
   `nState`（`:553`、`:571`、`:596`、`:621`）、`nSID`（`:554`、`:599`、`:683`）、
   `pList`（`:555`、`:608`、`:629`）、`nList`（`:598`、`:609`、`:630`）、`nSDist`（`:600`、`:618`、`:675`）、
   `nSTimer`（`:591`）、`nFullScanCount`（`:592`、`:306`）
   ⇒ **全游戏一份**，不是每个生物一份。
2. 播种数据来自**所有玩家的格子**，每帧一次：
   `__Packages/Thing/CThing_Collection.as:159-168`
   ```
   CMap_Cell[46]();                                        // :159
   var _loc3_ = new <数组类>();                             // :160
   var _loc4_ = this[8][47][48];                            // :161  世界格子矩阵
   for (_loc5_ in this[5]) {                                // :163  this[5] = 玩家字典
       _loc2_ = this[5][_loc5_][42];                        // :165  玩家位置
       _loc3_[35](_loc4_[_loc2_[49] & 0xFFFFFF][_loc2_[50] & 0xFFFFFF]);  // :166 push 玩家所在格
   }
   CMap_Cell[51](_loc3_);                                  // :168  ← 把种子列表交给 CMap_Cell
   ```
   【推断】`:168` 的 `CMap_Cell[51](list)` 就是 `CMap_Cell.as:589` 的 `Nav_Update(sCellList)`
   （2Play 侧该文件成员名加密，无池可映射；但**形态与参数完全吻合**，且 `Nav_Update` 是
   `CMap_Cell` 上唯一接受"格子数组"的静态方法）。
   `[46]()`（`:159`）与 `Nav_Restart()`（`CMap_Cell.as:569-576`）形态吻合（无参、在铺场前调用）。
3. **增量**：`CMap_Cell.as:606` 每帧最多 5 圈（`nInterations = 5`，`:1262`），
   `:641-651`/`:655-677` 有 `nTimeOut = 3`（毫秒）的时间预算（`:1275`）。
   状态在 `:621`/`:653`/`:676` 被设为 `resume`/`finished`，下一帧从 `:623`/`:655` 续跑。
4. **重播种时机**：只有上一轮铺完（`nState == restart` 或 `undefined`）才会用新种子从零开始（`:596`）
   ⇒ 玩家移动**不会**立刻打断正在铺的流场。
5. **两段生命周期（易误读，必须分清）**：
   - `Nav_Reset()`（`__Packages/World/Map/CMap_Cell.as:551-556`）：
     `nState = restart; nSID = 0; delete pList;`
     —— **只在玩家对象构造时调用一次**（`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:563`，
     2Play 侧该调用点未找到明文）。它**只重置状态与前沿，不清除任何格子的 `nDist`/`nID`**。
   - `Nav_Update(sCellList)`（`:589-678`）：**每帧调用**。
     证据：① `__Packages/Thing/CThing_Collection.as:159-168`（东西管理器每帧 Process 末尾）；
     ② `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:606`
     在 `State_PlayerControl` 里调 `World.Map.CMap_Cell[§§constant(153)]()`，
     而该行所在的函数每帧负责读取输入/位移（`:590-605`）。
   ⇒ **正确表述**：「失效（`Nav_Reset`）是按玩家出生触发的；**铺场（`Nav_Update`）是每帧推进的滚动重建**」。
   不要理解成"铺一次就一直复用"——`nState` 回到 `restart` 后用新种子重铺是常态。
   ⚠️ 因为 `Nav_Reset` 不清格子，旧一轮的 `nDist` 会在重建期间被读到；这正是 `Nav_Direction:287`
   那道 `nSTimer - nID < 2000` 新鲜度闸门存在的原因（旧值 ⇒ 走局部 `NavReal_Dir` 兜底）。
6. **消费端不做缓存**：生物每帧直接读 `mCurrentCell` 与邻居的 `nDist`（`CMap_Cell.as:290-328`）。
   代价字段是每格一份（`nDist`），所以**「缓存」体现在格子上，而不是在每个生物身上**。

**复杂度**（供 Godot 参考）：单次完整铺场 O(W×H)，摊到多帧；
每帧实际工作量由 `min(5 圈, 3ms)` 封顶 ⇒ **帧率与地图大小解耦**，这是原版能跑 50fps 的关键。

---

## 8. Q7 · 动态障碍（移动墙 / 木桶 / 地雷）如何影响导航

### 8.1 事实：运行期写格子 `mCollide` 的**只有三处**

| 位置 | 动作 | 出处 |
|---|---|---|
| 房间加载 | `mCollide.MarkArea_PP(p1, p2, mCollide_Solid)` 把 CollisionSolid 标记的**矩形区域**整片刷成 Solid | `[MoreRooms] __Packages/World/CWorld.as:95`；实现 `[MoreRooms] __Packages/World/Map/CMap_Collide.as:30-46` |
| 玩家每帧 | `this.SetCollideDirection(this.mPosition, CMap_Cell.mCollide_Player)` | `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:573` |
| **木桶**生/灭 | 生：`this.mCurrentCell.mCollide \|= CMap_Cell.mCollide_Object;`<br>灭：`super.Dispose(); this.mCurrentCell.mCollide &= ~CMap_Cell.mCollide_Object;` | `__Packages/Thing/Object/CThing_Object_WallMovable.as:82`（实际内容为 `CThing_Object_Barrel`）、`:72` |

对全树做过 grep（`mCollide \|=` / `mCollide &=` / `MarkArea` / `MarkArea_PP`，
2Play 与 MoreRooms 两棵 linearized 全树）：**除上表之外没有其它运行期写 `mCollide` 的代码**。
⇒ 【事实 + 一句推断】

- **木桶**：会即时改变导航可通行性（同一帧内 `NavReal_d()` 立刻能看见），
  恶魔甚至把“目标方向上的木桶”当作要开枪打掉的东西（`__Packages/Thing/Creature/CThing_Creature_Devil.as:116-127`、
  `:210-213` —— 后者用 `mAdjacentCells[dir].mCollide & mCollide_Object` 决定是否对那一格放 `DevilAttack`）。
  木桶还有一段**等玩家离开才生效**的逻辑：若它落点格子上已有 `mCollide_Player`，
  则先进入 `Process_PlayerOnCell`，直到玩家离开才 `mFlags |= mFlag_Collidable` 并长大半径
  （`__Packages/Thing/Object/CThing_Object_WallMovable.as:84-96`；膨胀半径 `0.42` 于 `:99`、`:107`，单位=格）。
- **移动墙 `CThing_Object_WallMovable`**：**在本次反编译产物中未找到它的类体**
  （同名文件里装的是 `CThing_Object_Barrel`，见 §1 表）。文件名 `__Packages/Thing/Object/CThing_Object_Barrel.as`
  只有 9 行残片（`__Packages/Thing/Object/CThing_Object_Barrel.as:7,9`）。⇒ 【未恢复】，推定其影响方式与木桶相同（写同一批 `mCollide` 位）。
- **地雷 `CThing_Object_Mine`**：在本次导出的全树 grep 中**没有任何写 `mCollide` 的语句**，
  也没有引用 `NavReal_*` / `Nav_Direction`。⇒ 【事实】它不参与格子级导航阻挡（危险区只影响 AI 决策层，不影响可通行性）。
  （`__Packages/Thing/Object/CThing_Object_Mine.as` 全文件未出现 `mCollide` 写入。）

### 8.2 对 Godot 的移植建议

- 静态几何（墙/柱子）→ 烘焙进**不可变的阻挡位图**（原版用 `MarkArea_PP` 一次刷完）。
- 动态障碍（木桶/移动墙）→ 单独一个**动态阻挡位图**，只有它变化时把受影响的格子标记为“流场需要局部重铺”。
  原版靠“整张场逐帧重铺”隐式获得正确性；Godot 里可以做得更好（局部重铺或 dirty rect）。

### 8.3 「改格子碰撞位」→「导航场失效」的完整因果（事实 + 设计含义）

原版的链条是这样的（每一步都有出处）：

1. 木桶生成：`this.mCurrentCell.mCollide |= CMap_Cell.mCollide_Object;`（值 = **128**）
   —— `__Packages/Thing/Object/CThing_Object_WallMovable.as:82`（文件内实际是 Barrel 类）。
2. 木桶销毁：`super.Dispose(); this.mCurrentCell.mCollide &= ~CMap_Cell.mCollide_Object;`
   —— 同文件 `:72`。
3. **导航立刻就能看见它**：`NavReal_<d>()` 每次都**实时读**邻居的 `mCollide`
   （`__Packages/World/Map/CMap_Cell.as:509-537`），
   而 `mCollide_Navigation = StaticImpassable | Object = 131`（`:937`）
   **包含 `mCollide_Object`** ⇒ 木桶所在格当帧即从流场可通行集合中排除
   （`NF_4` 的 `if(!(this.mCollide & mCollide_Navigation …))`，`:681`）。
4. **流场不会立刻重算**：`Nav_Reset()` 只在玩家出生时调用
   （`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:563`），
   木桶生灭**不触发** `Nav_Reset`。重算要等当前这轮 `Nav_Update` 铺完
   （`nState == finished` → 下一帧 `restart` 用新种子重铺，`CMap_Cell.as:596`、`:621`）。
5. **旧值兜底**：重建期间旧格子的 `nDist` 仍在，所以 `Nav_Direction:287` 的
   `nSTimer - nID < 2000` 新鲜度闸门会把"上一轮遗留"的格子踢到
   局部 `NavReal_Dir` 分支（`:334`）；而 `NavReal_Dir` 又实时读 `NavReal_<d>()`，
   所以**即使流场是旧的，也不会穿进木桶**——它只会短暂走得不够聪明。

⇒ **设计含义**（原版靠"每帧滚动重铺 + 实时掩码探测"两条腿保证正确性）：
- **正确性**由实时掩码（第 3 步）保证，**最优性**由流场（第 4 步）保证；
- 因此 Godot 里**必须**让"可通行查询"直接读动态阻挡位（不要只信流场），
  并在动态阻挡变化时把相关区域标 dirty 触发局部重铺。
  两者缺一：只信流场 → 会撞木桶；只做局部绕行 → 会被墙卡住/绕远。

---

## 9. Q8 · 两个玩家同时在场上时，目标如何选

### 9.1 目标选择（事实）

- 恶魔每帧在 `Brain()` 里重新取目标：
  `__Packages/Thing/Creature/CThing_Creature_Devil.as:86`
  `this.mTarget_Player = this.mThing_Collection.GetClosestPlayer(this.mPosition);`
  紧接着 `:87` 缓存 `mTarget_Position`。
- `GetClosestPlayer` 的本体在 `CThing_Collection`（2Play 版成员名加密，控制流可读）：
  `__Packages/Thing/CThing_Collection.as:96-131`
  ```
  var _loc3_ = Number.MAX_VALUE;
  for (_loc6_ in this[5]) {                       // this[5] = 玩家字典（按 uniqueID）
      _loc2_ = this[5][_loc6_];
      if (!(_loc2_[40] & <某个 CThing 标志>)) {    // :114 跳过特定状态的玩家
          if ((_loc4_ = p[43](_loc2_[42])) < _loc3_) {  // :116 距离（p=自身位置）
              _loc3_ = _loc4_; _loc5_ = _loc2_;         // :118-119
          }
      }
  }
  if (!_loc5_) { for (_loc6_ in this[5]) return this[5][_loc6_]; }  // :123-130 兜底：任取一个
  return _loc5_;
  ```
  ⇒ **双玩家时：取“距离最近的、通过状态过滤的玩家”；全部不合格时退化为“字典里第一个玩家”。**
- 另有“另一个玩家”的取法（用于 HUD/双人交互，非 AI 目标）：
  `__Packages/Thing/CThing_Collection.as:133-143`
  `[44](tPlayer) → 遍历玩家字典，返回第一个 != tPlayer 的玩家`。
  【推断】2Play 的二次元 HUD 用的就是这个。
- **导航场本身不区分玩家**：种子列表把**所有**玩家的格子都塞进去（§7 第 2 点，`:163-167`）
  ⇒ 流场是“到最近玩家的距离”。
  【推断】因此 `Nav_Direction` 返回的方向天然指向最近玩家，与 `GetClosestPlayer` 的选择一致；
  两者不一致只可能出现在“两玩家距离几乎相同”的边界情况。

### 9.2 两版差异（必读）

- `[MoreRooms] __Packages/World/CWorld.as:359-365`：`Spawn_Player()` **只生成 `mSpawnPoint_Player[0]`**，
  是单人版；2Play 的对应代码在 `__Packages/World/CWorld.as`（724 行，严重加密）中，**未能恢复**。
- 但 2Play 的 `Object.registerClass` 侧确实准备了两个玩家出生类：
  `[MoreRooms] __Packages/World/CWorld.as:109-114`（`CWorld_Init_Player1` 与 `CWorld_Init_Player2`
  **都调用同一个 `AddSpawnPoint_Player`**）——两个玩家共用同一个出生点列表，靠下标区分。
  ⇒ 【推断】2Play 通过“取列表第 0 / 第 1 个元素”生成两名玩家。
- `CThing_Creature_Player.as` 在 2Play 里 495 行、成员名全加密（548 处 `§§constant`），
  **双人输入/复活差异未能恢复**；MoreRooms 版是单人的（`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:590-596`
  读 `this.mControls.LEFT/RIGHT/UP/DOWN` 单套按键）。

---

## 10. 照着写 Godot 代码：最小可复刻规格

### 10.1 数据结构

```gdscript
const CELL := 32.0                 # CMap_Cell.as:703 / :716
const DIRS8 := [Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1),
                Vector2i(-1,0), Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1)]
# 偶数下标 = 四正向；奇数 = 对角（CMap_Cell.as:26-35, :115-119）

class Cell:
    var cx: int; var cy: int
    var collide: int = 0                 # 9 位掩码，见 §3.1
    var objects: Dictionary = {}         # key = uniqueID（CMap_Cell.as:23）
    var adjacent: Array[Cell] = []       # 长度 8，含对角（CMap_Cell.as:28）
    var nav_stamp: int = -1              # CMap_Cell.as:24（[25]）
    var nav_cost: float = INF            # CMap_Cell.as:684（[93]）
    var open_mask: int = 0               # CMap_Cell.as:389（[101]）

# 全局唯一（类静态）：CMap_Cell.as:553-556, 591-600
var nav_state := DONE
var nav_stamp := 0
var nav_ring := 0
var nav_prev: Array[Cell] = []
var nav_next: Array[Cell] = []
var nav_giveup := 0
const NAV_RINGS_PER_FRAME := 5          # CMap_Cell.as:1260  [157]=5
const NAV_MS_BUDGET := 3                # CMap_Cell.as:1273  [159]=3
const NAV_BLOCK_MASK := 131             # CMap_Cell.as:935   [161]=[65]|[169]=3|128
const NAV_FRESH_MS := 2000              # CMap_Cell.as:287
const NAV_GIVEUP_LIMIT := 5             # CMap_Cell.as:306
```

### 10.2 方向探测

```gdscript
func collide_flags_in_direction(c: Cell, d: int) -> int:      # CMap_Cell.as:115-119
    var f := c.adjacent[d].collide
    if d & 1:                                                  # 对角
        f |= c.adjacent[(d - 1) & 7].collide | c.adjacent[(d + 1) & 7].collide
    return f

func passable(c: Cell, d: int, mask: int) -> bool:
    return (collide_flags_in_direction(c, d) & mask) == 0
```

### 10.3 每帧铺场（严格按原版顺序，才能在行为上对齐）

```gdscript
func nav_advance(seeds: Array[Cell]) -> void:                  # CMap_Cell.as:589-678
    if nav_state == DONE or nav_state == null:                  # :596
        nav_next = []; nav_stamp = Time.get_ticks_msec()
        nav_ring = 0; nav_giveup = 0
        for c in seeds: c.visit()
    var rings := 0
    while rings < NAV_RINGS_PER_FRAME and nav_next.size() > 0:  # :606
        nav_prev = nav_next; nav_next = []
        for c in nav_prev:
            for d in [0, 2, 4, 6]:                              # :613-616  只扩四正向
                c.adjacent[d].visit()
        nav_ring += 1; rings += 1                               # :618
    nav_state = DONE if nav_next.size() == 0 else RUNNING       # :621

func visit(c: Cell) -> void:                                    # CMap_Cell.as:679-688
    if (c.collide & NAV_BLOCK_MASK) != 0 or c.nav_stamp == nav_stamp: return
    c.nav_stamp = nav_stamp
    c.nav_cost  = nav_ring
    nav_next.append(c)
```

### 10.4 方向决策（两级：流场梯度 → 局部绕行）

```gdscript
func nav_direction(c: Cell, cur_dir: int, want_dir: int, mask: int, force: bool) -> int:
    if nav_start_time - c.nav_stamp < NAV_FRESH_MS:              # :287  本格有新鲜流场值
        if passable(c, want_dir, mask) and cost_better(c, want_dir):  return want_dir
        if passable(c, cur_dir,  mask) and cost_better(c, cur_dir):   return cur_dir
        if not force and ++nav_giveup > NAV_GIVEUP_LIMIT: return -1   # :306
        c.open_mask = compute_open_mask(c, mask)                 # :387-442
        if c.open_mask == 0: return -1
        var order := sort_dirs_by_cost_desc(c)                   # :318-319 取末尾=最小
        for i in range(order.size() - 1, -1, -1):
            if c.open_mask & (1 << order[i]): return order[i]
        return -1
    return local_preference(want_dir, cur_dir, mask)             # :334 → :336-386

func local_preference(d2: int, d1: int, mask: int) -> int:       # :336-386
    if passable(c, d2, mask): return d2
    if d1 != d2 and passable(c, d1, mask): return d1
    var sgn := (abs(d2 - d1) <= 4) ? -1 : 1
    if d2 & 1:                        # 对角：步长 1，最多 ±3
        for n in [1, 3]:
            if passable(c, (d2 + n * sgn) & 7, mask): return (d2 + n * sgn) & 7
            if passable(c, (d2 - n * sgn) & 7, mask): return (d2 - n * sgn) & 7
    else:                             # 正向：步长 2（即只跳相邻正向）
        if passable(c, (d2 + 2 * sgn) & 7, mask): return (d2 + 2 * sgn) & 7
        if passable(c, (d2 - 2 * sgn) & 7, mask): return (d2 - 2 * sgn) & 7
    return -1
```

### 10.5 常量速查表

| 名称 | 值 | 出处 |
|---|---|---|
| 格子像素尺寸 | 32 | `__Packages/World/Map/CMap_Cell.as:703`、`:716` |
| 格中心偏移 | +0.5（格单位） | `__Packages/World/Map/CMap_Cell.as:18` |
| 高度换算 `mPFactor` | 1 | `__Packages/Thing/Math/CThing_Position.as:306` |
| 每帧铺场圈数上限 | 5 | `__Packages/World/Map/CMap_Cell.as:1260`（`[157]=5`） |
| 铺场时间预算 | 3 ms | `__Packages/World/Map/CMap_Cell.as:1273`（`[159]=3`） |
| BFS 阻挡掩码 | 131（=3\|128） | `__Packages/World/Map/CMap_Cell.as:935`（`[161]=[65]\|[169]`） |
| 流场“新鲜”阈值 | 2000 ms | `__Packages/World/Map/CMap_Cell.as:287` |
| 放弃计数上限 | 5 | `__Packages/World/Map/CMap_Cell.as:306` |
| 方向位掩码 | 1,2,4,8,16,32,64,128 | `__Packages/World/Map/CMap_Cell.as:976-1067` |
| 全方向掩码 | 255 | `__Packages/World/Map/CMap_Cell.as:1104` |
| 正向并 / 对角并 | 85 / 170 | `__Packages/World/Map/CMap_Cell.as:1091` / `:1078` |
| 格子碰撞位 | 1,2,4,8,16,32,64,128,256 | `__Packages/World/Map/CMap_Cell.as:742-846` |
| `CThing` 标志 | Collidable=1, WaitForMove=2, CellMoved=4, Drawn=8, SortFloor=16, DEAD=32 | `__Packages/Thing/CThing.as:139,149,159,169,179,189` |
| 线段碰撞步长 | 1 | `[MoreRooms] __Packages/World/Map/CMap_Collide.as:310` |
| 恶魔参数 | speed 0.04 / radius 0.42 / life 1000 / attackRange 5 / damage 50 / mass 5 / height 1.8 / fireRateCount 5 / score 1000 | `__Packages/Thing/Creature/CThing_Creature_Devil.as:63-72`、`:226` |
| 木桶参数 | life 1 / height 1 / radius 0.42 / damage 默认 100 | `__Packages/Thing/Object/CThing_Object_WallMovable.as:79,99,107,58` |
| 玩家参数（MoreRooms） | speed 0.16 / mass 2 / height 1.5 / life 200 | `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:557-560` |
| 世界尺寸 | 舞台 640×480；房间尺寸**未恢复**（库元件包围盒） | `[MoreRooms] __Packages/World/CWorld.as:49-50`；SWF 头 12800×9600 twips |

---

## 11. 未能恢复 / 存疑清单（明确记账）

> 说明：第 11.1 节给出**常量池恢复后已解决**的项；下面只列**仍然未解决**的。

1. **房间格数（地图边界尺寸）** — ❌ 仍未恢复（常量池也救不了：它本来就不是脚本常量）。
   尺寸来自 `mWorldSize` 库元件包围盒（`__Packages/World/Map/CMap.as:265`）与
   `mcRoomData._Size`（`[MoreRooms] __Packages/World/CWorld.as:50`）。
   尝试过：grep 两棵树的 `mWorldSize|_Size|mcRoomData|mMapSize|InitCells`；
   通读 `__Packages/World/Init/*.as`、`Piece/*.as`（只有 `Object.registerClass`）。
   ⇒ 只能从 SWF 美术量（或按 640×480 视口与房间底图推算）。
2. **`CThing_Object_WallMovable`（移动墙）类体** — ❌ 仍未找到；同名文件里装的是 `CThing_Object_Barrel`
   （`__Packages/Thing/Object/CThing_Object_WallMovable.as:51-54`）。
   其 `mCollide` 行为是**推断**（与木桶同）。
3. **`CMap_Navigation.as` 的按块切分** — ⚠️ 部分失败，原因已定位：
   该 `.as` 把**多个脚本块的输出合并**在一起（地图基类副本 + `CMap_Navigation` 空壳 + `CMath` + 音效类），
   所以用单一池（pool 30）替换会留下 20 个越界索引
   （`[12,13,14,15,16,20,23,25,28,30,31,33,35,39,41,44,45,46,48,49]`，属于另一个块的池）。
   **不影响本文结论**：导航真身在 `CMap_Cell.as`（pool 39 覆盖完整、零越界）。
4. **2Play 的双人输入 / 复活 / 结算差异** — ❌ 仍未恢复。
   `__Packages/Thing/Creature/CThing_Creature_Player.as` 对应 pool 318，**理论上可恢复**，
   但该文件是 495 行的合并块，按块映射需要额外的切分逻辑，本次未做。
   文档中双人结论只到“目标选择（§9.1）”与“出生点列表（§9.2）”。
5. **`CMap_Mapwho` / `CMap_Affect` / `CMap_Math` 的方法体** — ⚠️ 名字可恢复
   （pool 315 / 342 / 348），但本文只核实了下列内容；`CMap_Math.as` 只有 28 行（类体被 FFDec 吞掉），
   **即使恢复常量池也补不回被吞掉的语句**。
   - 【事实】`CMap_Mapwho.MoveThing(tThing)`：比较旧格与新格，从旧格 `mObjects` 删除、
     写入新格 `mObjects`，并把 `tThing` 的格子字段更新为新格集合的键
     （`__Packages/World/Map/CMap_Mapwho.as:25-42`；`[MoreRooms] __Packages/World/Map/CMap_Mapwho.as:51-66`）。
   - 【事实】调用点示例：`__Packages/Thing/CThing.as:42`（DeleteThing）、`:75`（MoveThing）、
     `__Packages/Thing/Object/CThing_Object_Pickup.as:36,57,94`。
   - 【事实】`CMap_Affect` 的“矩形取格 → 逐个 cell 里 `mObjects` → 按 affect 掩码派发”
     可在 `[MoreRooms] __Packages/World/Map/CMap_Affect.as:43-60`（明文）读到；
     2Play 同构于 `__Packages/World/Map/CMap.as:98-156`。

### 11.1 常量池恢复后**已解决**的项（附类 ↔ 池索引，便于复现）

| 原“未恢复”项 | 现状 |
|---|---|
| 9 个 `mCollide` 位与名字的对齐 | ✅ 全部对齐，含 7 个复合掩码 → §3.1 |
| 16 个方向解析方法的真名 | ✅ `NavDir_CW_0..7` / `NavDir_CCW_0..7` → §5.2 |
| `Array.sortOn` 的选项常量 | ✅ `RETURNINDEXEDARRAY \| NUMERIC \| DESCENDING`（`CMap_Cell.as:318`） |
| `CMap_Navigation` 是否空壳 | ✅ 是：pool 30 只有 12 项（`_global World Object Map CMap_Navigation mMap prototype toString _CLASSID_ Dispose _BASECLASSID_ ASSetPropFlags`），没有任何算法方法 |
| 方向编号与方位的对应 | ✅ 0..7 = E, SE, S, SW, W, NW, N, NE（`CMap_Cell.as:976-1067`） |
| `Nav_*` 一族方法名 | ✅ `Nav_Reset` / `Nav_Restart` / `Nav_Update` / `Nav_Direction` / `Nav_VD` / `NavReal_Dir` / `NF_4` / `NavReal_0..7` |
| 每格字段名 | ✅ `mPosition/mP1/mP2/mCentre/mArea/mID/mChildCount/mCollide/mObjects/mAdjacentCells(ac)/mEast/mSouth/mWest/mNorth/nID/nDist/nVD` |

**2Play 类 ↔ ActionConstantPool 索引**（`sprite` = 该池所在的 `DoInitAction` 精灵 ID）：

| 类 | pool # | sprite | 类 | pool # | sprite |
|---|---|---|---|---|---|
| `CMath` | 17 | 760 | `CThing_Navigation` | 261 | 828 |
| `CMap` | 27 | 763 | `CThing_Creature` | 310 | 840 |
| `CMap_Navigation` | 30 | 764 | `CMap_Mapwho` | 315 | 841 |
| `CMap_Collide` | 35 | 765 | `CThing_Creature_Player` | 318 | 842 |
| `CThing_Position` | 38 | 766 | `CThing_Creature_Devil` | 322 | 843 |
| `CMap_Cell` | 39 | 767 | `CThing_Creature_Zombie` | 324 | 844 |
| `CMap_Affect` | 342 | 850 | `CMap_Decal` | 346 | 851 |
| `CMap_Math` | 348 | 852 | | | |


---

## 12. 与 MoreRooms 对照的差异提示

| 项 | 2Play | MoreRooms | 说明 |
|---|---|---|---|
| 玩家数 | 2（`CWorld_Init_Player1` + `Player2` 两类，`[MoreRooms] __Packages/World/CWorld.as:109-114` 显示两者共用同一出生点列表） | 1（`[MoreRooms] __Packages/World/CWorld.as:361` 只取 `[0]`） | **双人相关结论仅对 2Play 有效** |
| 流场机制 | 同 | 同 | 两版的 `Nav_Direction` / `Nav_Reset` / BFS 结构一致（`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:563,606`） |
| 成员名可读性 | 差 | 好（`CMap_Collide` / `CWorld` 完全明文） | 命名类结论优先引 MoreRooms，并已在每处标注 |
| 移动墙 | 存在类名，类体未找到 | 未见 | — |
| `_StepSize` | 未读到（同名文件加密） | `1` | `[MoreRooms] __Packages/World/Map/CMap_Collide.as:310` |

**通用告警**：两个 build 都出自同一套 scidd 引擎，但**版本号/编译日期不同**
（2Play 为 `Final.1.00110 (16/05/2007 22:37)`，见 `frame_1/DoAction.as:1-7`），
凡是用 MoreRooms 补齐的结论，请在移植时以 2Play 的实际手感为准。
