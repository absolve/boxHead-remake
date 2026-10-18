# 03 — 武器系统与全部武器数值（Boxhead: 2Play Rooms 逆向设计文档）

> **目标 build**：`oldGame\Boxhead_2Play.swf`
> 产品串 `Boxhead: 2Play Rooms: Final.1.00110 (16/05/2007 22:37)`，Flash 8 / AS2，
> 舞台 640×480，63 帧，**frameRate = 50**（`mcp__ffdec__get_swf_metadata` 读 SWF 头）。
>
> **引用根目录**（下文中不带前缀的路径都相对于它）：
> `E:\boxHead-remake\oldGame\_decompiled\Boxhead_2Play\linearized\`
> 带 `[MoreRooms] ` 前缀的引用相对于：
> `E:\boxHead-remake\oldGame\_decompiled\MoreRooms\linearized\`
>
> **行号约定**：`__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:38` 表示上表根目录下该文件的第 38 行。
> **同一行号在 `resolved/` 树里也成立**（见 §0.2）。

---

## 0. 前提：常量池已解出，本文档的武器字段名是**直读**

### 0.1 结论

**§2 的武器数值表里，每一个字段名与每一个数值都是从代码里直接读到的，不含任何猜测。**

混淆器把成员名换成了 `§§constant(N)`，`N` 就是**该脚本块自己的 AS2 `ActionConstantPool`
（操作码 `0x88`）数组下标**；这个常量池**以明文存在 SWF 字节码里**。把它读出来，
`§§constant(N)` 就能直接替换成真实成员名。

### 0.2 工具链（`doc/tools/`）

| 工具 | 作用 |
|---|---|
| `doc/tools/as2_constpool.py` | 从 SWF 恢复全部 `ActionConstantPool`（本 build 共 **108 个**，`--selftest` 机器自检全过），并把 `§§constant(N)` 映射回真实名字。`--map <文件>` 打印单个文件的索引映射表。 |
| `doc/tools/as2_resolve.py` | 把整个 `linearized/` 重写成 `resolved/`，**逐行一一对应**（一行进一行出），所以 `linearized/` 上的行号在 `resolved/` 上依然有效。 |
| `doc/tools/check_citations.py` | 校验文档里每个 `路径:行号`：文件是否存在、该行是否混淆噪声、是否漏 `[MoreRooms]` 前缀。 |

生成命令：

```
python doc\tools\as2_constpool.py oldGame\Boxhead_2Play.swf --json %TEMP%\pools.json
python doc\tools\as2_resolve.py   %TEMP%\pools.json ^
      oldGame\_decompiled\Boxhead_2Play\linearized ^
      oldGame\_decompiled\Boxhead_2Play\resolved
```

### 0.3 索引约定（重要）

池数组有一个**前导空串**，所以 **`§N` → `entries[N+1]`**。
已用 `CThing_Creature` 独立复核：`§5`→`mFlags`、`§6`→`CThing`、`§7`→`mFlag_Collidable`。

### 0.4 常量池是**按脚本块独立**的（易错）

`§N` 只在**产生它的那个脚本块内**有意义。同一个 `N` 在不同文件里含义可能不同：

| 证据 | 说明 |
|---|---|
| `__Packages/Thing/Weapon/CThing_Weapon.as:18` 的 `§5` → **`mFireRateCount`** | 基类池头：`… Weapon, CThing_Weapon, mFireRateCount, mFireRate, mTotalAmmo, mAmmo, mInfinateAmmo, …` |
| `__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:17` 的 `§5` → **`mFireRate`** | Pistol 池头：`… Weapon, CThing_Weapon_Pistol, mFireRate, mTotalAmmo, mAmmo, …` |
| `__Packages/Thing/Weapon/CThing_Weapon_Grenade.as:23` 的 `§12` → **`mRange`**（值 6）<br>`__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:44` 的 `§12` → **`mWideShot`**（值 0） | 两文件池不同 |

> **因此**：任何"跨文件复用常量编号"的说法都是错的。`resolved/` 树已为每个文件用**它自己的池**解开。
> 若 `resolved/` 中某行解出的名字明显不合理（例如 `CThing_Weapon_Mine.as:17` 解出 `this[mPosition] = 1`），
> 说明那个文件的池是**低置信度匹配**（`--map` 会显示 `matched_by=header-overflow` 与 `clean=` 分数）——
> 这类行本文档一律不引用，改用**逐行对齐的 `linearized/` 原文 + 池的索引映射表**（见 §2.1）。

### 0.5 两个 build 的常量池互不相同

MoreRooms 与 2Play 是独立构建，池不同（这也是 §0.4 的自然推论）。
本文档**不用** MoreRooms 的池去解 2Play；MoreRooms 只用于**数值对照**与**2Play 确实读不到的行为**。

---

## 1. 武器系统的类结构

### 1.1 类层次

```
CThing
└── CThing_Weapon
    ├── CThing_Weapon_Pistol
    ├── CThing_Weapon_UZI
    ├── CThing_Weapon_Shotgun
    ├── CThing_Weapon_Barrel
    ├── CThing_Weapon_Grenade
    ├── CThing_Weapon_FakeWall
    ├── CThing_Weapon_Mine
    ├── CThing_Weapon_Rocket
    ├── CThing_Weapon_Railgun
    ├── CThing_Weapon_ChargePack
    ├── CThing_Weapon_SmartBomb          （不在玩家武器表内，见 §8.3）
    └── CThing_Weapon_Devastator         （不在玩家武器表内，见 §8.3）
```

各子类的 `extends` 与构造首行 `super(...)`：
`__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:34`（extends）、`:37`（super）；
`__Packages/Thing/Weapon/CThing_Weapon_Railgun.as:782`（extends）、`:785`（super）。

### 1.2 基类 `CThing_Weapon`

`__Packages/Thing/Weapon/CThing_Weapon.as:15-21`（原文），其**池映射**（`--map` 输出）为：

| 常量 | 真实字段名 |
|---|---|
| `§5` | **`mFireRateCount`** |
| `§6` | **`mFireRate`** |
| `§7` | `mTotalAmmo` |
| `§8` | `mAmmo` |
| `§9` | `mInfinateAmmo` |

于是这三行的真实含义是：

```as2
17:  super(tPosition,tAngle,tParent);
18:  this.mFireRateCount = 0;                                   // §5
19:  this.mFireRate = 10;                                      // §6
20:  this.mTotalAmmo = this.mAmmo = ...CThing_Weapon.mInfinateAmmo;  // §7 = §8 = §9
```

| 基类字段 | 初值 | 备注 |
|---|---|---|
| `mFireRateCount` | `0` | 剩余冷却帧数 |
| `mFireRate` | `10` | 开火间隔帧数（基类默认；每个子类都覆写） |
| `mTotalAmmo` = `mAmmo` | `mInfinateAmmo` | 备弹 = 当前弹匣 |
| `mInfinateAmmo` | **999999** | `__Packages/Thing/Weapon/CThing_Weapon.as:129`：`}[§§constant(9)] = 999999;` |

> ⚠ **基类的字段顺序与所有子类相反**：基类是 `mFireRateCount`(§5) 在前、`mFireRate`(§6) 在后；
> 而**所有子类**（Pistol / Shotgun / UZI / Grenade / Rocket / Railgun / Mine / Barrel / FakeWall）
> 都是 `mFireRate`(§5) 在前、`mFireRateCount`(§8) 在第三位。这是最容易看错的一处，
> 本文档早期版本就在这里搞反过（见附录 C）。

**基类方法**（`__Packages/Thing/Weapon/CThing_Weapon.as`）：

| 方法 | 行号 | 行为 |
|---|---|---|
| `Process(tKey)` | `:72-103` | 每帧：① 处理子物体；② `if (WeaponEmpty())` → 把武器名 + `" is out of ammo!"` 推给 HUD 并 `return`（**不再开火**）；③ `if (--mFireRateCount <= 0)` → `mFireRateCount = 0`，再按 `mOnRelease` / `mAuto` / 刚按下 三选一调用 `Fire()` |
| `WeaponEmpty()` | `:104-107` | `return this.mAmmo <= 0;`（ChargePack 覆写，见 §9.4） |
| `Fire(tPosition,tAngle)`（基类包装） | `:108-111` | 只调 `DecrementAmmo()`；子类覆写真正的发射 |
| `DecrementAmmo()` | `:112-116` | `mAmmo -= (mTotalAmmo != mInfinateAmmo ? 1 : 0);` 然后 `mFireRateCount = mFireRate;` ← **无限弹药时不减** |
| `Reset()` | `:117-120` | `mAmmo = (mTotalAmmo != mInfinateAmmo ? 0 : mTotalAmmo);` |

**开火调度**（`CThing_Weapon.as:81-102`，解混淆）：

```
if (--this.mFireRateCount <= 0) {          // :81
    this.mFireRateCount = 0;               // :83
    if (this.mOnRelease) {                 // :84  §41
        if (tKey.SomeKeyQuery())           // :86  §43
            Fire(mPosition.Clone(), mAngle.mAngle, tKey.SomeDuration());   // :88  §44
    } else if (this.mAuto) {               // :91  §49
        if (tKey.SomeKeyQuery())           // :93  §50
            Fire(mPosition.Clone(), mAngle.mAngle, tKey.SomeDuration());   // :95  §51
    } else if (tKey.SomeKeyQuery())        // :98  §52
        Fire(mPosition.Clone(), mAngle.mAngle);                            // :100
}
```

> `§41 = mOnRelease`、`§49 = mAuto`：由 `__Packages/Thing/Weapon/CThing_Weapon_Grenade.as:22`
> （值 `true`，池映射 `§11 = mOnRelease`）与 `__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:21` /
> `__Packages/Thing/Weapon/CThing_Weapon_Rocket.as:88`（值 `false`，池映射 `§12`/`§10 = mAuto`）交叉确认。
> `§43` / `§50` / `§52` 超出基类池范围，**具体方法名未恢复**（推断：松开 / 按住 / 刚按下 三种按键查询）。

---

## 2. 全部武器数值表（核心交付物，全部直读）

下表的**每一格都是明文读到的**。`—` 表示该武器的构造函数里**根本没有这一项赋值**
（不是"未恢复"，而是原版确实没写；后果见 §2.3）。

| 武器 | `mFireRate` | `mFireRateCount` | `mTotalAmmo` = `mAmmo` | `mDamage` | `mAuto` | `mOnRelease` | `mRange` | `mWideShot` | 数值来源 |
|---|---|---|---|---|---|---|---|---|---|
| **Pistol** | 8 | 0 | 999999（∞） | **26** | false | — | 8 | — | 直读 |
| **UZI** | 4 ※ | 0 | **100** | **35** | **true** | — | 8 | — | 直读 |
| **Shotgun** | **12** | 0 | **20** | **51** | false | — | 7 | **0** | 直读 |
| **Barrel** | 1 | 0 | 10 | **150** | false | — | — | — | 直读 |
| **Grenade** | **12** | 0 | **20** | **150** | false | **true** | **6** | — | 直读 |
| **Rocket** | **12** | 0 | **20** | **250** | false | — | — | — | 直读 |
| **Railgun** | **5** | 0 | **15** | **100** | false | — | **10** | — | 直读 |
| **FakeWall** | 1 | 0 | 5 | **100** | false | — | — | — | 直读 |
| **Mine** | 1 | **12** ※ | **10** | 100 | false | — | — | — | 直读 |
| **ChargePack** | 1 | 0 | 10 | **150** | false | — | — | — | 直读 |
| **SmartBomb** | 12 | 0 | 20 | 100 | false | — | — | — | 直读 |
| **Devastator** | 4 | 0 | 999999（∞） | **100** | **true** | — | 8 | — | 直读 |

※ 两处特例，见 §2.2。

> **本表的 `mTotalAmmo`/`mAmmo` 列已修正一处旧错误**：早期版本把 **Mine** 写成 `20`，
> 正确值是 **10**（`__Packages/Thing/Weapon/CThing_Weapon_Mine.as:18`：
> `this[§§constant(6)] = this[§§constant(7)] = 10;`，池映射 `§6 = mTotalAmmo`、`§7 = mAmmo`）。

### 2.1 逐把武器：原始构造函数 + 本文件的池映射表

`行号` 都是 `linearized/` 的行号（与 `resolved/` 一致）。池映射表来自
`python doc\tools\as2_constpool.py oldGame\Boxhead_2Play.swf --map __Packages/Thing/Weapon/<文件>.as`。

#### Pistol — `__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:14-29`

池映射（`matched_by=header, clean=0.977`）：

| § | 名字 | § | 名字 |
|---|---|---|---|
| 5 | `mFireRate` | 11 | `mDamage` |
| 6 | `mTotalAmmo` | 12 | `mAuto` |
| 7 | `mAmmo` | 13 | `mRange` |
| 8 | `CThing_Weapon` | 14 | `mcMuzzleFlash` |
| 9 | `mInfinateAmmo` | 19 | `mWorld` |
| 10 | `mFireRateCount` | 20 | `mUpgrades` |

```as2
16:  super(tPosition,tAngle,tParent);
17:  this[§5]  = 8;                                    // mFireRate
18:  this[§6]  = this[§7] = ...CThing_Weapon[§9];      // mTotalAmmo = mAmmo = mInfinateAmmo (999999)
19:  this[§10] = 0;                                    // mFireRateCount
20:  this[§11] = 26;                                   // mDamage
21:  this[§12] = false;                                // mAuto
22:  this[§13] = 8;                                    // mRange
```

交叉验证：`__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:45` 的 `Fire` 里
`new ...CThing_Shot_Bullet(tPosition, tAngle, this[§34], this[§11], 8)`
—— 第 4 实参 `this[§11]` = **`mDamage`(26)**，第 5 实参硬编码 `8`（与 `mRange` 同值）。

#### UZI — `__Packages/Thing/Weapon/CThing_Weapon_UZI.as:636-651`

池映射（`matched_by=header-overflow, clean=0.754`，但 §4–§11 与构造顺序完全自洽）：

| § | 名字 | § | 名字 |
|---|---|---|---|
| 4 | `CThing_Weapon_UZI` | 9 | `mDamage` |
| 5 | `mFireRate` | 10 | `mAuto` |
| 6 | `mTotalAmmo` | 11 | `mRange` |
| 7 | `mAmmo` | 14 | `Register_Weapon` |
| 8 | `mFireRateCount` | 19 | `mcMuzzleFlash` |

```as2
638:  super(tPosition,tAngle,tParent);
639:  this["{invalid_utf8=250}{invalid_utf8=179}{invalid_utf8=143}q"] = 4;
640:  this[§6]  = this[§7] = 100;                       // mTotalAmmo = mAmmo
641:  this[§8]  = 0;                                    // mFireRateCount
642:  this[§9]  = 35;                                   // mDamage
643:  this[§10] = true;                                 // mAuto
644:  this[§11] = 8;                                    // mRange
```

交叉验证：`__Packages/Thing/Weapon/CThing_Weapon_UZI.as:667` 的 `Fire` 里
`… (tPosition, tAngle, this[§33], this[§9], this[§11])` → `mDamage = 35`、`mRange = 8`。

> **※ UZI 的射速是乱码属性名（确凿）**：UZI 的池里**确实有 `mFireRate`**（在 `§5`），
> 但构造函数第 639 行把它写成了 `this["{invalid_utf8=250}{invalid_utf8=179}{invalid_utf8=143}q"] = 4;`
> —— 混淆器把**这一处成员名字符串本身**换成了乱码，而没有走常量池。
> 结果是 `mFireRate` 这个字段在 UZI 上**从未被赋值**。
> 这个乱码属性名全程只出现这一次（`CThing_Weapon_UZI.as:639`）。
>
> **（推断）运行时后果**：`DecrementAmmo()`（`__Packages/Thing/Weapon/CThing_Weapon.as:115`）执行
> `mFireRateCount = mFireRate`，而 UZI 的 `mFireRate` 是 `undefined` ⇒ `mFireRateCount = undefined`；
> 下一帧 `if (--mFireRateCount <= 0)` 变成 `NaN <= 0` = `false` ⇒ **"冷却"永不阻塞**，
> 表现为按住即无限倾泻。这与 UZI 的实际手感一致，但属于原版的**未定义行为**。
> **Godot 实现建议**：按 `mFireRate = 4` 处理（12.5 发/秒），并在注释里记录原版这一格是乱的。

#### Shotgun — `__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:35-51`

池映射（`matched_by=header-overflow, clean=0.800`，§4–§12 与构造顺序完全自洽）：

| § | 名字 | § | 名字 |
|---|---|---|---|
| 4 | `CThing_Weapon_Shotgun` | 9 | `mDamage` |
| 5 | `mFireRate` | 10 | `mAuto` |
| 6 | `mTotalAmmo` | 11 | `mRange` |
| 7 | `mAmmo` | 12 | `mWideShot` |
| 8 | `mFireRateCount` | 15 | `Register_Weapon` |

```as2
37:  super(tPosition,tAngle,tParent);
38:  this[§5]  = 12;                                   // mFireRate
39:  this[§6]  = this[§7] = 20;                        // mTotalAmmo = mAmmo
40:  this[§8]  = 0;                                    // mFireRateCount
41:  this[§9]  = 51;                                   // mDamage
42:  this[§10] = false;                                // mAuto
43:  this[§11] = 7;                                    // mRange
44:  this[§12] = 0;                                    // mWideShot
```

#### Barrel — `__Packages/Thing/Weapon/CThing_Weapon_Barrel.as:9-18`

池映射：`§5 = mFireRate, §6 = mTotalAmmo, §7 = mAmmo, §8 = mFireRateCount, §9 = mDamage`。

```as2
10:  super(tPosition,tAngle,tParent);
11:  this[§5]  = 1;                                    // mFireRate
12:  this[§6]  = this[§7] = 10;                        // mTotalAmmo = mAmmo
13:  this[§8]  = 0;                                    // mFireRateCount
14:  this[§9]  = 150;                                  // mDamage
15:  this[§10] = false;                                // mAuto
```

**构造函数到此为止**，没有第 6 项 ⇒ **没有 `mRange` 赋值**。

#### Grenade — `__Packages/Thing/Weapon/CThing_Weapon_Grenade.as:14-26`

池映射（`matched_by=header, clean=1.000`，**最可信的一份**）：

| § | 名字 | § | 名字 |
|---|---|---|---|
| 4 | `CThing_Weapon_Grenade` | 10 | `mAuto` |
| 5 | `mFireRate` | 11 | `mOnRelease` |
| 6 | `mTotalAmmo` | 12 | `mRange` |
| 7 | `mAmmo` | 15 | `Register_Weapon` |
| 8 | `mFireRateCount` | 16 | `Process` |
| 9 | `mDamage` | 17 | `Process_Normal` |

```as2
16:  super(tPosition,tAngle,tParent);
17:  this[§5]  = 12;                                   // mFireRate
18:  this[§6]  = this[§7] = 20;                        // mTotalAmmo = mAmmo
19:  this[§8]  = 0;                                    // mFireRateCount
20:  this[§9]  = 150;                                  // mDamage
21:  this[§10] = false;                                // mAuto
22:  this[§11] = true;                                 // mOnRelease
23:  this[§12] = 6;                                    // mRange
```

**独立旁证**：`[MoreRooms] __Packages/Thing/Weapon/CThing_Weapon_Grenade.as:19-25` 是**明文**
（该文件 60 行 / 0 加密记号），逐字段与上表完全一致：

```as2
19:  this.mFireRate = 12;
20:  this.mTotalAmmo = this.mAmmo = 20;
21:  this.mFireRateCount = 0;
22:  this.mDamage = 150;
23:  this.mAuto = false;
24:  this.mOnRelease = true;
25:  this.mRange = 6;
```

#### Rocket — `__Packages/Thing/Weapon/CThing_Weapon_Rocket.as:81-91`

池映射：`§5 = mFireRate, §6 = mTotalAmmo, §7 = mAmmo, §8 = mFireRateCount, §9 = mDamage, §10 = mAuto`。

```as2
83:  super(tPosition,tAngle,tParent);
84:  this[§5]  = 12;                                   // mFireRate
85:  this[§6]  = this[§7] = 20;                        // mTotalAmmo = mAmmo
86:  this[§8]  = 0;                                    // mFireRateCount
87:  this[§9]  = 250;                                  // mDamage
88:  this[§10] = false;                                // mAuto
```

**没有 `mRange` 赋值**（构造函数到此为止）。

#### Railgun — `__Packages/Thing/Weapon/CThing_Weapon_Railgun.as:783-798`

池映射：`§5 = mFireRate, §6 = mTotalAmmo, §7 = mAmmo, §8 = mFireRateCount,
§9 = mDamage, §10 = mAuto, §11 = mRange`。

```as2
785:  super(tPosition,tAngle,tParent);
786:  this[§5]  = 5;                                    // mFireRate
787:  this[§6]  = this[§7] = 15;                        // mTotalAmmo = mAmmo
788:  this[§8]  = 0;                                    // mFireRateCount
789:  this[§9]  = 100;                                  // mDamage
790:  this[§10] = false;                                // mAuto
791:  this[§11] = 10;                                   // mRange
```

> ⚠ `__Packages/Thing/Weapon/CThing_Weapon_Railgun.as` 里**还内嵌了一份 Rocket 的重复定义**
> （`:223-259`，值 `12 / 20 / 0 / 250 / false`），那是 FFDec 的反编译伪影。
> 引用该文件请认准 `:783-798`。

#### FakeWall — `__Packages/Thing/Weapon/CThing_Weapon_FakeWall.as:15-25`

池映射（`matched_by=header, clean=0.976`）：
`§5 = mFireRate, §6 = mTotalAmmo, §7 = mAmmo, §8 = mFireRateCount, §9 = mDamage, §10 = mAuto`。

```as2
17:  super(tPosition,tAngle,tParent);
18:  this[§5]  = 1;                                    // mFireRate
19:  this[§6]  = this[§7] = 5;                         // mTotalAmmo = mAmmo
20:  this[§8]  = 0;                                    // mFireRateCount
21:  this[§9]  = 100;                                  // mDamage
22:  this[§10] = false;                                // mAuto
```

**没有 `mRange` 赋值**。
> **对照 MoreRooms**：`[MoreRooms] __Packages/Thing/Weapon/CThing_Weapon_FakeWall.as:15` 的同位置值是 **150**，
> 而 2Play 是 **100**。这是**已确认的 build 数值差异**。

#### Mine — `__Packages/Thing/Weapon/CThing_Weapon_Mine.as:14-23`，另见 `:468`

池映射：`§5 = mFireRate, §6 = mTotalAmmo, §7 = mAmmo, §8 = mFireRateCount, §9 = mDamage, §10 = mAuto`。

```as2
16:  super(tPosition,tAngle,tParent);
17:  this[§5]  = 1;                                    // mFireRate
18:  this[§6]  = this[§7] = 10;                        // mTotalAmmo = mAmmo = 10
19:  this[§8]  = 0;                                    // mFireRateCount
20:  this[§9]  = 100;                                  // mDamage
21:  this[§10] = false;                                // mAuto
...
468: this.mFireRateCount = 12;                         // ← 明文直读
471: this.mInfinateAmmo = 51;                          // ← 明文直读
```

> `:468` / `:471` 位于**明文区**，属于 FFDec 并入同一文件的另一处类定义。
> 目标类身份不能 100% 确定，但字段名与值都是明文，故列为确凿。
> 它把 `mFireRateCount` 从构造函数里的 `0`（`:19`）改成了 **12**。
> （推断）最终值以 **12** 为准（`:468` 在 `:19` 之后执行）。

#### ChargePack — `__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:21-32`（构造部分本就明文）

```as2
23:  super(tPosition,tAngle,tParent);
24:  this.mFireRate = 1;
25:  this.mTotalAmmo = this.mAmmo = 10;
26:  this.mFireRateCount = 0;
27:  this.mDamage = 150;
28:  this.mAuto = false;
29:  tParent.mWorld.mUpgrades.Register_Weapon(this);
30:  this.Reset();
31:  this.Process = this.Process_Normal;
```

**没有 `mRange` 赋值**（`Reset()` 见 `:76-81`，也不设它）。

#### SmartBomb — `__Packages/Thing/Weapon/CThing_Weapon_SmartBomb.as:16-26`（构造部分本就明文）

```as2
18:  super(tPosition,tAngle,tParent);
19:  this.mFireRate = 12;
20:  this.mTotalAmmo = this.mAmmo = 20;
21:  this.mFireRateCount = 0;
22:  this.mDamage = 100;
23:  this.mAuto = false;
```

**没有 `mRange` 赋值**。

#### Devastator — `__Packages/Thing/Weapon/CThing_Weapon_Devastator.as:14-25`（全文件 0 加密记号）

```as2
16:  super(tPosition,tAngle,tParent);
17:  this.mFireRate = 4;
18:  this.mTotalAmmo = this.mAmmo = Thing.Weapon.CThing_Weapon.mInfinateAmmo;
19:  this.mFireRateCount = 0;
20:  this.mDamage = 100;
21:  this.mAuto = true;
22:  this.mRange = 8;
```

### 2.2 两处特例小结

| 特例 | 说明 |
|---|---|
| **UZI 的乱码属性名** | `__Packages/Thing/Weapon/CThing_Weapon_UZI.as:639` 把射速写进一个非加密的乱码属性名，`mFireRate` 从未被赋值。**数值 4 可信；字段名是乱码。** 运行时后果见 §2.1 的 UZI 段。 |
| **Mine 的 `mFireRateCount = 12`** | `__Packages/Thing/Weapon/CThing_Weapon_Mine.as:468` 明文，覆盖构造函数里的 `0`（`:19`）。 |

### 2.3 构造函数里"没有 `mRange`"意味着什么（重要）

`Barrel` / `FakeWall` / `Mine` / `Rocket` / `ChargePack` / `SmartBomb` 六个武器的构造函数
**根本没有写 `mRange`**，`CThing_Weapon` 基类也没有写。因此这些武器的 `mRange` 是
**`undefined`**（不是 0，也不是某个默认值）。

后果分两类：

* **不使用 range 的**：`Barrel` / `FakeWall` / `Mine` / `ChargePack` 的 `Fire` 放置实体，
  不传范围（`CThing_Weapon_Barrel.as:31`、`CThing_Weapon_FakeWall.as:43`、
  `CThing_Weapon_Mine.as:42`、`CThing_Weapon_ChargePack.as:65`）。
* **依赖 Shot 默认值的**：`Rocket` 的 `Fire`（`CThing_Weapon_Rocket.as:107-110`）向 Shot 只传 4 个实参
  （`_loc4_, tAngle, this[§23]/*mParent*/, this[§9]/*mDamage*/`），**不传 range**，
  于是走 `CThing_Shot_Bullet` / `CThing_Shot_Rocket` 的**默认 range = 10**（见 §5.2）。
  `SmartBomb` 同样不使用 range。

> 也就是说：**这 6 把武器没有"射程"这个字段**，不要凭空给它们填数。
> 只有 **Pistol(8) / UZI(8) / Shotgun(7) / Grenade(6) / Railgun(10) / Devastator(8)** 有 `mRange`。

### 2.4 仍然没有恢复的东西（诚实清单）

| 项 | 状态 | 说明 |
|---|---|---|
| `mShortName` | **仅 ChargePack = `"Charges"`**（`__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:85`，明文）。其余武器**未恢复** | 类尾元数据落在 FFDec 误并入的其他脚本块里 |
| `CThing_Object_LaserNode`（激光节点） | **未恢复** | 2Play 与 MoreRooms 的同名文件都只有 32/33 行且被加密 |
| `CThing_Shot_HomingMissile` / `CThing_Shot_DLaser` | **未恢复** | 两 build 同名文件均被加密 |
| `RandomPickup` 的定义 | **未恢复** | 全仓库只有 3 处**调用点**、0 处定义（详见 §9.2） |
| `CHud` 的弹药/武器面板细节 | **未恢复** | `__Packages/World/CHud.as` 2Play 505 行被加密 |
| 子弹"速度"这个量 | **不存在** | 见 §5.2 |
| 基类 `§43` / `§50` / `§52` 的具体方法名 | **未恢复** | 超出基类池范围（推断为松开 / 按住 / 刚按下） |
| UZI 那个乱码属性名的原文 | **未恢复** | 混淆器产物，无对应明文字符串 |

---

## 3. `mFireRate` 的单位：帧

**结论（数值直读 + 机制直读，确凿）：`mFireRate` 的单位是「帧」，不是秒。**

```
开火间隔(秒) = mFireRate / CMain.mFPS        （2Play 的 CMain.mFPS = 50）
每秒发数(shoots/s) = CMain.mFPS / mFireRate  = 50 / mFireRate
```

依据：

1. `Process()` 每帧对剩余冷却**减 1**：`__Packages/Thing/Weapon/CThing_Weapon.as:81`
   `if(--this[§§constant(5)] <= 0)` —— 该文件池映射 `§5 = mFireRateCount`。
2. `DecrementAmmo()` 把冷却重装为间隔：`__Packages/Thing/Weapon/CThing_Weapon.as:115`
   `this[§5] = this[§6];` = `mFireRateCount = mFireRate`。
3. 主循环用固定步长 `1000 / tFrameRate` 毫秒推进（`__Packages/CMain.as:247`），
   `CMain.mFPS` 即该帧率；SWF 头 `framerate = 50`。
4. **交叉印证**：`[MoreRooms] __Packages/CMain.as:188` 是明文 `}.mFPS = 25;`；
   而玩家回血写作 `mMaxLife / (CMain.mFPS * 30)`
   （`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:577`），即"30 秒回满"——
   证明 `mFPS` 是逐帧计数，与秒无关。

**换算表（2Play, 50 FPS）**：

| 武器 | `mFireRate` | 间隔 | 每秒发数（理论） | 每次开火投出的实体 |
|---|---|---|---|---|
| Pistol | 8 | 0.16 s | 6.25 | 1 发弹丸 |
| UZI | 4（见 §2.1） | 0.08 s | 12.5 | 1 发弹丸 |
| Shotgun | 12 | 0.24 s | 4.17 | **3** 发弹丸 |
| Barrel | 1 | 0.02 s | 50.0 | 1 个油桶实体 |
| Grenade | 12 | 0.24 s | 4.17 | 1 枚手雷 |
| Rocket | 12 | 0.24 s | 4.17 | 1 枚火箭 |
| Railgun | 5 | 0.10 s | 10.0 | 1 条射线 |
| FakeWall | 1 | 0.02 s | 50.0 | 1 面假墙实体 |
| Mine | 1 | 0.02 s | 50.0 | 1 枚地雷实体 |
| ChargePack | 1 | 0.02 s | 50.0 | 1 个炸药包实体 |
| SmartBomb | 12 | 0.24 s | 4.17 | 1 次全场效果 |
| Devastator | 4 | 0.08 s | 12.5 | 1 条持续伤害射线 |

> （推断）RapidFire 把 `mFireRate` 除以 4 并下限 2 帧（§7.3），于是 Pistol / UZI / Railgun 都变成
> 2 帧 = **25 发/秒**。这个上限很可能就是设计意图。

---

## 4. 从按键到扣血的完整伤害链路

> 本节权威来源是 **0 加密记号**的干净文件：`__Packages/Thing/CThing.as`（201 行）、
> `[MoreRooms] __Packages/World/Map/CMap_Affect.as`（129 行）。

```
① CThing_Creature_Player 的 State_PlayerControl()
     this.mWeapon_Current.Fire(this.mPosition, this.mAngle.mAngle)
② CThing_Weapon_XXX.Fire(tPosition, tAngle)
     super.Fire() → DecrementAmmo()            ← 扣 1 发（无限弹药不减）
     mThing_Collection.AddThing_Shot(new CThing_Shot_YYY(pos, ang, mParent, mDamage, …))
③ CThing_Shot_YYY 命中时
     mWorld.mMap.mAffect.Affect_Line(…) / AffectArea(rect, affect)
        new CThing_Affect_ZZZ(mParent, this /*affector*/, damage, …)
④ CMap_Affect 遍历候选 CThing：
     if ((thing.mAffectFlags & affect.mType) && affect.mAffector.mID != thing.mID)
         thing.Affect(affect)                  ← 只入队！mAffectors.push(affect)
⑤ 下一帧该 Thing 自己的 Process 里调 ProcessAffects()，再逐个结算：
     生物目标： AffectThing(affect) { thing.mLife -= affect.mDamage; return affect.mDamage; }
     爆炸目标： 带距离衰减的 AffectThing（§6.2）
     可爆物体： 按 mType 分派 → ApplyUpgrade_Object → Delete → 生成 Explosion
```

### 4.1 各步出处

| 步 | 出处 | 关键内容 |
|---|---|---|
| ① 玩家开火入口 | `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:617` | `this[mWeapon_Current].Fire(...)`；`mWeapon_Current` 由同文件 `:601` / `:604` 的 `this.mWeapon_Current.mNameID + "walk"` / `+"stand"` 明文确认。2Play 对应位置被加密；2Play 的武器表初始化在 `__Packages/Thing/Creature/CThing_Creature_Player.as:338-352` |
| ② Pistol | `__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:44-46` | MuzzleFlash 特效；`AddThing_Shot(new CThing_Shot_Bullet(tPosition, tAngle, this[§34]/*mParent*/, this[§11]/*mDamage=26*/, 8))` |
| ② UZI | `__Packages/Thing/Weapon/CThing_Weapon_UZI.as:665-668` | `…(tPosition, tAngle, this[§33]/*mParent*/, this[§9]/*mDamage=35*/, this[§11]/*mRange=8*/)` |
| ② Shotgun | `__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:65-80` | 中心弹 + 两侧弹（角度 ±θ）；`…(…, this[§38]/*mParent*/, this[§9]/*51*/, this[§11]/*7*/)` |
| ② Railgun | `__Packages/Thing/Weapon/CThing_Weapon_Railgun.as:812-815` | `…(…, this[§33]/*mParent*/, this[§9]/*100*/, this[§11]/*10*/)` |
| ② Barrel | `__Packages/Thing/Weapon/CThing_Weapon_Barrel.as:31` | `AddThing(new CThing_Object_Barrel(_loc2_, tAngle, this[§28]/*mParent*/, this[§9]/*150*/))` |
| ② FakeWall | `__Packages/Thing/Weapon/CThing_Weapon_FakeWall.as:43` | `AddThing(new CThing_Object_Wall(_loc2_, tAngle, this[§28]/*mParent*/))` —— 不传伤害 |
| ② Mine | `__Packages/Thing/Weapon/CThing_Weapon_Mine.as:42` | `AddThing(new CThing_Object_Mine(_loc2_, tAngle, this[§28]/*mParent*/, this[§9]/*100*/))` |
| ② Rocket | `__Packages/Thing/Weapon/CThing_Weapon_Rocket.as:106-111` | `AddThing_Shot(Shot(…, this[§23]/*mParent*/, this[§9]/*250*/))`；随后 `shot[§28] = new Effect_Explosion(…, this[§23], this[§9])`，并把 `mClusterExplode` / `mBiggerBang` 拷到 effect。**不传 range** |
| ② Grenade | `__Packages/Thing/Weapon/CThing_Weapon_Grenade.as:38-47`（密文）<br>+ `[MoreRooms] __Packages/Thing/Weapon/CThing_Weapon_Grenade.as:40-48`（明文） | `AddThing_Shot(Shot_Grenade(…, mDamage/*150*/, CMath.Range(按住时长, 0.25, 0.75)))`；`shot.mEffect = new Effect_Explosion(…)`；`mEffect.mClusterExplode = this.mClusterExplode`；`mEffect.mBiggerBang = this.mBiggerBang`；`DecrementAmmo()` |
| ② ChargePack | `__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:65` | `AddThing(new CThing_Object_ChargePack(_loc4_, tAngle, this.mParent, this.mDamage/*150*/))` |
| ② Devastator | `__Packages/Thing/Weapon/CThing_Weapon_Devastator.as:40` | `AddThing_Shot(new CThing_Shot_Devastator(tPosition, tAngle, this.mParent, this.mDamage/*100*/))` |
| ② SmartBomb | `__Packages/Thing/Weapon/CThing_Weapon_SmartBomb.as:38-42` | `AddThing_Effect(new CThing_Effect_SmartBomb(this.mParent.mPosition, this.mParent.Angle, this.mParent, 3))` + `DecrementAmmo()`。**第 4 实参是 life=3，不是伤害**；`mDamage = 100` 在本 build 中**未被使用** |
| ③ 射线命中 | `__Packages/Thing/Shot/CThing_Shot_Laser.as:41,50` | `Collide_Line(…, 0.04, mAffect_Bullet, true)` → `Affect_Line(this, mPosition, mDestination, 0.04, new CThing_Affect_Bullet(this.mParent, this, this.mDamage, this.mAngle))` |
| ③ 爆炸命中 | `__Packages/Thing/Effect/CThing_Effect_Explosion.as:77-78` | `rect = (x−mRange, y−mRange, 2·mRange, 2·mRange)`；`AffectArea(rect, new CThing_Affect_Explosion(this.mParent, this, this.mDamage, this.mRange))` |
| ④ 区域判定 | `[MoreRooms] __Packages/World/Map/CMap_Affect.as:41-61` | `:54` `if (_loc2_.mAffectFlags & tAffect.mType && tAffect.mAffector.mID != _loc2_.mID) _loc2_.Affect(tAffect);` |
| ④ 线段判定 | `[MoreRooms] __Packages/World/Map/CMap_Affect.as:62-107` | 把 `p2−p1` 按 `_StepSize = 1`（`:127`）格切段，每段构造边长 `radius*2` 的 `Rectangle`（`:66`）+ 一条 `CLine`（`:69`），逐段 `_Affect_Line_Area` 做 `LineIntersection_ThingList`，去重后按 `:101` 同条件调 `Affect`；返回命中数 |
| ④ 为什么"不打自己" | `__Packages/Thing/CThing.as:101` | `this.mID = this.mParent != undefined ? tParent.mID : this.mUniqueID;` —— 子弹的 `mParent` = 武器，武器的 `mParent` = 玩家 ⇒ `mAffector.mID == 玩家.mID` |
| ⑤ 入队 | `__Packages/Thing/CThing.as:77-85` | `Affect_Setup(tFlags){ mAffectors = new Array(); mAffectFlags = tFlags; }`；`Affect(tAffect){ this.mAffectors.push(tAffect); }` |
| ⑤ 生物结算 | `__Packages/Thing/Affect/CThing_Affect.as:27-31`（基类，明文）<br>`__Packages/Thing/Affect/CThing_Affect_Bullet.as:21-25`（覆写，明文）<br>`__Packages/Thing/Affect/CThing_Affect_Explosion.as:19-32`（覆写为带衰减，明文） | `tThing.mLife -= this.mDamage; return this.mDamage;` |
| ⑤ 可爆物体结算 | `__Packages/Thing/Object/CThing_Object_WallMovable.as:112-148`（明文，该类内嵌 Barrel 定义） | `Process_Normal`：`if (this.mAffectors.length) this.ProcessAffects();`；`ProcessAffects`：取走队列，`switch(affect.mType)` 命中 `{mAffect_DevilAttack, mAffect_Bullet, mAffect_FireBall, mAffect_Explosion}` 之一则 `mWorld.mUpgrades.ApplyUpgrade_Object(this)`(`:140`) → `this.Delete()`(`:141`) → `AddThing_Effect(new CThing_Effect_Explosion(this.mPosition, this.mAngle, this.mParent, this.mDamage))`(`:142`) → 传下 `mClusterExplode` / `mBiggerBang`(`:143-144`) → `return`（**只吃第一个命中的 affect，一炸即删**） |

### 4.2 Affect 类型位掩码（`__Packages/Thing/Affect/CThing_Affect.as:34-110`，明文）

| 类型 | 值 | 行号 |
|---|---|---|
| `mAffect_None` | 0 | `:40` |
| `mAffect_Bullet` | **1** | `:47` |
| `mAffect_Electricuted` | 2 | `:54` |
| `mAffect_Explosion` | **4** | `:61` |
| `mAffect_Punched` | 8 | `:68` |
| `mAffect_Push` | 16 | `:75` |
| `mAffect_Vapourize` | 32 | `:82` |
| `mAffect_ZombieAttack` | 64 | `:89` |
| `mAffect_PlayerLineOfSight` | 128 | `:96` |
| `mAffect_DevilAttack` | 256 | `:103` |
| `mAffect_FireBall` | 512 | `:110` |

**玩家默认吃哪些伤害**（`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:554`，明文）：

```
Affect_Setup(mAffect_Bullet | mAffect_Explosion | mAffect_ZombieAttack | mAffect_PlayerLineOfSight)
          = 1 | 4 | 64 | 128 = 197
```

> **玩家不吃 `mAffect_FireBall`(512)**。所以恶魔火球必须走 `mAffect_DevilAttack`：
> `__Packages/Thing/Shot/CThing_Shot_FireBall.as:50` 里 `mDamageMultiply` 为真时改用
> `new CThing_Affect_DevilAttack(this.mParent, this, 10000, this.mAngle)`。
> 玩家 `mMaxLife = mLife = 200`（`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:560`）。

### 4.3 子弹的命中与"穿透"

`CThing_Shot_Laser`（`__Packages/Thing/Shot/CThing_Shot_Laser.as:41`）第 6 参数传 `true` ⇒ **射线穿透**，
沿途所有满足掩码的目标都吃 `mAffect_Bullet`。
`CThing_Shot_Bullet.Process_Normal`（`__Packages/Thing/Shot/CThing_Shot_Bullet.as:37-63`）则是单点命中：
命中后 `mDelay` 为假时切到 `Process_Dead`（`:33-36`），并在命中点按
`random(3)==0 && _root._quality != "LOW"` 生成血花（`:55-58`）。

---

## 5. 各类弹丸（CThing_Shot）

### 5.1 `CThing_Shot` 基类

`__Packages/Thing/Shot/CThing_Shot.as:16-20`：签名 `function(tPosition, tAngle, tParent, tDamage)`，
只存 `this[§§constant(5)] = tDamage`（`§§constant(5)` = `mDamage`）。

### 5.2 `CThing_Shot_Bullet`（手枪 / UZI / 霰弹枪的弹丸）

`__Packages/Thing/Shot/CThing_Shot_Bullet.as:14-24`：

```as2
function (tPosition, tAngle, tParent, tDamage, tRange, tDelay) {
    super(tPosition, tAngle, tParent, tDamage);
    this.mDelay = tDelay != undefined ? tDelay : false;      // :17
    tRange = tRange != undefined ? tRange : 10;               // :18  ← 默认 range = 10
    this.mDestination = this.mPosition.Add(
        new CThing_Position(1,0,0).RotateZ(this.mAngle.mAngle).Normalize(tRange));   // :19
    this.mMaxLife = this.mLife = 2;                           // :20  ← 寿命 2 帧
    this.mDelta = new CThing_Position(0,
        (random(4)+2) / CMap_Cell.mSize.x,
        (random(4)+2) / CMap_Cell.mSize.y).RotateZ(this.mAngle.mAngle);   // :21
    this.mAlpha = 75;                                         // :22
    this.Process = !this.mDelay ? this.Process_Normal : this.Process_Delayed;  // :23
}
```

| 参数 | 值 | 出处 |
|---|---|---|
| `tRange` 默认值 | **10** | `:18` |
| 寿命 `mMaxLife = mLife` | **2 帧**（0.04 s @50fps） | `:20` |
| 横向抖动 | `(random(4)+2) / cellSize` | `:21` |
| 透明度 | 75 | `:22` |
| 绘制 | 线宽 0.5、色 `0xCCCCCC`(13421772)、alpha = `mAlpha` | `:82` |

> **子弹"速度"不是常量**：`Process_Normal` 每帧 `mDelta.Scale(0.75)`（`:66`）并把
> `mDelta * 0.5` 累加到 `mDestination`（`:67-69`）—— 是**逐帧衰减的插值**，不是匀速运动。
> 又因寿命只有 2 帧，实际有效射程由碰撞判定决定。**故"速度"这个字段不存在。**

### 5.3 其余弹丸类

| 弹丸类 | 出处 | 关键数值 |
|---|---|---|
| `CThing_Shot_Laser` | `__Packages/Thing/Shot/CThing_Shot_Laser.as:19-25,35-67`（明文） | range 默认 10；`mDestination = mPosition + mAngle.mDelta.ScaleN(100)`；`mAlpha = 75`；`Collide_Line(…, 0.04, mAffect_Bullet, **true**)` 穿透；绘制双线（3px 青 `8421631` + 2px 白 `16777215`，`:65-66`） |
| `CThing_Shot_Railgun` | `__Packages/Thing/Shot/CThing_Shot_Railgun.as:73-82,96-108`（明文） | 签名 `(tPosition,tAngle,tParent,tDamage,tRange)`；range 默认 10；`mMaxLife = mLife = 2`；`mDelta = (0,(random(4)+2)/cell.x,(random(4)+2)/cell.y).RotateZ(angle)`；`mAlpha = 75`；命中用 `mAffect_Bullet` + 穿透 `true`（`:97`），再 `Affect_Line(…, new CThing_Affect_Bullet(…))`（`:106`） |
| `CThing_Shot_Devastator` | `__Packages/Thing/Shot/CThing_Shot_Devastator.as:57-121`（明文） | `mDelta = mAngle.mDelta.ScaleN(0.9)`；`SetRadius(0.25)`；撞墙即 `Delete()`（`:89-93`）；`_FireLine` 每 2 帧（`mCounter++ % 2 == 0 && mCounter >= 4`，`:95`）向左右 90°（`±1.5707963267948966`）各发一条"爆线" |
| `CThing_Shot_Devastator._FireLine` | `:103-121` | 从 `mPosition + a.mDelta.ScaleN(0.4)` 起沿射线每 0.4 格放一个爆炸，最多 `_loc3_ = 8` 个（`:110-120`）；每个 `new CThing_Effect_Explosion(_loc2_, …, this, **200**)`（`:117`）⇒ **每次爆线最多 8 × 200 = 1600 伤害**，两方向 3200 |
| `CThing_Shot_ClusterShell` | `__Packages/Thing/Shot/CThing_Shot_ClusterShell.as:14-27,60-64` | `mLife = mCounter = 16 + random(8)`（**16~23 帧**）；`mDelta` 缩放 `0.05 + random()*0.05`；`mDeltaZ = 0.5`；半径缩放 `0.1`；寿命结束时在自身位置生成 `CThing_Effect_Explosion(mPosition, mAngle, this, mDamage)`（`:62`） |
| `CThing_Shot_Grenade` | `__Packages/Thing/Shot/CThing_Shot_Grenade.as:30-58` | 签名 `(tPosition,tAngle,tParent,tDamage,tPower)`；`mLife = mCounter = **60**`（`:51`）；Z 轴初速 `40 / CMap_Cell.mSize.z`（`:52`）；`mDeltaZ = 0.5`，初速 `1 * tPower`（`:55`）；每帧 `mDeltaZ -= 0.06`（`:63`）；落地反弹 `ScaleN(0.5)`（`:70`） |
| `CThing_Shot_FireBall` | `__Packages/Thing/Shot/CThing_Shot_FireBall.as:14-74`（**76 行 / 0 记号，完全干净**） | 签名 `(tPosition,tAngle,tParent,tDamage,tDamageMultiply,tSpeed)`；`mDelta = mAngle.mDelta.ScaleN(tSpeed != undefined ? tSpeed : **0.15**)`（`:23`）；`mCollideRadius = **0.1**`（`:74`）；`SetRadius(!mDamageMultiply ? **0.25** : **1**)`（`:38`）；每帧 `mDelta.ScaleN(1.02)` 加速（`:45`）；命中 `AffectArea(rect, !mDamageMultiply ? new CThing_Affect_FireBall(…) : new CThing_Affect_DevilAttack(…, **10000**, …))`（`:50`） |
| `CThing_Shot_HomingMissile` / `CThing_Shot_DLaser` | — | **整体加密，未恢复**（见 §2.4） |

---

## 6. 爆炸半径公式与伤害衰减

> 本节结论全部来自 `__Packages/Thing/Effect/CThing_Effect_Explosion.as`
> （**101 行 / 0 加密记号，完全干净**）与 `__Packages/Thing/Affect/CThing_Affect_Explosion.as`。

### 6.1 半径公式（数值直读）

`__Packages/Thing/Effect/CThing_Effect_Explosion.as:19-22`：

```as2
this.mDamage = tDamage;
this.mRange  = 2 + Math.max(this.mDamage - 100, 0) * 0.005;   // ← 半径（格）
this.mDelay  = 0;
this.mClusterExplode = this.mBiggerBang = 0;
```

```
半径(格) = 2 + max(damage − 100, 0) × 0.005
```

| 伤害来源 | damage | 半径（格） |
|---|---|---|
| 地雷 / 假墙 / 炸药包 / 油桶 / SmartBomb | 100 | **2.000** |
| 手雷 | 150 | **2.250** |
| Devastator 爆线 | 200 | **2.500** |
| 火箭 | 250 | **2.750** |

> ⚠ **BiggerBang / BigBang 不改变半径**，只增加子爆炸/子弹**数量**（§6.4）。
> **只有 `mDamage` 变大才会放大半径**，所以 `DoubleDamage`(×2) / `QuadDamage`(×4) / `FatalDamage`(×10)
> 会同时放大半径：

| 组合 | damage | 半径 |
|---|---|---|
| 手雷 + DoubleDamage | 300 | 3.000 |
| 手雷 + QuadDamage | 600 | 4.500 |
| 手雷 + FatalDamage | 1500 | **9.000** |
| 火箭 + FatalDamage | 2500 | **14.000** |

### 6.2 伤害衰减（数值直读）

`__Packages/Thing/Affect/CThing_Affect_Explosion.as:14-32`：

```as2
function (tOwner, tAffector, tDamage, tRange) {
    super(CThing_Affect.mAffect_Explosion, tOwner, tAffector, tDamage);   // :16
    this.mRange = tRange;                                                 // :17
}
AffectThing = function(tThing) {
    var d = tThing.mPosition.Distance2D(this.mOwner.mPosition);           // :21
    if (d <= this.mRange) {
        var r = d / this.mRange;                                          // :26
        var dmg = r > 0.5 ? (r > 0.75 ? this.mDamage * 0.5 : this.mDamage * 0.75)
                          : this.mDamage;                                 // :27
        tThing.mLife -= dmg;                                              // :28
        return dmg;
    }
    return 0;                                                             // :31
}
```

| r = 距离/半径 | 伤害倍率 | 举例：火箭(250, 半径 2.75) |
|---|---|---|
| `0 ≤ r ≤ 0.5` | **1.00 ×** | 距离 ≤ 1.375 格 → **250** |
| `0.5 < r ≤ 0.75` | **0.75 ×** | 1.375 ~ 2.0625 格 → **187.5** |
| `0.75 < r ≤ 1.0` | **0.50 ×** | 2.0625 ~ 2.75 格 → **125** |
| `r > 1.0` | **0（不命中）** | — |

### 6.3 爆炸的生成时机与范围查询（明文）

`__Packages/Thing/Effect/CThing_Effect_Explosion.as:69-86`（`Process_Delay`）：

```as2
if (--mDelay >= 0) return;                          // :71-74  ← mDelay 帧后才真正爆
mWorld.Shake(new flash.geom.Point(0, 30));          // :75
mWorld.mBrightness = 1;                             // :76
rect = new flash.geom.Rectangle(mPosition.mX - mRange, mPosition.mY - mRange, mRange*2, mRange*2);  // :77
mWorld.mMap.mAffect.AffectArea(rect, new CThing_Affect_Explosion(mParent, this, mDamage, mRange));  // :78
mWorld.mMap.mDecal.Draw_ScorchMark(mPosition);      // :80
PlaySound(CSound.mSamples.Effect_Explosion_wav);    // :81
```

即 **AABB 矩形粗筛 → 再按圆形距离判定真正命中**。
特效动画 `Animate(2.5)` 播完即 `Delete()`（`:89-92`）。

### 6.4 `mClusterExplode` 与 `mBiggerBang` 的实际效果（明文）

`__Packages/Thing/Effect/CThing_Effect_Explosion.as:42-65`：

```as2
if (this.mClusterExplode) {                                    // :42
    _loc2_ = 0;
    _loc3_ = PI360 / 4;                                        // :45  ← 4 份
    while (_loc2_ < PI360) {
        _loc4_ = new CThing_Angle(_loc2_ + random()*(_loc3_/2) - _loc3_/4);
        AddThing_Shot(new CThing_Shot_ClusterShell(mPosition.Clone(), _loc4_, mParent, mDamage));  // :49
        _loc2_ += _loc3_;
    }
}
if (this.mBiggerBang) {                                        // :54
    _loc2_ = 0;
    _loc3_ = PI360 / (this.mBiggerBang * 1.5);                 // :57
    while (_loc2_ < PI360) {
        _loc4_ = new CThing_Angle(_loc2_ + random()*(_loc3_/4) - _loc3_/8);
        _loc5_ = AddThing_Effect(new CThing_Effect_Explosion(mPosition.Add(_loc4_.mDelta), _loc4_, mParent, mDamage));  // :61
        _loc5_.mDelay = 2 + random(4);                         // :62  ← 2..5 帧延迟
        _loc2_ += _loc3_;
    }
}
```

| 标志 | 值来源 | 子物体数量 | 携带 damage |
|---|---|---|---|
| `mClusterExplode = 1` | ClusterExplode 升级（§7.4） | **4** 枚 `CThing_Shot_ClusterShell`，角度均分 + 随机抖动 | 父爆炸的 `mDamage` |
| `mBiggerBang = 1`（BigBang） | BigBang 升级 | `PI360 / (1 × 1.5)` = **6** 个延迟子爆炸 | 同值 |
| `mBiggerBang = 2`（BiggerBang） | BiggerBang 升级（覆盖 BigBang） | `PI360 / (2 × 1.5)` = **4** 个延迟子爆炸 | 同值 |

> **⚠ 原版数值陷阱**：`mBiggerBang = 1` 反而比 `= 2` 生成更多子爆炸（6 > 4）。
> 而升级表里 BiggerBang 会把值设成 2 并**覆盖** BigBang 的 1（§7.4 的 `else if`）。
> 所以：拿到 BigBang → 6 个；再拿 BiggerBang → **降为** 4 个。
> 看起来是原版的**数值 bug**。Godot 里建议保留原行为并在注释里标明，或改成单调递增
> （如 6 / 10）—— **后者属于新增设计，不是还原**。

### 6.5 `mClusterExplode` / `mBiggerBang` 的传递路径

生产端（明文）：`__Packages/World/CUpgrades.as:221-232`（`ApplyUpgrade_Weapon`）

```as2
if (_loc3_.BiggerBang)          tThing.mBiggerBang = 2;
else if (_loc3_.BigBang)        tThing.mBiggerBang = 1;
if (_loc3_.ClusterExplode)      tThing.mClusterExplode = 1;
```

传播端：`[MoreRooms] __Packages/Thing/Weapon/CThing_Weapon_Grenade.as:45-47`（明文）

```as2
_loc2_.mEffect = new CThing_Effect_Explosion(_loc3_, tAngle, this.mParent, this.mDamage);
_loc2_.mEffect.mClusterExplode = this.mClusterExplode;
_loc2_.mEffect.mBiggerBang     = this.mBiggerBang;
```

物体类同理：`__Packages/Thing/Object/CThing_Object_ChargePack.as:62-63`（明文）、
`__Packages/Thing/Object/CThing_Object_WallMovable.as:142-144`（Barrel，明文）、
`__Packages/Thing/Object/CThing_Object_ChargePack.as:19`（初值 `mClusterExplode = mBiggerBang = 0`）。

> **2Play 差异**：2Play 的 `__Packages/Thing/Weapon/CThing_Weapon_Grenade.as:42-46` 属密文区，
> 其中 `mEffect.mClusterExplode` / `mEffect.mBiggerBang` 两行不可读。
> 但 2Play 的**消费端**（`__Packages/Thing/Effect/CThing_Effect_Explosion.as:22,42-65`）与
> **生产端**（`__Packages/World/CUpgrades.as:229-232`）都完整可读，
> 物体类（ChargePack / Barrel）的搬运也明文可读。
> 所以只有"手雷武器 → effect"这一跳在 2Play 里未见明文，用 `[MoreRooms]` 补齐。

---

## 7. 完整升级公式

出处：`__Packages/World/CUpgrades.as`。**该文件在 2Play 中 669 行 / 0 加密记号，完全干净。**

### 7.1 原始数值快照机制（先注册，再应用）

`ApplyUpgrade_Weapon` 每次都从 `mOriginalStats` 重新计算（`__Packages/World/CUpgrades.as:190-268`）：

```as2
ApplyUpgrade_Weapon = function(tThing) {
    var _loc3_ = this[tThing._CLASSID_];
    if (_loc3_.IDCount == tThing.mUpgradeObject.mIDCount) return;   // :193-196 无变化则跳过
    tThing.mUpgradeObject.mIDCount = _loc3_.IDCount;
    var _loc4_ = _loc3_.mOriginalStats;                             // :198  ← 原始值快照
    ...
}
```

`mOriginalStats` 在武器创建时由 `Register_Weapon` 拍下（`__Packages/World/CUpgrades.as:344-364`）：

```as2
_loc3_.mAuto       = tThing.mAuto;        // :353
_loc3_.mFireRate   = tThing.mFireRate;    // :354
_loc3_.mAmmo       = tThing.mAmmo;        // :355
_loc3_.mTotalAmmo  = tThing.mTotalAmmo;   // :356
_loc3_.mDamage     = tThing.mDamage;      // :357
_loc3_.mWideShot   = tThing.mWideShot;    // :358
_loc3_.mBiggerBang = tThing.mBiggerBang;  // :359
_loc3_.mRange      = tThing.mRange;       // :360
```

**关键含义**：升级是**幂等的、基于原始值的** —— 所有倍率都乘 `mOriginalStats.X`，不是乘当前值。
同一类武器共享一份 `mOriginalStats`（`this[tClassID]`）。

### 7.2 伤害类升级（互斥，优先级 Fatal > Quad > Double）

| 升级名 | 公式 | 出处 |
|---|---|---|
| `FatalDamage` | `mDamage = mOriginalStats.mDamage × 10` | `__Packages/World/CUpgrades.as:199-202` |
| `QuadDamage` | `mDamage = mOriginalStats.mDamage × 4` | `__Packages/World/CUpgrades.as:203-206` |
| `DoubleDamage` | `mDamage = mOriginalStats.mDamage × 2` | `__Packages/World/CUpgrades.as:207-210` |

### 7.3 射速类升级（互斥，优先级 RapidFire > FastFire）

| 升级名 | 公式 | 出处 |
|---|---|---|
| `RapidFire` | `mFireRate = Math.round(Math.max(mOriginalStats.mFireRate / 4, 2))`<br>`mFireRateCount = 0`<br>`mAuto = true` | `__Packages/World/CUpgrades.as:211-216` |
| `FastFire` | 只 `mAuto = true`（**不缩短间隔，只是变成按住连发**） | `__Packages/World/CUpgrades.as:217-220` |

换算（50 fps）：`mFireRate=8` → `max(2,2)=2` 帧 = **25 发/秒**；
`mFireRate=12` → `max(3,2)=3` 帧 ≈ **16.7 发/秒**；`mFireRate=4` → `max(1,2)=2` 帧 = 25 发/秒。

### 7.4 爆炸增强类升级（互斥，BiggerBang > BigBang；ClusterExplode 独立）

| 升级名 | 公式 | 出处 |
|---|---|---|
| `BiggerBang` | `mBiggerBang = 2` | `__Packages/World/CUpgrades.as:221-224` |
| `BigBang` | `mBiggerBang = 1` | `__Packages/World/CUpgrades.as:225-228` |
| `ClusterExplode` | `mClusterExplode = 1` | `__Packages/World/CUpgrades.as:229-232` |

（效果与陷阱见 §6.4。）

### 7.5 散射类升级（互斥，WiderShot > WideShot）

| 升级名 | 公式 | 出处 |
|---|---|---|
| `WiderShot` | `mWideShot = 2` | `__Packages/World/CUpgrades.as:233-236` |
| `WideShot` | `mWideShot = 1` | `__Packages/World/CUpgrades.as:237-240` |

> **⚠ 重要发现：`mWideShot` 只被写入，从未被读取。**
> 全仓库（2Play `linearized`、2Play `scripts`、2Play `resolved`、MoreRooms `linearized`、
> MoreRooms `scripts`）搜 `mWideShot`，命中只有：
> `__Packages/World/CUpgrades.as:235`、`:239`（写入）、`:358`（快照记录）、
> `__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:44`（初值 `0`），
> 以及 `__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:198`（该行同时引用了
> `CThing_Effect_MuzzleFlash`，属 FFDec 误并入的其他脚本块，不足为据）。
> **没有任何一处把它作为散射角的输入。**
> **结论：Wide Shot / Wider Shot 两个升级在本 build 中实际不生效**（原版 bug 或未完成功能）。
> （推断）原设计意图应是让霰弹的散射角或弹丸数随 `mWideShot` 变化。
> Godot 若要"散射真的变宽"，那是**新增设计**。

### 7.6 弹药类升级（互斥，Infinate > Quad > Double）

| 升级名 | 公式 | 出处 |
|---|---|---|
| `InfinateAmmo` | `mTotalAmmo = mInfinateAmmo (999999)`；`mAmmo = 999999` | `__Packages/World/CUpgrades.as:241-245` |
| `QuadAmmo` | `mTotalAmmo = mOriginalStats.mTotalAmmo × 4`；`mAmmo = mOriginalStats.mAmmo × 4` | `__Packages/World/CUpgrades.as:246-250` |
| `DoubleAmmo` | `mTotalAmmo = mOriginalStats.mTotalAmmo × 2`；`mAmmo = mOriginalStats.mAmmo × 2` | `__Packages/World/CUpgrades.as:251-255` |

### 7.7 制导与射程类升级

| 升级名 | 公式 | 出处 |
|---|---|---|
| `HomingMissiles` | `mHomingMissiles = true` | `__Packages/World/CUpgrades.as:256-259` |
| `InfinateRange` | `mRange = 100` | `__Packages/World/CUpgrades.as:260-263` |
| `LongShot` | `mRange = mOriginalStats.mRange × 1.5` | `__Packages/World/CUpgrades.as:264-267` |

> ⚠ `InfinateRange` 与 `LongShot` 互斥，`InfinateRange` 优先（`else if` 结构）。
> ⚠ **`mHomingMissiles` 同样只被写入、从未被读取** —— 全仓库搜 `mHomingMissiles`
> 只有 `__Packages/World/CUpgrades.as:258` 一处。**`HomingMissiles` 升级在本 build 中不生效。**
> ⚠ **射程升级的实际效果有限**：`mRange` 只在 UZI / Shotgun / Railgun 的 `Fire` 里作为第 5 个实参传给 Shot
> （`__Packages/Thing/Weapon/CThing_Weapon_UZI.as:667`、
> `__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:70`、
> `__Packages/Thing/Weapon/CThing_Weapon_Railgun.as:814`），
> 而这三者的 Shot 都在 **2 帧**内完成命中判定
> （`__Packages/Thing/Shot/CThing_Shot_Bullet.as:20` / `__Packages/Thing/Shot/CThing_Shot_Railgun.as:78`）。
> 所以 `mRange` 变大主要影响**碰撞线段的长度**，而不是"子弹飞得更远"。
> 对 Pistol（硬编码 `8`，`__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:45`）以及
> Grenade / Rocket / Barrel / Mine / FakeWall / ChargePack（`Fire` 不传 range）**完全无效**。
> （推断）"Long Shot"在原版里的实际表现是"命中线段一次拉得更长，更容易碰到远处目标"。

### 7.8 生物 / 物体的升级（非武器，仅供对照）

| 目标 | 公式 | 出处 |
|---|---|---|
| `CThing_Creature_Zombie` | `mSpeed = mOriginalStats.mSpeed × (SpeedUp ?? 1)` | `__Packages/World/CUpgrades.as:166` |
| `CThing_Creature_Devil` | `mSpeed = mOriginalStats.mSpeed × (SpeedUp ?? 1)`<br>`mFireRate = mOriginalStats.mFireRate × (FireRateUp ?? 1)`<br>`mAttackSpeed = mOriginalStats.mAttackSpeed × (AttackSpeedUp ?? 1)` | `__Packages/World/CUpgrades.as:153-155` |
| `CThing_Object` | `BiggerBang → mBiggerBang = 2`；`BigBang → mBiggerBang = 1`；`ClusterExplode → mClusterExplode = 1` | `__Packages/World/CUpgrades.as:177-188` |

### 7.9 关卡级（Level）自动升级

`CUpgrades.InitLists` 为 LEVEL 1..100 生成（`__Packages/World/CUpgrades.as:378-398`）：

```as2
var _loc8_ = 1 * CMain.mFPS;                       // :370  僵尸生成间隔（帧），起始 50
var _loc4_ = !_global.mCheat_OneZombie ? 10 : 1;   // :371  场上僵尸上限，起始 10
var _loc5_ = 10;                                   // :372  本关僵尸总数，起始 10
var _loc6_ = 10 * CMain.mFPS;                      // :373  恶魔生成间隔，起始 500
var _loc7_ = 0;                                    // :374  场上恶魔上限
var _loc9_ = 0;                                    // :375  本关恶魔总数
while (_loc3_ <= 100) {
    Level.Zombie_SpawnRate   = floor(_loc8_);                              // :380
    Level.Zombie_Count       = floor(_loc4_);                              // :381
    Level.Zombie_TotalCount  = floor(_loc5_);                              // :382
    CThing_Creature_Zombie.SpeedUp = min(1 + _loc3_/100*10, 5);            // :383  ← 1..5 倍
    _loc8_ = max(_loc8_ - 1, 1);                                           // :384
    _loc4_ = min(_loc4_ + 5, 60);                                          // :385  ← 上限 60
    _loc5_ += 5;                                                           // :386
    if (CMain.mSaveData.mDevilsActive) {
        Level.Devil_SpawnRate  = floor(_loc6_);                            // :389
        Level.Devil_Count      = floor(_loc7_);                            // :390
        Level.Devil_TotalCount = floor(_loc9_);                            // :391
        CThing_Creature_Devil.SpeedUp = min(1 + _loc3_/100*10, 5);          // :392
        _loc7_ = min(_loc3_ != 1 ? _loc7_ + 0.3 : 1, 5);                    // :393  ← 恶魔上限 ≤ 5
        _loc9_ = _loc3_ != 1 ? _loc9_ + 0.25 : 1;                           // :394
        _loc6_ = max(_loc6_ - 1, CMain.mFPS);                              // :395  ← 最快 50 帧
    }
    _loc3_++;
}
this.mLevel = 1;
this.mMultiplier = 0;                              // :401  ← 初值为 0
```

| 量 | LEVEL 1 | LEVEL 100 |
|---|---|---|
| `Zombie_SpawnRate`（帧） | 50 | 1 |
| `Zombie_Count`（场上上限） | 10 | 60（另有 `_root._quality=="LOW"` 时 40 的限制，`__Packages/World/CUpgrades.as:44`） |
| `Zombie_TotalCount` | 10 | 505 |
| 僵尸 `SpeedUp` | 1.1 | 5.0 |
| （恶魔激活后）`Devil_SpawnRate` | 500 | 50 |
| （恶魔激活后）`Devil_Count` | 1 | 5 |

### 7.10 关卡推进 / 倍率计时

| 逻辑 | 公式 | 出处 |
|---|---|---|
| 关卡推进条件 | 场上无僵尸、无恶魔、无其它 counter → `++mLevel` | `__Packages/World/CUpgrades.as:33-41` |
| 僵尸补刷 | `Level.mZombieCount < min(Zombie_Count, _root._quality!="LOW" ? 60 : 40)` 且 `--mSpawnCount_Zombie <= 0` | `__Packages/World/CUpgrades.as:44-53` |
| 恶魔补刷 | `--mSpawnCount_Devil -= (Zombie_Count != 0 ? 1 : 10)`，`<= 0` 则刷 | `__Packages/World/CUpgrades.as:54-63` |
| 倍率衰减 | `if (mMultiplierTick-- < 0) --mMultiplier;` | `__Packages/World/CUpgrades.as:72-75` |
| 连杀衰减 | `if (mMultipleKillsTick-- < 0) mMultipleKill = 0;` | `__Packages/World/CUpgrades.as:68-71` |
| **倍率持续帧数** | `GetTicks(index) = (100 − (min(index,100) − 1))^2.5 / 100000.00000000003 × (CMain.mFPS×3 − 3) + 3` | `__Packages/World/CUpgrades.as:585-590` |
| 连杀持续帧数 | `GetTicks(mMultipleKillsIndex) / 6` | `__Packages/World/CUpgrades.as:534` |

**难度预设**（`SetDifficulty`，`__Packages/World/CUpgrades.as:87-104`；
`_loc3_` = 初始 LEVEL，`_loc2_` = 初始 MULTIPLIER）：

| tDifficulty | 初始 `mLevel` | 初始 `mMultiplier` |
|---|---|---|
| 0 | 1 | 1 |
| 1 | 10 | 10 |
| 2 | 20 | 30 |
| 3 | 35 | 50 |
| DeathMatch（忽略 tDifficulty） | 1 | **200**（`__Packages/World/CUpgrades.as:81-84`） |

`GetTicks` 换算成秒（50 fps）：`index=1` → `100^2.5/1e5 × 147 + 3 = 150 秒`；
`index=100` → `1^2.5/1e5 × 147 + 3 ≈ 3.0015 帧 ≈ 0.06 秒`。

---

## 8. 武器解锁顺序与倍率门槛

出处：`__Packages/World/CUpgrades.as:403-460`（干净文件）。
**DeathMatch 模式下 `CUpgrades.Process` 直接 return（`__Packages/World/CUpgrades.as:28-31`），
所有升级都不发放**（该模式靠 `SetDifficulty` 把 `mMultiplier` 直接设成 200，一次性发到第 200 档）。

### 8.1 完整解锁表（按倍率升序）

| MULTIPLIER | 目标类 | 属性 | 值 | HUD 提示文本 | 行号 |
|---:|---|---|---|---|---|
| 3 | `CThing_Weapon_Pistol` | `FastFire` | true | Pistol+: Fast Fire | `:403` |
| **5** | `CThing_Creature_Player` | `NW_uzi` | `"uzi"` | New Weapon: UZI (Key 2) | `:404` |
| 8 | `CThing_Weapon_Pistol` | `DoubleDamage` | true | Pistol+: Double Damage | `:405` |
| **10** | `CThing_Creature_Player` | `NW_shotgun` | `"shotgun"` | New Weapon: Shotgun (Key 3) | `:406` |
| 13 | `CThing_Weapon_UZI` | `RapidFire` | true | UZI+: Rapid Fire | `:407` |
| **15** | `CThing_Creature_Player` | `NW_barrel` | `"barrel"` | New Weapon: Barrel (Key 4) | `:408` |
| 17 | `CThing_Weapon_UZI` | `DoubleAmmo` | true | UZI+: Double Ammo | `:409` |
| 18 | `CThing_Weapon_Shotgun` | `FastFire` | true | Shotgun+: Fast Fire | `:410` |
| **20** | `CThing_Creature_Player` | `NW_grenade` | `"grenade"` | New Weapon: Grenade (Key 5) | `:411` |
| 21 | `CThing_Weapon_Shotgun` | `DoubleAmmo` | true | Shotgun+: Double Ammo | `:412` |
| 23 | `CThing_Weapon_UZI` | `LongShot` | true | UZI+: Long Shot | `:413` |
| 26 | `CThing_Weapon_Barrel` | `DoubleAmmo` | true | Barrel+: Double Ammo | `:414` |
| **30** | `CThing_Creature_Player` | `NW_fakewall` | `"fakewall"` | New Weapon: Fake walls (Key 6) | `:415` |
| 31 | `CThing_Weapon_Shotgun` | `WideShot` | true | Shotgun+: Wide Shot | `:416` |
| 32 | `CThing_Object_Barrel` | `BigBang` | true | Barrel+: Big Bang | `:417` |
| 33 | `CThing_Weapon_Grenade` | `ClusterExplode` | true | Grenade+: Cluster Explode | `:418` |
| 35 | `CThing_Weapon_Shotgun` | `LongShot` | true | Shotgun+: Long Shot | `:419` |
| 36 | `CThing_Weapon_Barrel` | `QuadAmmo` | true | Barrel+: Quad Ammo | `:420` |
| 37 | `CThing_Weapon_FakeWall` | `DoubleAmmo` | true | Fake Wall+: Double Ammo | `:421` |
| 39 | `CThing_Weapon_UZI` | `QuadAmmo` | true | UZI+: Quad Ammo | `:422` |
| **40** | `CThing_Creature_Player` | `NW_mine` | `"mine"` | New Weapon: Claymore (Key 7) | `:423` |
| 41 | `CThing_Weapon_Shotgun` | `QuadAmmo` | true | Shotgun+: Quad Ammo | `:424` |
| 42 | `CThing_Weapon_Grenade` | `DoubleAmmo` | true | Grenade+: Double Ammo | `:425` |
| 43 | `CThing_Weapon_Shotgun` | `RapidFire` | true | Shotgun+: Rapid Fire | `:426` |
| 44 | `CThing_Object_Barrel` | `BiggerBang` | true | Barrel+: Bigger Bang | `:427` |
| 45 | `CThing_Weapon_Grenade` | `BigBang` | true | Grenade+: Big Bang | `:428` |
| 47 | `CThing_Object_Mine` | `ClusterExplode` | true | Claymore+: Cluster Explode | `:429` |
| 48 | `CThing_Weapon_UZI` | `DoubleDamage` | true | UZI+: Double Damage | `:430` |
| **50** | `CThing_Creature_Player` | `NW_rocket` | `"rocket"` | New Weapon: Rocket (Key 8) | `:431` |
| 51 | `CThing_Weapon_Shotgun` | `WiderShot` | true | Shotgun+: Wider Shot | `:432` |
| 52 | `CThing_Weapon_Grenade` | `QuadAmmo` | true | Grenade+: Quad Ammo | `:433` |
| 53 | `CThing_Weapon_FakeWall` | `QuadAmmo` | true | Fake Wall+: Quad Ammo | `:434` |
| 54 | `CThing_Weapon_Mine` | `DoubleAmmo` | true | Claymore+: Double Ammo | `:435` |
| **55** | `CThing_Creature_Player` | `NW_chargepack` | `"chargepack"` | New Weapon: Chargepack (Key 9) | `:436` |
| 56 | `CThing_Weapon_Shotgun` | `DoubleDamage` | true | Shotgun+: Double Damage | `:437` |
| 57 | `CThing_Weapon_Grenade` | `BiggerBang` | true | Grenade+: Bigger Bang | `:438` |
| 58 | `CThing_Object_Mine` | `BigBang` | true | Claymore+: Big Bang | `:439` |
| 59 | `CThing_Weapon_Rocket` | `FastFire` | true | Rocket+: Fast Fire | `:440` |
| 61 | `CThing_Weapon_UZI` | `InfinateRange` | true | UZI+: Infinate Range | `:441` |
| 62 | `CThing_Object_Mine` | `BiggerBang` | true | Claymore+: Bigger Bang | `:442` |
| 63 | `CThing_Object_ChargePack` | `ClusterExplode` | true | Charge Pack+: Cluster Explode | `:443` |
| 64 | `CThing_Weapon_Mine` | `QuadAmmo` | true | Claymore+: Quad Ammo | `:444` |
| 66 | `CThing_Weapon_Rocket` | `DoubleAmmo` | true | Rocket+: Double Ammo | `:445` |
| 68 | `CThing_Weapon_ChargePack` | `DoubleAmmo` | true | Charge Pack+: Double Ammo | `:446` |
| **70** | `CThing_Creature_Player` | `NW_railgun` | `"railgun"` | New Weapon: Railgun (Key 0) | `:447` |
| 72 | `CThing_Weapon_Rocket` | `BigBang` | true | Rocket+: Big Bang | `:448` |
| 74 | `CThing_Object_ChargePack` | `BigBang` | true | Charge Pack+: Big Bang | `:449` |
| 76 | `CThing_Weapon_ChargePack` | `QuadAmmo` | true | Charge Pack+: Quad Ammo | `:450` |
| 78 | `CThing_Weapon_Railgun` | `FastFire` | true | Railgun+: Fast Fire | `:451` |
| 80 | `CThing_Weapon_Railgun` | `DoubleAmmo` | true | Railgun+: Double Ammo | `:452` |
| 85 | `CThing_Weapon_Rocket` | `QuadAmmo` | true | Rocket+: Quad Ammo | `:453` |
| 90 | `CThing_Weapon_UZI` | `QuadDamage` | true | UZI+: Quad Damage | `:454` |
| 95 | `CThing_Object_ChargePack` | `BiggerBang` | true | Charge Pack+: Bigger Bang | `:455` |
| 100 | `CThing_Weapon_Railgun` | `RapidFire` | true | Railgun+: Rapid Fire | `:456` |
| 105 | `CThing_Weapon_Rocket` | `BiggerBang` | true | Rocket+: Bigger Bang | `:457` |
| 110 | `CThing_Weapon_Railgun` | `QuadAmmo` | true | Railgun+: Quad Ammo | `:458` |
| 120 | `CThing_Weapon_Rocket` | `RapidFire` | true | Rocket+: Rapid Fire | `:459` |
| 125 | `CThing_Weapon_Railgun` | `LongShot` | true | Railgun+: Long Shot | `:460` |

### 8.2 升级发放的触发机制

`mMultiplier` 的 setter（`__Packages/World/CUpgrades.as:556-576`）：

```as2
this.mMultiplierIndex = a >= 1 ? (a <= 999 ? a : 999) : 1;      // :558  ← 夹在 1..999
this.mMultiplierTickTotal = this.mMultiplierTick = GetTicks(this.mMultiplierIndex);  // :559
if (a > 1) {                                                    // :562
    _loc3_ = this.mMultipliers[this.mMultiplierIndex];          // :564  ← 只取"恰好这一档"
    for each (_loc2_ in _loc3_) {
        if (_loc2_.mActive != true) {                           // :568  ← 每项只发一次
            this.AddUpgrade(_loc2_.mName, _loc2_.mClassID, _loc2_.mProp, _loc2_.mValue);
            _loc2_.mActive = true;
        }
    }
}
```

> `mMultipliers[index]` 是按**精确索引**存的数组（`AddToMultipliers`，`__Packages/World/CUpgrades.as:462-467`），
> 所以"倍率 20"只发 `mMultipliers[20]` 里的项。倍率**逐 1 递增**
> （`LogKills`：`++mMultiplier`，`__Packages/World/CUpgrades.as:500-508`），从 19 涨到 20 时才发 20 档。
> 升级项一旦 `mActive = true` 就永不再发。

`LogKills(a)`（`__Packages/World/CUpgrades.as:500-508`）：

```as2
while (a) { ++this.mMultipleKill; ++this.mMultiplier; a = a - 1; }
```

由 `mZombieCount` / `mDevilCount` 的 setter 在"数量减少时"调用 `LogKills(1)`
（`__Packages/World/CUpgrades.as:591-624`）。
即 **每杀一个僵尸/恶魔，倍率 +1**，并在 while 循环里逐档触发升级。
（`mMultipleKills` 数组在 `InitLists` 里从未被 `AddToMultipleKills` 填充，所以连杀本身不直接给升级。）

### 8.3 不在玩家武器表里的武器

玩家武器表由 `InitWeapons` 建立，10 个槽位按 `KEY_SELECT0..9` 索引
（`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:43-51`，明文）：

```as2
var _loc2_ = [§105, §177, §176, §175, §174, §173, §172, §171, §170, §169];   // :43 武器名
var _loc3_ = [§187, §186, §185, §184, §183, §182, §181, §180, §179, §178];   // :44 类名
...
this[§158][_loc2_[_loc9_]] = { NameID:_loc2_[_loc9_], ClassID:_loc3_[_loc9_], Thing:undefined,
                               Owned:false, KeyIndex:(Number(_loc9_)+1) % 10 };   // :48
this[§191](_loc2_[0]);        // :50  ← 只把第 0 个（Pistol）设为拥有
```

`[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:562` 明文
`this.SelectWeapon("pistol");`。
2Play 的同一张表在 `__Packages/Thing/Creature/CThing_Creature_Player.as:340-351`，结构完全同构。

> 武器名与类名的具体字符串在两个文件里都被加密，所以"第 0 槽是 Pistol"由
> `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:562` 的明文
> `SelectWeapon("pistol")` 与 `:351` 的 `(_loc3_[0])` 共同确定；
> 其余 9 槽与键位的对应关系由 §8.1 的 `NW_*` 解锁项的 HUD 文本给出
> （`"New Weapon: UZI (Key 2)"` … `"(Key 0)"`），这是**文本直读**。

| 武器 | 键位 | 进入玩家武器表 | 出处 |
|---|---|---|---|
| Pistol | — | ✅ 起始自带 | `[MoreRooms] __Packages/Thing/Creature/CThing_Creature_Player.as:562` |
| UZI | 2 | ✅ 倍率 5 | `__Packages/World/CUpgrades.as:404` |
| Shotgun | 3 | ✅ 倍率 10 | `__Packages/World/CUpgrades.as:406` |
| Barrel | 4 | ✅ 倍率 15 | `__Packages/World/CUpgrades.as:408` |
| Grenade | 5 | ✅ 倍率 20 | `__Packages/World/CUpgrades.as:411` |
| FakeWall | 6 | ✅ 倍率 30 | `__Packages/World/CUpgrades.as:415` |
| Mine | 7 | ✅ 倍率 40 | `__Packages/World/CUpgrades.as:423` |
| Rocket | 8 | ✅ 倍率 50 | `__Packages/World/CUpgrades.as:431` |
| ChargePack | 9 | ✅ 倍率 55 | `__Packages/World/CUpgrades.as:436` |
| Railgun | 0 | ✅ 倍率 70 | `__Packages/World/CUpgrades.as:447` |
| **SmartBomb** | — | ❌ | 表中无 `smartbomb`、`InitLists` 里无 `NW_smartbomb`；只有 `mNameID="smartbomb"`（`__Packages/Thing/Weapon/CThing_Weapon_SmartBomb.as:44`）。**只能靠 debug/cheat 获得** |
| **Devastator** | — | ❌ | 表中无 `devastator`（`__Packages/Thing/Weapon/CThing_Weapon_Devastator.as:43` 是 `mNameID`）。**只能靠 debug/cheat 获得** |

---

## 9. 弹药、拾取物、以及各类部署物规则

### 9.1 弹药模型

| 规则 | 出处 |
|---|---|
| `mInfinateAmmo = 999999` 为"无限"哨兵 | `__Packages/Thing/Weapon/CThing_Weapon.as:129` |
| 开火扣弹：`mAmmo -= (mTotalAmmo != mInfinateAmmo ? 1 : 0)` | `__Packages/Thing/Weapon/CThing_Weapon.as:114` |
| 空仓时不再开火，HUD 显示 `mName + " is out of ammo!"` | `__Packages/Thing/Weapon/CThing_Weapon.as:75-80` |
| `Reset()`：`mAmmo = (mTotalAmmo != mInfinateAmmo ? 0 : mTotalAmmo)` —— 有限弹药武器重置为**空仓** | `__Packages/Thing/Weapon/CThing_Weapon.as:119` |
| 携带上限 = `mTotalAmmo`；`DoubleAmmo` ×2、`QuadAmmo` ×4、`InfinateAmmo` → 999999 | `__Packages/World/CUpgrades.as:241-255` |
| Pistol / Devastator 天然无限弹药 | `__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:18`、`__Packages/Thing/Weapon/CThing_Weapon_Devastator.as:18` |
| 其余武器弹药量见 §2 表 | — |

### 9.2 拾取物（`CThing_Object_Pickup`，**111 行 / 0 记号，完全干净**）

| 行为 | 值 / 逻辑 | 行号 |
|---|---|---|
| 创建 | `super(tPosition.mCellCentre, tAngle, tParent)` —— 吸附到格子中心 | `:17` |
| 拾取判定 | `if (mCurrentCell.mCollide & CMap_Cell.mCollide_Player) PickedUp();` | `:43-46` |
| 拾取动作 | `_loc2_ = mCurrentCell.ContainsClassID("CThing_Creature_Player")`；若该玩家 `mFlags & mFlag_DEAD` 则**不拾取**；否则 `_loc2_.RandomPickup()` | `:77-87` |
| 音效 | `CSound.mSamples.Object_Pickup_wav` | `:88` |
| `mDeleteOnPickup` 为真 → 立即 `Delete()` | 击杀掉落物走这条 | `:89-93` |
| 否则（地图固定拾取点）→ 隐藏并等待重生 | `mReappearCount = CMain.mFPS × (mGameMode != "DeathMatch" ? 30 : 10)` ⇒ **普通 30 秒 / DeathMatch 10 秒** | `:94-96` |
| 重生倒计时结束 | 回到 `Process_Init` | `:48-54` |
| 击杀掉落条件 | 只有 `Zombie` 且 `mMultipleKill % 5 == 0`、或 `Devil` 才掉落 | `[MoreRooms] __Packages/World/CWorld.as:366-397` |
| 掉落点 | 必须不在静态不可通行格上 | `[MoreRooms] __Packages/World/CWorld.as:389` |
| 掉落物消失倒计时 | `SetDeleteCounter(CMain.mFPS * 10)` = **10 秒**；最后 1 秒淡出 `mAlpha = mDeleteCounter / mFPS * 100` | `[MoreRooms] __Packages/World/CWorld.as:393`、`__Packages/Thing/Object/CThing_Object_Pickup.as:61-76` |

> ⚠ **`RandomPickup()` 的具体内容未恢复**（该函数整体被字符串加密；全仓库只找到 3 处**调用点**、
> 0 处定义：`__Packages/Thing/Object/CThing_Object_Pickup.as:86`、`linearized_v2` 同位置、
> `scripts/scripts` 原始版 `:223`。已在 `CThing_Creature.as`、`CThing_Creature_Player.as`、
> `CThing_Creature_Zombie.as`、`CThing_Creature_Devil.as` 及 MoreRooms 对应文件中搜索）。
> （推断）从命名与调用位置看，它是"随机给一次补给"，最可能给当前武器补弹或随机补给资源。

### 9.3 地图上的固定拾取物

`__Packages/World/Init/CWorld_Init_Pickup.as` 在 2Play 中**只有 20 行的空壳**
（`:14-19` 只有 `super()` 与 `_CLASSID_`，没有 Spawn 逻辑）。
`[MoreRooms] __Packages/World/CWorld.as:115-116` 显示了真正的生成入口：

```as2
case "CWorld_Init_Pickup":
    this.mThing_Collection.AddThing(new Thing.Object.CThing_Object_Pickup(_loc2_));
```

`AddSpawnPoint_Pickup(p)` 把它存进 `mSpawnPoint_Pickup` 数组
（`[MoreRooms] __Packages/World/CWorld.as:275-279`）。
2Play 的对应入口在被加密的 `CWorld.as` 中。

### 9.4 地雷 / 炸药包 / 假墙 / 油桶的部署与触发

| 武器 | 放置 | 出处 |
|---|---|---|
| **Mine（键 7）** | `Fire` 时检查目标格 `GetCell(...).mChildCount <= 1`，通过则 `AddThing(new CThing_Object_Mine(_loc2_, tAngle, this[§28]/*mParent*/, this[§9]/*100*/))`，再 `DecrementAmmo()` 并播 `Weapon_Mine_Place_wav` | `__Packages/Thing/Weapon/CThing_Weapon_Mine.as:36-46` |
| **ChargePack（键 9）** | **两段式**：第一次 `Fire` 放置 `CThing_Object_ChargePack(_loc4_, tAngle, this.mParent, this.mDamage/*150*/)` 并置 `mDetonate = true`；第二次 `Fire` 找到本玩家所有 `CThing_Object_ChargePack` 并置 `mDetonate = true` | `__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:44-70`（明文） |
| ChargePack 空仓判定 | **覆写** `WeaponEmpty()`：`SearchThings(...CThing_Object_ChargePack).length == 0 && mAmmo <= 0` —— 场上还有炸药包就不算空仓 | `__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:71-75`（明文） |
| ChargePack 复位 | **覆写** `Reset()`：`mDetonate = (场上炸药包数量 && mAmmo <= 0)` | `__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:76-81`（明文） |
| **FakeWall（键 6）** | 两段式：`mDetonate` 为真时把附近假墙 `mVisible = true` 暴露出来；否则在空地上放一面假墙 | `__Packages/Thing/Weapon/CThing_Weapon_FakeWall.as:37-58`（结构同 ChargePack） |
| **Barrel（键 4）** | 单段：`AddThing(new CThing_Object_Barrel(_loc2_, tAngle, this[§28]/*mParent*/, this[§9]/*150*/))` | `__Packages/Thing/Weapon/CThing_Weapon_Barrel.as:27-34` |
| Barrel 对象默认伤害 | `this.mDamage = tDamage != undefined ? tDamage : 100` | `__Packages/Thing/Object/CThing_Object_Barrel.as:25` |
| ChargePack 对象默认伤害 | `this.mDamage = tDamage != undefined ? tDamage : 100` | `__Packages/Thing/Object/CThing_Object_ChargePack.as:17` |
| **Barrel 对象被击中后的完整反应** | `Process_Normal`：`if (mAffectors.length) ProcessAffects();`（`:112-118`）<br>`ProcessAffects`：取走 `mAffectors`，`switch(mType)` 命中 `{DevilAttack, Bullet, FireBall, Explosion}` 之一则：① `ApplyUpgrade_Object(this)`（`:140`）② `this.Delete()`（`:141`）③ `AddThing_Effect(new CThing_Effect_Explosion(mPosition, mAngle, mParent, this.mDamage))`（`:142`）④ 传下 `mClusterExplode` / `mBiggerBang`（`:143-144`）→ `return`（只吃第一个命中的 affect，一炸即删） | `__Packages/Thing/Object/CThing_Object_WallMovable.as:112-148`（明文，该类内嵌 Barrel 定义） |
| ChargePack 对象动画速率 | `mcDrawObject.Animate_Cycle(1 / CMain.mFPS)` | `__Packages/Thing/Object/CThing_Object_ChargePack.as:45`（明文） |
| ChargePack 起爆倒计时 | `mDetonateCounter = CMain.mFPS / 10`（= 0.1 秒） | `__Packages/Thing/Object/CThing_Object_ChargePack.as:48`（明文） |
| ChargePack 起爆音效 | `CSound.mSamples.Object_Mine_Detonate_wav` | `__Packages/Thing/Object/CThing_Object_ChargePack.as:123`（明文） |

> **激光节点（`CThing_Object_LaserNode`）**：2Play 与 MoreRooms 的同名文件都只有 32/33 行且被加密。
> **布置与触发规则未恢复。**

### 9.5 武器的 Process 与 HUD 显示

| 项 | 出处 |
|---|---|
| 武器每帧 `Process(tKey)`：处理子物体 → 查空仓 → 倒计时 → 按输入状态决定是否 `Fire` | `__Packages/Thing/Weapon/CThing_Weapon.as:72-103` |
| 空仓提示走 HUD 的 `AddMessage_Critical` | `__Packages/Thing/Weapon/CThing_Weapon.as:77-78` |
| 武器显示名 `mName` | ChargePack `"Charge Packs"`（`__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:84`）、Devastator `"The Devastator"`（`__Packages/Thing/Weapon/CThing_Weapon_Devastator.as:44`）、SmartBomb `"Smart Bomb"`（`__Packages/Thing/Weapon/CThing_Weapon_SmartBomb.as:45`）均为明文；Grenade 见 `[MoreRooms] __Packages/Thing/Weapon/CThing_Weapon_Grenade.as:52` |
| 武器短名 `mShortName` | **只有 ChargePack = `"Charges"`**（`__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as:85`，明文），其余**未恢复** |
| HUD 弹药面板 | `__Packages/World/CHud.as` 2Play 505 行被加密。**未恢复** |

### 9.6 武器解锁的存档（结论：**原版不存档武器解锁**）

一个**确凿的否定结论**，能省掉 Godot 里一整块无用设计：

* `[MoreRooms] __Packages/CSaveData.as` **完全干净（134 行 / 0 记号）**，
  它的全部可存档属性只有 6 个（`:127-132` 的 `addProperty` 列表 + `:121-126` 的默认值）：

  | 属性 | 默认值 | 行号 |
  |---|---|---|
  | `mDetail` | true | `:123`、`:127` |
  | `mDifficulty` | 0 | `:125`、`:128` |
  | `mMusicActive` | true | `:121`、`:129` |
  | `mPlayCount` | 0 | `:126`、`:130` |
  | `mSoundActive` | true | `:122`、`:131` |
  | `mUsername` | （无默认） | `:132` |

  存档实体是 `SharedObject.getLocal(tUsername)`（`:101`），`SaveData()` 就是 `flush()`（`:94-98`）。
  **列表里没有任何武器解锁 / 关卡进度 / 分数类字段。**

* 2Play 的 `__Packages/CSaveData.as` 被加密（481 行），`addProperty` 列表有**约 30 项**（`:448-478`）。
  其中一项是 `mDevilsActive`（`__Packages/World/CUpgrades.as:387` 读了 `CMain.mSaveData.mDevilsActive`）。
  **哪一项是武器解锁标志无法指认 —— 未恢复。**

* **但机制上"武器解锁不需要存档"**：解锁完全由 `CUpgrades.mMultiplier` 驱动（§8.2），
  而 `mMultiplier` 是局内的、初始为 0（`__Packages/World/CUpgrades.as:401`），
  靠 `SetDifficulty` 预设（§7.10）。每局都从 `mMultiplier = 0` 重新爬。
  > （推断）原版设计就是"**每局重新解锁**"，而不是"跨局保留解锁进度"。
  > Godot 若想做成跨局保留，那是**新增设计**，不是还原。

---

## 10. 给 Godot 实现的迁移建议

1. **武器数值表直接照 §2 建资源文件**。数值与字段名都可信（直读）。
   `mFireRate` 用"帧"存，运行时按 `Engine.physics_ticks_per_second`（建议 50）换算，
   或直接改成"开火间隔秒"：`interval = mFireRate / 50.0`。
2. **把 `mFireRate`（间隔）与 `mFireRateCount`（剩余冷却）拆成两个字段** —— 原版是两个变量，
   `RapidFire` 会同时改两者。**注意基类与子类的字段顺序相反**（§1.2）。
3. **注意 §2.3：`Barrel`/`FakeWall`/`Mine`/`Rocket`/`ChargePack`/`SmartBomb` 没有 `mRange`。**
   不要给它们凭空填射程。只有 Pistol(8)/UZI(8)/Shotgun(7)/Grenade(6)/Railgun(10)/Devastator(8) 有。
4. **升级系统照 §7 做成"基于 `mOriginalStats` 的幂等重算"**：每次从原始快照重算全部字段，
   而不是增量修改。这样 `FatalDamage`→`QuadDamage` 之类的叠加永远不会算错。
5. **爆炸照 §6.1/§6.2 做两级判定**：AABB 粗筛 → 圆形 `r = dist/radius` 阶梯取整伤害。
   半径由伤害推导，所以改伤害会自动改半径。
6. **伤害链路要复现"两阶段"**（§4）：`Affect()` 只入队，下一帧该实体自己的 `Process` 里才结算。
   若改成即时结算，会与原版的"可爆物体只吃第一个 affect""同一帧多次命中"等行为产生差异。
7. **反自伤靠 `mID` 继承**：子弹/爆炸的 `mParent` 链最终指向开火者，
   命中判定比较 `affector.mID != thing.mID`。Godot 里可用"归属者 owner_id + 继承"复现。
8. **三个已知无效升级**（`WideShot`/`WiderShot`、`HomingMissiles`，以及本 build 的 `SmartBomb.mDamage`）
   建议**补全设计**而不是照抄失效逻辑，并在代码里注释"原版此处无效"。
9. **`BiggerBang` 的子爆炸数量反直觉**（1 → 6 个，2 → 4 个，§6.4），
   建议改成单调递增（如 6 / 10）并注明与原版的差异。
10. **按 §8.1 的表实现解锁**：倍率逐 1 递增，"只在恰好等于该档时发放"，且每项只发一次。
11. **`RandomPickup`（§9.2）需要自己设计** —— 原版数值未能恢复。
12. **武器解锁不必做持久化**（§9.6：原版每局从 `mMultiplier = 0` 重来）。
13. **UZI 的射速按 `mFireRate = 4` 处理**（§2.1 的 UZI 段），并在注释里记录原版那一格是乱码属性名。

---

## 附录 A：证据分级

| 级别 | 含义 | 本文档中的范围 |
|---|---|---|
| **①常量池恢复（= 直读）** | 字段名由 SWF 内明文的 `ActionConstantPool` 直接解出，数值是文件里的字面量 | **§2 全部 12 把武器的全部字段名与数值**；§1.2 基类字段；§4.2 Affect 位掩码；§6、§7、§8.1 的全部公式与条目；§9.2 拾取规则；§9.4 部署规则 |
| **②[MoreRooms] 来源** | 2Play 中该处无明文，只能取 MoreRooms（**两 build 常量池不同，不可互相解**） | 玩家武器表（`:43-51` / `:562`）；玩家 `mMaxLife=200`；玩家吃伤害掩码；击杀掉落判定；手雷→effect 的 `mClusterExplode`/`mBiggerBang` 搬运；`mFPS = 25`（**与 2Play 的 50 不可混用**）；FakeWall 伤害 150（2Play 是 100） |
| **③（推断）** | 我的推理，代码里没有直接写明 | `§43`/`§50`/`§52` 的按键方法名；UZI 的 `mFireRateCount = undefined` 后果；Mine 的 `mFireRateCount` 最终值为 12；RapidFire 25 发/秒上限的设计意图；WideShot 的原设计意图；`RandomPickup` 的作用；"每局重新解锁"的设计意图 |
| **④未恢复** | 尝试后仍读不到 | 全部 `mShortName`（除 ChargePack）；`CThing_Object_LaserNode`；`CThing_Shot_HomingMissile`；`CThing_Shot_DLaser`；`RandomPickup` 的定义；`CHud` 的弹药面板；基类 `§43`/`§50`/`§52` 的名字；UZI 那个乱码属性名的原文 |

### 一句话总结

* **数值**：12 把武器的全部核心数值（`mFireRate` / `mFireRateCount` / `mTotalAmmo` / `mAmmo` /
  `mDamage` / `mAuto` / `mOnRelease` / `mRange` / `mWideShot`）**全部直读，无一格是猜的**。
  构造函数里没写 `mRange` 的 6 把武器是**原版确实没写**（§2.3），不是"未恢复"。
* **字段名**：**全部直读**（由 SWF 内明文的常量池解出）。唯一例外是 UZI 的射速槽，
  原版是乱码属性名，`mFireRate` 未被赋值（§2.1）。
* **机制与公式**：伤害链路（§4）、爆炸半径与衰减（§6）、全部升级公式（§7）、
  完整解锁表（§8.1）、拾取物与部署规则（§9）—— 全部来自干净文件，确凿。

## 附录 B：两个 build 的可用性对照与差异

| 类 / 文件 | 2Play | MoreRooms | 本文档取值来源 |
|---|---|---|---|
| `__Packages/Thing/Weapon/CThing_Weapon_Devastator.as` | 46 行 · **0 记号** | 192 · 30 | 2Play（本来全明文） |
| `__Packages/Thing/Weapon/CThing_Weapon_SmartBomb.as` | 63 · 9 | 2132 · 693 | 2Play（本来近明文） |
| `__Packages/Thing/Weapon/CThing_Weapon_ChargePack.as` | 116 · 47 | 481 · 229 | 2Play（本来近明文） |
| `__Packages/Thing/Weapon/CThing_Weapon_Grenade.as` | 53 · 65 | **60 · 0** | 两者一致，互为印证 |
| `__Packages/Thing/Weapon/CThing_Weapon_Pistol.as` | 54 · 54 | 238 · 87 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as` | 220 · 256 | 2694 · 1232 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon_UZI.as` | 675 · 401 | 2395 · 979 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon_Barrel.as` | 75 · 110 | 295 · 62 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon_Rocket.as` | 118 · 168 | 2969 · 1432 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon_Railgun.as` | 826 · 591 | 55 · 59 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon_Mine.as` | 517 · 363 | 53 · 48 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon_FakeWall.as` | 56 · 57 | 124 · 145 | **2Play，常量池已解** |
| `__Packages/Thing/Weapon/CThing_Weapon.as`（基类） | 216 · 290 | 132 · 112 | **2Play，常量池已解** |
| `__Packages/Thing/Effect/CThing_Effect_Explosion.as` | 101 · **0** | 430 | 2Play |
| `__Packages/Thing/Shot/CThing_Shot_FireBall.as` | 76 · **0** | 139 | 2Play |
| `__Packages/Thing/Object/CThing_Object_Pickup.as` | 111 · **0** | 107 | 2Play |
| `__Packages/Thing/CThing.as`（实体基类） | 201 · **0** | 684 | 2Play |
| `__Packages/World/CUpgrades.as` | 669 · **0** | 671 · 1103 | 2Play |
| `__Packages/Thing/Object/CThing_Object_WallMovable.as`（含 Barrel） | 283 · 部分 | 84 | 2Play |
| `__Packages/World/Map/CMap_Affect.as` | 127 · 密文 | **129 · 0** | **`[MoreRooms]`（命中判定权威）** |
| `__Packages/CSaveData.as` | 481 · 密文（约 30 字段） | **134 · 0**（仅 6 字段） | **`[MoreRooms]`** |
| `__Packages/World/CWorld.as` | 724 · 密文 | **505 · 0** | **`[MoreRooms]`** |
| `__Packages/Thing/Creature/CThing_Creature_Player.as` | 495 · 密文 | 625 · 部分明文 | **`[MoreRooms]`** |
| `__Packages/World/CHud.as` | 505 · 密文 | 954 · 密文 | **未恢复** |

### 已确认的跨 build 数值差异（双方都明文可读，确凿）

| 项 | 2Play | MoreRooms | 双方出处 |
|---|---|---|---|
| `CMain.mFPS` | **50**（SWF 头） | **25** | `[MoreRooms] __Packages/CMain.as:188` 明文 `}.mFPS = 25;` |
| FakeWall `mDamage` | **100** | **150** | `__Packages/Thing/Weapon/CThing_Weapon_FakeWall.as:21`；`[MoreRooms] __Packages/Thing/Weapon/CThing_Weapon_FakeWall.as:15` |
| `CThing_Effect_SmartBomb` | **空壳**：`Process_Normal` 立刻 `Delete()`（`__Packages/Thing/Effect/CThing_Effect_SmartBomb.as:34-37`），无伤害逻辑 | **完整**：撞墙处生成 `CThing_Effect_Explosion(..., 200)`（`[MoreRooms] __Packages/Thing/Effect/CThing_Effect_SmartBomb.as:285`） | 各自文件 |

> **原则**：凡标 `[MoreRooms]` 的结论，在 2Play 里都**没有**对应的明文可读位置；
> 凡两 build 都读到的，本文档都给双方出处并确认一致。

## 附录 C：本文件曾出现的错误结论（已撤回，留档）

**C.1 错误："`§§constant(N)` 是全局常量池，两个 build 共用，可建一张全局 N→成员名 表。"**

证伪（都在**同一个 build 内**）：

1. `__Packages/Thing/Weapon/CThing_Weapon.as:18` 的 `§§constant(5)` → `mFireRateCount`；
   `__Packages/Thing/Weapon/CThing_Weapon_Pistol.as:17` 的 `§§constant(5)` → `mFireRate`。
2. `__Packages/Thing/Weapon/CThing_Weapon_Grenade.as:23` 的 `§§constant(12)` → `mRange`（值 6）；
   `__Packages/Thing/Weapon/CThing_Weapon_Shotgun.as:44` 的 `§§constant(12)` → `mWideShot`（值 0）。
3. 两个 build 是独立构建，常量池互不相同。

**正确处理**：`§N` 只在**产生它的脚本块内**有意义。现已用 `doc/tools/as2_constpool.py` +
`doc/tools/as2_resolve.py` 为每个文件单独解池，得到 `resolved/` 树。
早期版本附录里那张"全局 N → 成员名"表**已删除**，由 §2.1 的**逐武器池映射表**取代。

**C.2 错误：曾把 `[MoreRooms]` 那份 Shotgun 的第 19 行到第 25 行当作明文构造函数，
用作 Shotgun 字段名的锚点。**

该文件是密文文件（2694 行 / 1232 记号），**它的构造函数并不在明文区** ——
那段区间里实际是状态机噪声（第 19 行原文为
`set("\x01",eval("\x01") + 487);`，第 25 行为一个孤立的 `}`）。
Shotgun 的字段名现在由 2Play **自己的常量池**给出，不再依赖 MoreRooms。

**C.3 错误：基类 `mFireRate` / `mFireRateCount` 写反了。**

早期版本曾写"`CThing_Weapon.as:18` 是 `mFireRate = 0`，`:19` 是 `mFireRateCount = 10`"。
**正确是相反的**：该文件池映射 `§5 = mFireRateCount`、`§6 = mFireRate`，所以

```as2
18:  this.mFireRateCount = 0;
19:  this.mFireRate = 10;
```

（注意：所有**子类**的顺序恰好相反 —— `§5 = mFireRate`、`§8 = mFireRateCount`。
这是本文档最容易读错的一处，已在 §1.2 用警告标出。）

**C.4 错误：Mine 的 `mTotalAmmo` / `mAmmo` 曾写成 20。**

正确值是 **10**。出处 `__Packages/Thing/Weapon/CThing_Weapon_Mine.as:18`：
`this[§§constant(6)] = this[§§constant(7)] = 10;`，池映射 `§6 = mTotalAmmo`、`§7 = mAmmo`。
早期版本的正文出处行写的是 10、而汇总表写成 20，自相矛盾，现已统一为 **10**（见 §2）。
