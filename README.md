# iT-BATTLE：值班幸存者

[![Godot 4.7.1](https://img.shields.io/badge/Godot-4.7.1-478CBF?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Build and Release](https://github.com/Eleven-CZ/Operation-Surviver-Battle/actions/workflows/release.yml/badge.svg)](https://github.com/Eleven-CZ/Operation-Surviver-Battle/actions/workflows/release.yml)

一款支持 Windows、macOS、Android 与 iOS 的高俯视 2D Survivor-like 游戏，把线上事故、职业技能和办公室黑话做成战斗机制。进入值班大厅，选择 10 种 IT 职业之一，在六分钟事故班次中清理故障、处理发布、拉同事进 War Room，并把复盘收益投入永久成长。

![iT-BATTLE 战斗画面](docs/screenshots/combat_showcase.png)

当前版本已形成“值班大厅 → 选择职业 → 六分钟事故班次 → RP / 履历结算 → 职业挑战与永久成长”的完整循环，使用 Godot 4.7.1 开发，并已把战情室、职业角色、故障单位、同事投影、技能图标与 HUD 素材接入实机。

## 多端支持

| 平台 | 自动构建产物 | 安装状态 |
| --- | --- | --- |
| Windows x86_64 | `iT-BATTLE-Windows-x86_64.zip` | 解压即玩 |
| macOS universal | `iT-BATTLE-macOS-universal.zip` | 未公证，首次启动需手动确认 |
| Android ARMv7 / ARM64 | `iT-BATTLE-Android-universal.apk` | 已使用 CI 临时调试证书签名，可直接侧载 |
| iOS / iPadOS 15+ | `iT-BATTLE-iOS-Xcode-project.zip`、`iT-BATTLE-iOS-unsigned-app.zip` | CI 可完成未签名编译；真机安装仍需在 Xcode 中自签 |

移动端采用横屏布局：左下虚拟摇杆移动，点击底栏两侧使用职业小技能与大招，右下按住“对齐”完成协作验收，右上按钮暂停。菜单、三选一和设置页面均可直接触控。

## 下载与安装

前往 [Releases](https://github.com/Eleven-CZ/Operation-Surviver-Battle/releases) 下载最新版本：

- Windows：解压 `iT-BATTLE-Windows-x86_64.zip`，运行 `iT-BATTLE.exe`。
- macOS：解压 `iT-BATTLE-macOS-universal.zip`，运行 `iT-BATTLE.app`。当前自动构建未使用 Apple Developer ID 签名；如果被 Gatekeeper 拦截，请在“系统设置 → 隐私与安全性”中确认打开。
- Android：下载 `iT-BATTLE-Android-universal.apk`，在系统提示时允许浏览器或文件管理器“安装未知应用”，然后打开 APK 安装。不需要 Google Play 开发者账号。当前工作流每次运行都会生成临时调试签名；如果覆盖安装时报“签名不一致”，请先卸载旧版本再安装，新旧签名之间不能直接升级，卸载会清除本机存档。

### 没有付费 Apple 开发者账号时安装 iOS 版

iPhone 和 iPad 不允许直接安装 GitHub Actions 生成的未签名 App，所以 `iT-BATTLE-iOS-unsigned-app.zip` 不能直接装到未越狱设备。无需加入付费 Apple Developer Program，但需要一台 Mac、最新版 Xcode、普通 Apple ID 和数据线或已配对的无线调试：

1. 下载并解压 `iT-BATTLE-iOS-Xcode-project.zip`，打开其中的 `iT-BATTLE.xcodeproj`。
2. 用 Apple ID 登录 Xcode，在项目 Target 的 `Signing & Capabilities` 中启用 `Automatically manage signing`，并选择自己的 `Personal Team`。
3. 如果 Xcode 提示 Bundle Identifier 已被占用，将 `com.elevencz.itbattle` 改成个人唯一值，例如 `com.yourname.itbattle`。
4. 连接并解锁 iPhone / iPad；iOS 16 及以上还需在“设置 → 隐私与安全性 → 开发者模式”中启用开发者模式。
5. 在 Xcode 顶部选择设备，点击 Run。首次打开时如有提示，再到设备的“VPN 与设备管理”中信任对应开发者。

免费 Personal Team 安装通常约 7 天后失效，需要重新连接 Xcode 构建；Apple 对免费签名的设备数和 App 数也有限制。没有 Mac 时，官方支持的真机分发只能使用付费开发者账号配合 TestFlight、Ad Hoc 或 App Store。

## 本地运行

桌面运行要求 [Godot 4.7.1 Standard](https://godotengine.org/download/)；项目不需要额外插件或第三方依赖。本地导出 Android 还需要 JDK 与 Android SDK，本地导出或安装 iOS 真机版需要 macOS 与 Xcode。

直接开始游戏：

```bash
godot --path .
```

用编辑器打开：

```bash
godot --editor --path .
```

完整流程自动冒烟测试（约 1 秒跑完 6 分钟时间轴）：

```bash
godot \
  --headless \
  --path . \
  --fixed-fps 60 \
  --time-scale 60 \
  --quit-after 1200 \
  -- \
  --smoke-test
```

成功时会输出 `SMOKE_TEST_PASS`，并验证升级、发布、压力投影转盟友、Boss 根因暴露和恢复验证。

压测场景：

```bash
godot \
  --path . \
  --editor res://scenes/benchmark.tscn
```

## 操作

- `WASD` / 方向键 / 左摇杆：移动
- `Q` 或 `Space` / 手柄 X / 点击底栏左侧：职业小技能
- `R` / 手柄 Y / 点击底栏右侧：职业大招
- `E` / 手柄 A：对齐压力投影的验收标准
- `Esc` / 手柄 Start：暂停 / 继续，打开值班菜单
- 手机 / 平板：左下虚拟摇杆移动；点击小技能和大招；右下按住对齐；右上暂停
- `P`：立即触发线上发布（开发快捷键）
- `O`：立即生成 OOM 137 精英
- `B`：立即生成 Incident Core Boss
- `T`：时间前进 30 秒
- `F3`：显示性能信息
- `U`：立即获得一次升级选择（开发快捷键，用来快速测试叠层）

压测场景中使用 `F1 / F2 / F3 / F4` 切换 200 / 500 / 1000 / 2000 个单位，`L` 切换故障标签。

## 当前可玩循环

- 默认启动进入值班大厅；职业档案、值班简报、能力基线商店和设置均可用键鼠或手柄焦点操作。
- 四档纵向难度：普通、高级、深渊、这不可能。必须依次通关解锁；首页作弊码 `yesifu` 会同时解锁全部职业与全部难度。
- 难度同时影响开场数量、持续出怪、敌人上限、普通/精英/Boss 的生命伤害速度、精英编队、技能频率、事件波次、Boss 分诊和恢复验证；“这不可能”可容纳 2000 个敌人、整局约 84 只精英与 25,600 HP 的事故核心。
- 10 个可选职业：运维工程师、DBA、网络工程师、安全运维、IT 运维、Helpdesk、运维开发、SRE、实施交付、AI Infra。
- 每个职业拥有不占构筑槽的独立固有攻击、短 CD 小技能、长 CD 大招，以及属性曲线、压力投影效率、像素轮廓和岗位专精选项。
- 每个职业还有常驻 HUD 的独立协议：跨域联动、事务 COMMIT、链路收敛、自动隔离、现场处置、SLA 批次、幂等重试、错误预算、验收里程碑或 KV Cache；这些协议均有实际触发效果，不是说明文字。
- AI 生成的十职业像素徽记同时用于职业档案、值班大厅与战斗 HUD；运行时从统一 5×2 图集裁切，避免重复纹理。
- 局内三选一从当前全部合格卡牌中等概率、无放回抽取，不再强制塞入固有普攻、岗位专精或推荐架构；每次构筑都可能走向不同路线。
- 复盘点 `RP` 来自遥测闭环、精英故障、War Room 协作、发布窗口、岗位协议执行和恢复验证；失败也有最低复盘保底。
- 直接全量发布成功会获得额外高风险变更奖励；同一个 `run_id` 只能结算一次。
- 职业通过公开的局内挑战横向解锁，不花 RP；RP 只投入容量、遥测、重新评审和移动动线四类永久能力。
- 职业履历形成五级职级：见习观察、独立值班、主值班、领域专家、事故指挥；晋升会在结算与职业档案中持续显示。
- 存档位于 `user://profile_v1.json`；自动测试模式不会污染正式存档。
- 结算页展示奖励明细、职业履历、新职业解锁，并提供再来一局、更换职业、返回大厅三个出口。

## 战斗与流派范围

- 普通怪：`404`、`NXDOMAIN`、`ENOSPC`、`BUG`、`408`；只有 BUG 有腿。
- 精英：`502 UPSTREAM`、`OOM 137`。
- Boss：`FATAL / INCIDENT CORE`，固定 `UPSTREAM` 根因。
- 底栏中央是固有攻击 + 4 个常规构筑槽；左侧为职业小技能及 CD，右侧为职业大招及 CD。两个主动槽也可直接点击，方便触屏与手柄。
- 通用 Bash、Ping、日志、扳手等不再决定职业身份，只作为后续四槽构筑；职业固有攻击始终保留。

| 职业 | 固有攻击 | 小技能（CD） | 大招（CD） |
| --- | --- | --- | --- |
| 运维工程师 | 终端重击：近战三连，第三击 sudo 震地 | 抢修突进（6s） | P1 一级响应（46s） |
| DBA | 慢查询锁域：延迟阵地、持续减速伤害 | ROLLBACK（12s） | 全库事务 COMMIT（50s） |
| 网络工程师 | ICMP 探针：640px 多目标贯穿 | 抓包：区内总攻击 +15%（14s） | 网络风暴：大范围多段 AOE（48s） |
| 安全运维 | 零信任防火墙：持续线性范围墙 | 隔离通道（11s） | 全域封禁：六边形控制区（52s） |
| IT 运维 | 备件节点：可修复服务并周期放电 | 整机热插拔（10s） | 机房总控（54s） |
| Helpdesk | 工单分派：多目标自动弹跳 | 远程协助（12s） | SLA 绿色通道（49s） |
| 运维开发 | 幂等脚本：命中位置重复执行 | CI Runner（10s） | 全量 IaC Apply（51s） |
| SRE | 关键路径 Trace：高伤害采样、SPAN 留痕、折线反向回滚并重击根因 | 流量切换：高伤害主备站数据链路（10s） | 全站多活：历史容灾站并发 Trace（58s） |
| 实施交付 | 发布包：延迟 AOE + UAT 验收区 | 跨组联调：默认独立储备 2 次、轮换召集职业剪影（每层 10s） | 全员到场：十职业固有普攻 ×3（58s） |
| AI Infra | Tensor Pipeline：双 Token 四阶段推理、击杀后残差转交 | Pipeline Flush：三通道四阶段贯穿（10s） | 基础模型上线：Prefill / Decode / EOS 全屏推理（60s） |

- 进化：Bash Lv.3 + 幂等性 → 基础设施即代码。
- Lv.3 / Lv.7 触发“岗位架构”三选一，可选择现场值守、零信任边界、查询治理或弹性训练集群；同一架构可叠至 II 阶，也可混合两条路线。
- 升级界面使用横向三张大卡，显示稀有度、岗位、攻击几何、协同提示、槽位状态，并提供每局 2 次重新评审。
- 职业固有普攻的伤害、频率、范围和并发均可无限叠加；范围升级会按各职业真实攻击几何同步放大碰撞与预览特效。
- 通用成长加入移动速度、职业小技能 CD 和大招 CD，采用有安全下限的无限渐近曲线；升级卡直接显示前后实际数值。
- 实施交付拥有三张岗位主动专精卡：`联调排期` 将 Q 独立储备从 2 提升至最多 4 次，`并行会签` 将单次到场剪影从 1 提升至最多 4 位，`发布燃尽` 共 5 阶，使 Q 击杀削减 R 0.12–0.36 秒，并将单次 Q 总削减限制在 1.2–3.6 秒。
- 精英有 50% / 40% / 30% / 20%（普通至“这不可能”）概率掉落神器；每局最多装备 2 件。当前包含 `RM -RF`、`DELETE * FROM incidents`、重装系统、重启设备、删库跑路、`kill -9`、回滚上一版、`sudo !!` 等 12 件运维梗神器。每件神器拥有独立生成图标，掉落时通过三窗协议老虎机滚动揭晓，最终停在实际掉落结果上。
- 主菜单加入故障博物馆，分为小怪与精英、Boss、神器三类；故障和 Boss 在实际遭遇后解锁，神器在拾取安装后解锁，发现状态写入个人档案长期保存。
- 可见叠层：Bash 增加并发光束，Ping 增加回波，防火墙增加常驻规则环，日志采集增加并行落点；iptables 规则链前五阶每次都会增加环绕节点，并同步扩大轨道与单节点碰撞范围。
- 方法论同样可以叠加：Runbook、容量规划、冗余设计与幂等性均有明确层数和上限。
- 四类事件合同：线上发布、版本更新、线上救火、备份恢复演练；每类事件都有 3 个风险 / 收益不同的处置策略和独立目标。
- 同事采用“压力投影，解决后变盟友”：线上发布对应产品经理、版本更新对应后端开发、线上救火对应客户、备份恢复对应财务；解除压力外壳并完成标准对齐后加入 War Room。
- 事件会进入结构化结算，记录策略、成功 / 部分成功 / 失败、风险奖励和岗位加成；测试模式不会发放奖励或污染正式档案。

## AI 像素视觉资产

- `arena_war_room_v2.png`：2400×1350 战斗空间使用的高俯视暗色服务器战情室。
- `career_sprites_5x2.png`：10 个职业角色，职业档案、战斗角色和 HUD 共用同一图集。
- `fault_sprites_4x2.png`：404、NXDOMAIN、ENOSPC、BUG、408，以及 502、OOM 137 和 FATAL Boss。
- `coworker_sprites_4x2.png`：HR、财务、产品、前后端、领导、客户和主管压力投影 / 盟友角色。
- `skill_icons_5x2.png`：Bash、Ping、防火墙、日志、扳手、规则链、锁域、Worker、Runbook 和冗余技能图标。
- `artifacts/*.png`：12 件神器独立的 256×256 像素科技卡图标，用于地面掉落、HUD、老虎机与博物馆。
- `combat_hud_overlay.png`：生命 / 经验框、Boss 警报、雷达、事件框、同事状态条和五槽技能托盘的像素装饰层；实际数值与交互仍由 Godot 原生控件驱动。

所有最终图、生成提示词、原始来源路径、请求编号和 SHA-256 都登记在 `ASSET_LICENSES.csv`。游戏运行时只引用 `res://assets/generated/` 下的最终资产。

本轮实机验收图保存在 `docs/screenshots/`：除战斗层级、职业档案和两类三选一外，还包含运维近战、网络抓包 / 风暴、安全范围墙 / 封禁三张职业动作图，均由 Godot 运行时直接截取。

## 原创动态音频

- `assets/audio/bgm/user/bgm01.ogg` 现为默认背景音乐并覆盖大厅、常规战斗、特殊事件、FATAL Boss、恢复验证；`BGM02`、`Maximum Breach`、`Terminal Overwrite`、`Unauthorized Entry` 也以 OGG 放入同一目录。程序合成的“脉冲值班”和原“夜班氛围”都完整保留，均可运行时循环并以 1.15–1.8 秒动态交叉淡入淡出。
- 44 个战斗音效：八类工具、十职业固有攻击 / 小技能 / 大招、精英词条预警与落地、Boss 登场 / 阶段 / 关闭、玩家受伤。
- 固定 8 个普通声道与 4 个空间声道；按整次施放聚合、按音效节流，不会随弹体或敌人数无限叠加。
- 设置界面可分别调整主音量、背景音乐、战斗与界面音效，并可即时切换五首用户 BGM、脉冲值班与夜班氛围。
- 程序合成音乐与音效不含第三方采样；用户导入 BGM 的来源与运行时转码记录见 `ASSET_LICENSES.csv`，完整说明见 `docs/AUDIO_SYSTEM.md`。

## 自动验证

```bash
godot --headless --path . --log-file /tmp/profile.log --script res://tests/profile_store_test.gd -- --profile-test
godot --headless --path . --log-file /tmp/career.log --script res://tests/career_runtime_test.gd -- --career-runtime-test
godot --headless --path . --log-file /tmp/career-actions.log --script res://tests/career_actions_test.gd -- --career-actions-test
godot --headless --path . --log-file /tmp/menu.log --script res://tests/menu_flow_test.gd -- --menu-test
godot --headless --path . --log-file /tmp/event-runtime.log --script res://tests/event_runtime_test.gd -- --event-runtime-test
godot --headless --path . --log-file /tmp/event-hud.log --script res://tests/event_hud_test.gd -- --event-hud-test
godot --headless --path . --log-file /tmp/visual-assets.log --script res://tests/visual_assets_test.gd -- --visual-assets-test
godot --headless --path . --log-file /tmp/difficulty.log --script res://tests/difficulty_system_test.gd -- --difficulty-test
godot --headless --path . --log-file /tmp/audio-system.log --script res://tests/audio_system_test.gd -- --audio-test
godot --headless --path . --log-file /tmp/growth.log --script res://tests/growth_and_elite_loot_test.gd -- --growth-elite-loot-test
godot --headless --path . --log-file /tmp/meta-growth.log --script res://tests/meta_growth_runtime_test.gd -- --meta-growth-test
godot --headless --path . --log-file /tmp/artifact.log --script res://tests/artifact_system_test.gd -- --artifact-system-test
godot --headless --path . --log-file /tmp/ally-support.log --script res://tests/ally_support_system_test.gd -- --ally-support-test
godot --headless --path . --log-file /tmp/mobile-controls.log --script res://tests/mobile_controls_test.gd -- --mobile-controls
```

十四项分别验证奖励幂等与阶梯解锁、10 职业协议、10 套固有攻击 / 小技能 / 大招与 CD、全池随机三选一、无限成长、移动与 CD 安全曲线、普攻范围实机预览、精英大水晶、两槽神器与四档掉率、主菜单与暂停流程、4 个事件 / 12 个策略、事件 HUD、全部生成素材、四档难度、完整动态音频和固定声道限流，以及移动端虚拟摇杆、触屏对齐与暂停入口。

## 自动构建与发布

`.github/workflows/release.yml` 使用 GitHub Actions 在 Windows、macOS 与 Linux runner 上并行导出四个平台。推送形如 `v0.1.0` 的标签后，工作流会自动：

1. 安装 Godot 4.7.1 和对应导出模板。
2. 导出 Windows x86_64 与 macOS universal 构建。
3. 导出 Android ARMv7 / ARM64 APK，并用无需开发者账号的临时 CI 证书完成对齐、签名与校验。
4. 在 macOS runner 上导出 iOS Xcode 工程，并用关闭代码签名的 `xcodebuild` 完成真机 Debug App 编译。
5. 上传桌面 ZIP、可安装 Android APK、iOS Xcode 工程和未签名 iOS App。
6. 创建 GitHub Release、自动生成更新说明并附上全部平台产物。

发布新版本：

```bash
git tag v0.1.0
git push origin v0.1.0
```

也可以在 GitHub Actions 页面手动运行工作流，只生成并保存四个平台的构建产物；手动运行不会创建正式 Release。由于 Android 默认使用每次运行临时生成的调试签名，正式长期分发时建议再配置一把固定 keystore；iOS 正式分发则必须配置 Apple Developer Program 证书和 provisioning profile。
