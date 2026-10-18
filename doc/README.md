# Boxhead 原版逆向文档索引

本目录记录原版 Flash 游戏 **Boxhead: 2Play Rooms**（`oldGame/Boxhead_2Play.swf`）的设计，
用途是给 `box-head-remake`（Godot 4 重制）提供可照抄的数值与规则。

## 文档

| 文件 | 内容 |
|---|---|
| [00-overview.md](00-overview.md) | 总览：SWF 元信息、引擎架构、类清单、主循环与计时、全局开关、混淆情况与可读性矩阵 |
| [01-enemy-ai.md](01-enemy-ai.md) | 敌人 AI 与刷怪机制 |
| [02-pathfinding.md](02-pathfinding.md) | 地图表示与寻路/导航方式 |
| [03-weapons.md](03-weapons.md) | 武器系统与全部武器数值 |
| [04-enemy-stats.md](04-enemy-stats.md) | 敌人数值、玩家数值、关卡与难度曲线 |

## 如何验证

结论不是"看着像"，三条检查都能自己跑：

```powershell
# 1) 常量池还原自检：29 项断言，含端到端还原僵尸类并核对数值
python doc\tools\as2_constpool.py oldGame\Boxhead_2Play.swf --selftest

# 2) 文档引用自检：每条 路径:行号 是否真指向代码行
#    （能识别"指向混淆噪声行/越界/文件不存在/漏 [MoreRooms] 前缀"）
python doc\tools\check_citations.py doc\00-overview.md doc\01-enemy-ai.md `
       doc\02-pathfinding.md doc\03-weapons.md doc\04-enemy-stats.md doc\README.md

# 3) 行号对齐自检：resolved/ 与 linearized/ 是否逐行一致（见下方"逆向流程"）
```

当前实测：

| 检查 | 结果 |
|---|---|
| `as2_constpool.py --selftest` | **29/29 passed** |
| `check_citations.py`（6 个文档） | **全部引用可信，0 处可疑** |
| `resolved/` 与 `linearized/` 行号对齐 | 2Play **0** 处错位，MoreRooms **0** 处错位 |
| `as2_delinearize.py` 重跑 | 与 `linearized/` **逐字节一致** |

## 逆向流程

```
oldGame/Boxhead_2Play.swf
        │  ffdec 26.3.0（经 ffdecmcp MCP 调用）
        ▼
oldGame/_decompiled/Boxhead_2Play/scripts/scripts/     ← FFDec 原始输出（含混淆外壳，185 个 .as）
        │  doc/tools/as2_delinearize.py                （剥状态机外壳 + 重新缩进）
        ▼
oldGame/_decompiled/Boxhead_2Play/linearized/          ← 可读的 ActionScript【文档的行号引用基准】
        │  doc/tools/as2_constpool.py  → docs/tools/pools/2Play.json
        │  doc/tools/as2_resolve.py                    （把 §§constant(N) 就地换成成员名）
        ▼
oldGame/_decompiled/Boxhead_2Play/resolved/            ← 成员名也还原了【读数值看这里】
```

**关键性质：`resolved/` 与 `linearized/` 逐行对齐**（全 185 个文件都已机器校验，0 处不一致）。
还原是"就地替换"，一行进一行出，所以针对 `linearized/` 写的 `路径:行号` 在 `resolved/` 里指向同一行 ——
两个目录可以直接对照阅读，文档里的引用不需要改写。

`as2_resolve.py` 有两条保守规则，宁可少还原也不出错：

1. **只认"定义"该类的池** —— 池头必须是 `_global, <包路径…>, Object, <包路径…>, <类名>, …` 且类名出现在头部。
   仅仅"提到"某个类的池不会被采用（否则会挑到无关类的池，产出看似合理实则错误的名字）。
2. **找不到所属池就不替换** —— 该文件原样拷过去，`§§constant(N)` 保持可见。
   目前 90 个文件成功还原，其余保持原样。
3. 池条目里若含换行（解密出来的字符串字节），替换时压成空格，以免破坏行对齐。

工具分工：

| 工具 | 作用 |
|---|---|
| [`tools/as2_delinearize.py`](tools/as2_delinearize.py) | 剥掉控制流扁平化外壳，保留真实语句并重新缩进 → `linearized/` |
| [`tools/as2_constpool.py`](tools/as2_constpool.py) | 从 SWF 字节码解析 `ActionConstantPool`，导出索引→成员名映射（含 `--selftest`） |
| [`tools/as2_resolve.py`](tools/as2_resolve.py) | 把映射就地应用到整棵树 → `resolved/`（同名类不匹配时**拒绝替换**，宁缺毋滥） |
| [`tools/check_citations.py`](tools/check_citations.py) | 校验文档里每条 `路径:行号` 引用确实指向真实代码行 |

复现命令：

```powershell
python doc\tools\as2_delinearize.py oldGame\_decompiled\Boxhead_2Play\scripts\scripts `
                                    oldGame\_decompiled\Boxhead_2Play\linearized
python doc\tools\as2_constpool.py  oldGame\Boxhead_2Play.swf --json doc\tools\pools\2Play.json
python doc\tools\as2_resolve.py    doc\tools\pools\2Play.json `
       oldGame\_decompiled\Boxhead_2Play\linearized oldGame\_decompiled\Boxhead_2Play\resolved
```

`as2_delinearize.py` 是确定性的：用默认参数重跑会与 `linearized/` **逐字节一致**（已验证）。

旁证来源（同作者、同引擎的另一版 build）：

```
oldGame/boxheadmorerooms.swf
        │  ffdec
        ▼
oldGame/_decompiled/MoreRooms/scripts/scripts/         ← 198 个 .as
        │  doc/tools/as2_delinearize.py
        ▼
oldGame/_decompiled/MoreRooms/linearized/              ← 补齐 2Play 缺失内容时看这里
        │  doc/tools/as2_resolve.py  +  tools/pools/MoreRooms.json
        ▼
oldGame/_decompiled/MoreRooms/resolved/                ← 同样与 linearized/ 逐行对齐
```

两个 build 的 `resolved/` 都做到了**零行号错位**（2Play 91 个文件被替换、MoreRooms 101 个）。
所以文档里 `[MoreRooms] 路径:行号` 的引用也可以直接换根目录读，不必改写行号。

`_decompiled/` 已加入 `.gitignore`；`doc/tools/` 下的工具与 `pools/*.json` 是可复现产物，保留在版本库里。

## 混淆说明（读文档前必读）

原版 SWF 经过 SWF 混淆器处理，有两层：

1. **控制流扁平化**。每个脚本和每个类体都被包进一个常量状态机：

   ```actionscript
   function §\x01\x02§() { return 418; }
   var §\x01§ = 362 + "\x01\x02"();
   while(true) {
      if(eval("\x01") == 780) { set("\x01", eval("\x01") - 3); §§push(true); }
      else if(eval("\x01") == 925) { /* 真正的代码在这里 */ }
      ...
   }
   ```

   每个转移都是常量加减，所以整条链是一条直线。**真实语句本身在 case 体里被完整保留**，
   只是外面套了外壳。`doc/tools/as2_delinearize.py` 剥掉外壳、保留语句、重新缩进，行数减少约 40%，
   并做 token 校验（`function(` / `this.` / `super(` / `return ` 的计数必须与原文一致，不一致就报错）。

   **残留**：混淆器还会把状态机*嵌套*在 case 体里（`loop1: while(true) { ... }`）。
   默认参数**不拆嵌套**，因为实测在约 19 个文件里 FFDec 对嵌套机器的输出本身是乱的，
   拆开会把碎片散落到语句列表里，反而更难读。默认保留嵌套机器的完整外形，
   读者能一眼看出"这里是个状态机，跳过"。
   当前 184 个文件里有 33 个含残留（合计约 1047 行）。
   工具另有实验性的 `--aggressive` 开关会尝试拆嵌套，**输出更短但在上述文件里会误导，谨慎使用**。

2. **成员名与字符串加密** —— 两种记号的**可恢复性完全不同**，务必分清：

   | 记号 | 含义 | 例 | 可恢复性 |
   |---|---|---|---|
   | `§§constant(N)` | 加密的**成员名/函数名/属性名** | `this[§§constant(5)] = 16711680;` | ✅ **可以还原**，见下 |
   | `{invalid_utf8=NN}` | 加密的**字符串字面量**，一个记号是一个字节 | `eval("{invalid_utf8=175}{invalid_utf8=244}J\x0e{invalid_utf8=148}")` | ❌ 未还原 |

   ### `§§constant(N)` 的还原方法（已实现并验证）

   `N` 不是全局编号，而是**该脚本块自己的 `ActionConstantPool`（AS2 操作码 `0x88`）数组下标**。
   这个常量池**以明文存在 SWF 字节码里**，位于 `DoAction(12)` / `DoInitAction(59)` 标签的载荷中，
   所以可以直接解析出来：

   1. 扫描 SWF 里所有 `DoAction` / `DoInitAction` 标签，取其中的 `0x88` 常量池；
   2. 用池头结构把池与脚本文件配对：池的前几项固定是
      `_global, <包路径第1段>, Object, <包路径其余段>, <类名>`；
   3. 于是 `this[§§constant(5)]` 可以直接换成 `this.<pool[5]>`。

   自校验（方法正确性的直接证据）：`CThing_Creature` 的池还原后
   下标 5 = `mFlags`、6 = `CThing`、7 = `mFlag_Collidable`，
   而代码是 `this[§5] = ...[§6][§7]` → 还原为 `this.mFlags = CThing.mFlag_Collidable`，
   与已知基类事实（`__Packages/Thing/CThing.as:139` 的 `mFlag_Collidable = 1`）完全吻合。

   工具：[`tools/as2_constpool.py`](tools/as2_constpool.py)。
   **注意：该工具仍在收尾中，尚未端到端验证通过**（实测在 2Play SWF 上暂时返回 0 个池）。
   凡是标了【常量池恢复】的结论，请以"能否用该工具复现"为准绳；
   在工具跑通之前，这些结论应当视为**待复核**。
   要判断一个文件"能不能读"，看的是**它的常量池能否与文件配对**，而不是记号数量。

   ### `{invalid_utf8=..}` 的还原

   FFDec 只对 AS3 提供命令行去混淆。实测 `ffdec-cli -deobfuscate max` 对 AS2 直接报
   `Warning: The file is not AS3. Only AS3 deobfuscation from commandline is available.`，
   产出 0 字节文件（已复现两次，一次经 ffdecmcp 的 `deobfuscate` 工具、一次手工调 CLI）。
   **这一层仍未还原。**

   一条线索：`__Packages/CMain.as:359,370` 漏出了明文
   `morerooms_default.Point` / `morerooms_default.geom`，
   说明字符串表并非全部不可逆，若后续要攻这一层可以从这里入手。

   > 即便不还原字符串，被加密文件里的**控制流结构、循环形状、数值字面量仍然可读**，
   > 加上常量池还原后连成员名也能读——所以「有加密记号」≠「不可读」。

### 仍然没有恢复的

| 内容 | 原因 |
|---|---|
| `World/Map/CMap_Math.as` | 类体被 FFDec 吞掉（文件只剩 28 行），还原常量池也补不回被吞掉的语句 |
| `Thing/Object/CThing_Object_WallMovable.as` | 同名文件里装的其实是 **Barrel** 的类体，真正的可移动墙代码不在里面 |
| 房间格数 / 房间尺寸 | 来自库元件的包围盒（`mWorldSize` / `mcRoomData._Size`），常量池救不了，只能量美术资源 |
| 2Play 双人输入差异 | pool 318 可还原，但需要额外的按块切分逻辑 |
| 字符串字面量 `{invalid_utf8=..}` | 见上，未还原 |

> **一条已撤销的结论**：早期版本的本节把 `CMap_Navigation.as` 列为"唯一硬缺口"（常量池解析率 0.069）。
> 那是误判——该文件只是把多个脚本块的输出**合并**在一起的容器，
> 其中的 `CMap_Navigation` 是个**只有 12 个条目的空壳类**，根本不含算法。
> 真正的寻路实现在 `CMap_Cell.as`（pool 39，**零越界**），已完整恢复。

## 可信度约定

每份文档统一使用以下标注：

- `相对路径:行号` —— 事实出处，例如 `__Packages/Thing/Creature/CThing_Creature_Devil.as:142`
- `[MoreRooms] 相对路径:行号` —— 结论来自**另一版 build**，不是 2Play 本体，数值可能有差异
- **【直读】** —— 该文件没有加密记号，成员名与数值都能直接读到
- **【常量池恢复】** —— 成员名是 `§§constant(N)`，已用上述方法还原
- **【推断】** —— 代码里没有直接写明的结论
- **【未恢复】** —— 试过但读不到，不会用猜测填充（并说明尝试过什么）

## 可读性矩阵

统计口径：文件里 `§§constant(N)` 与 `invalid_utf8=` 的出现次数，**两个都为 0 才算完整可读**。
（早期版本的本表只数了 `invalid_utf8=`，把 `CMap_Navigation.as` 这类成员名全被加密的文件
误判成"基本可读"，已更正。）

### 完整可读（0 处加密记号）—— 可以放心引用

**Boxhead_2Play**（82 / 184 个文件干净，其中 57 个是 ≤30 行的按钮与存根脚本；主要的有）：

| 文件 | 行数 |
|---|---:|
| `Screen_LoadingWorld.as` | 708 |
| `__Packages/World/CUpgrades.as` | 669 |
| `__Packages/scidd/Math/CLine.as` | 492 |
| `__Packages/scidd/Math/CMath.as` | 363 |
| `__Packages/World/Map/CMap_Decal.as` | 287 |
| **`__Packages/Thing/Creature/CThing_Creature_Devil.as`** | 228 |
| `__Packages/Thing/CThing.as` | 201 |
| `__Packages/DrawPrimitive/MovieClip/CDrawPrimitive_MovieClip_Animation.as` | 126 |
| **`__Packages/Thing/Object/CThing_Object_Pickup.as`** | 111 |
| **`__Packages/Thing/Effect/CThing_Effect_Explosion.as`** | 101 |
| `__Packages/Screen/CScreen_Debrief_Winner.as` | 88 |
| `__Packages/Thing/Shot/CThing_Shot_FireBall.as` | 76 |
| `__Packages/Screen/CScreen.as` | 68 |
| `frame_1/DoAction.as`（全局开关） | 53 |
| `__Packages/Thing/Weapon/CThing_Weapon_Devastator.as` | 46 |
| `__Packages/Thing/Effect/CThing_Effect_SmartBomb.as` | 43 |
| `__Packages/Thing/Effect/CThing_Effect_BloodPool.as` | 34 |
| `__Packages/scidd/Math/CRandom.as` | 24 |

**boxheadmorerooms**（49 / 198 个文件干净）：

| 文件 | 行数 |
|---|---:|
| **`__Packages/World/CWorld.as`**（主循环 + 刷怪入口） | 505 |
| `__Packages/scidd/Draw/CColor.as` | 462 |
| `__Packages/scidd/Math/CMath.as` | 374 |
| `Piece/Slab.as` | 356 |
| **`__Packages/World/Map/CMap_Collide.as`** | 312 |
| `frame_10/DoAction.as` | 196 |
| **`__Packages/CSaveData.as`** | 134 |
| **`__Packages/World/Map/CMap_Affect.as`** | 129 |
| `__Packages/World/Init/CWorld_Init.as` | 74 |
| `World_Init_Player1.as` | 66 |
| **`__Packages/Thing/Weapon/CThing_Weapon_Grenade.as`** | 60 |

### 含加密记号（`§§constant` 数 / `invalid_utf8=` 数）

格式：「2Play 行数 · 记号数 ｜ MoreRooms 行数 · 记号数」。
**注意：`§§constant` 多 ≠ 不可读** —— 它只说明该文件的成员名需要走 `as2_constpool.py` 还原。
只有**常量池无法与文件配对**时才真的读不到（目前属于这种情况的是把多个脚本块合并在一起的
`CMap_Navigation.as`）。`invalid_utf8=` 才是目前真正未还原的那一层（字符串字面量）。

| 文件 | 2Play | MoreRooms |
|---|---|---|
| `World/Map/CMap_Cell.as` | 1277 · 2740 → **pool 39 零越界** | 1275 · 3051 |
| `Thing/Affect/CThing_Affect.as` | 1575 · 2741 | 1521 · 1550 |
| `Screen/CScreen_Intro.as` | 8513 · 5459 | — |
| `CSound.as` | 949 · 4328 | — |
| `Thing/Creature/CThing_Creature_Player.as` | 495 · 899 | 625 · 335 |
| `World/CWorld.as` | 724 · 986 | 505 · **0** |
| `CSaveData.as` | 481 · 808 | 134 · **0** |
| `World/CHud.as` | 505 · 953 | 954 · 810 |
| `Thing/Creature/CThing_Creature.as` | 488 · 709 → pool 310 | 793 · 990 |
| `Thing/Shot/CThing_Shot_DLaser.as` | 854 · 704 | — |
| `Thing/Weapon/CThing_Weapon_Railgun.as` | 826 · 591 | 55 · 59 |
| `World/Map/CMap_Navigation.as` | 970 · 522 → **空壳类，无算法** | 370 · 486 |
| `CMain.as` | 370 · 460 | 264 · 13 |
| `Thing/Weapon/CThing_Weapon_UZI.as` | 675 · 401 | 2395 · 979 |
| `Thing/Weapon/CThing_Weapon_Mine.as` | 517 · 363 | 53 · 48 |
| `World/Map/CMap_Collide.as` | 310 · 337 → pool 35 | 312 · **0** |
| `Thing/Math/CThing_Angle.as` | 285 · 336 | — |
| `Thing/Creature/CThing_Creature_Zombie.as` | 134 · 286 → pool 324 | 1315 · 535 |
| `Thing/Weapon/CThing_Weapon.as` | 216 · 290 → pool 内 | 132 · 112 |
| `World/Map/CMap.as` | 327 · 280 | 704 · 817 |
| `Thing/Weapon/CThing_Weapon_Shotgun.as` | 220 · 256 | 2694 · 1232 |
| `Thing/Weapon/CThing_Weapon_Rocket.as` | 118 · 168 | 2969 · 1432 |
| `Thing/Effect/CThing_Effect.as` | 271 · 420 | — |
| `scidd/Draw/CColor.as` | 465 · 799 | 462 · **0** |
| `Screen/CScreen_SelectWorld.as` | 520 · 885 | — |
| `Screen/CScreen_Debrief.as` | 1086 · 801 | — |
| `Thing/Math/CThing_Position.as` | 360 · 546 | — |
| `Thing/Weapon/CThing_Weapon_Pistol.as` | 54 · 54 | 238 · 87 |
| `Thing/Weapon/CThing_Weapon_SmartBomb.as` | 63 · 9 | 2132 · 693 |
| `Thing/Weapon/CThing_Weapon_Devastator.as` | 46 · **0** | 192 · 30 |
| `World/Init/CWorld_Init_Zombie.as` | 23 · 13 | 1872 · 2122 |
| `World/Init/CWorld_Init_Devil.as` | 235 · 48 | 2168 · 2112 |
| `Thing/Math/CThing_Navigation.as` | 65 · 44 | 782 · 646 |
| `Screen_Debrief_Winner.as` | 16 · 121442 | — |

### 对本次四个专题的直接影响

以「敌人 AI」那份文档实测的常量池还原率为准（clean = 占用下标能还原成合法标识符的比例）：

| 文件 | clean | 还原结论 |
|---|---:|---|
| `Thing/Creature/CThing_Creature.as` | 0.995 | 【常量池恢复】完整 |
| `Thing/Creature/CThing_Creature_Zombie.as` | 1.000 | 【常量池恢复】完整 |
| `Thing/Creature/CThing_Creature_Player.as` | 0.978 | 【常量池恢复】完整 |
| `World/CWorld.as` | 0.986 | 【常量池恢复】完整 |
| `World/Map/CMap_Cell.as` | 1.000 | 【常量池恢复】完整 —— **寻路在这里** |
| `Thing/CThing_Collection.as` | 1.000 | 【常量池恢复】完整 |
| `World/Init/CWorld_Init_Zombie.as` | 0.857 | 【常量池恢复】正文完整 |
| `World/Init/CWorld_Init_Devil.as` | 1.000 | 【常量池恢复】完整 |
| `Thing/Math/CThing_Navigation.as` | 0.792 | 文件头有别的脚本残片，正文已还原 |
| `World/Map/CMap_Navigation.as` | 0.069 | **空壳类**（池仅 12 项），文件混了多个脚本块；**不含算法，不影响结论** |
| `Thing/Affect/CThing_Affect.as` | 0.489 | 部分未恢复，但 `mAffect_*` 常量值已取到 |

| 专题 | 状态 |
|---|---|
| 敌人 AI | 恶魔 AI【直读】；僵尸/生物基类【常量池恢复】完整；刷怪节奏【直读】`CUpgrades.as`；刷怪入口【直读】`[MoreRooms] CWorld.as` |
| 寻路/导航 | **已确证**：`CMap_Cell.as`【常量池恢复】完整，算法 = 全局 BFS 距离场 + 每格梯度下降 |
| 武器数值 | 字段名与数值均已由常量池还原；`Devastator`(2P)/`Grenade`(MR) 本身【直读】 |
| 敌人数值 | 恶魔/等级曲线/难度/拾取/存档均【直读】；僵尸与玩家【常量池恢复】 |

> 两个 build 规模差异很大（`CWorld_Init_Zombie.as` 2Play 23 行 / MoreRooms 1872 行，
> `CThing_Weapon_Rocket.as` 118 行 / 2969 行），不是同一次构建，
> **引用 MoreRooms 的数值时必须标注 `[MoreRooms]` 并视为待验证**。
