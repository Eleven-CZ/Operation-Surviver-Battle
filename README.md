# iT-BATTLE：值班幸存者

Godot 4.7.1 的高俯视 2D Survivor-like 可玩原型。当前版本已经形成“值班大厅 → 选择职业 → 六分钟事故班次 → RP / 履历结算 → 职业挑战与永久成长”的完整循环，并已把 AI 生成的战情室、职业角色、故障单位、同事投影、技能图标与 HUD 素材接入实机。

## 运行

直接开始游戏：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ye/code/iT-BATTLE
```

用编辑器打开：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/ye/code/iT-BATTLE
```

完整流程自动冒烟测试（约 1 秒跑完 6 分钟时间轴）：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/ye/code/iT-BATTLE \
  --fixed-fps 60 \
  --time-scale 60 \
  --quit-after 1200 \
  -- \
  --smoke-test
```

成功时会输出 `SMOKE_TEST_PASS`，并验证升级、发布、压力投影转盟友、Boss 根因暴露和恢复验证。

压测场景：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path /Users/ye/code/iT-BATTLE \
  --editor res://scenes/benchmark.tscn
```

## 操作

- `WASD` / 方向键 / 左摇杆：移动
- `Q` 或 `Space` / 手柄 X / 点击底栏左侧：职业小技能
- `R` / 手柄 Y / 点击底栏右侧：职业大招
- `E` / 手柄 A：对齐压力投影的验收标准
- `Esc` / 手柄 Start：暂停 / 继续，打开值班菜单
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
- 每个职业还有常驻 HUD 的独立协议：跨域联动、事务 COMMIT、链路收敛、自动隔离、现场处置、SLA 批次、幂等重试、错误预算、验收里程碑或自动扩缩容；这些协议均有实际触发效果，不是说明文字。
- AI 生成的十职业像素徽记同时用于职业档案、值班大厅与战斗 HUD；运行时从统一 5×2 图集裁切，避免重复纹理。
- 岗位专精会稳定出现在局内三选一中；Lv.3 / Lv.7 的架构选择也会保证出现该职业的推荐架构，同时允许跨职业构筑。
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
| SRE | SLO 预算环：按健康度切换伤害 / 恢复 | 流量切换（11s） | 错误预算冻结（56s） |
| 实施交付 | 发布包：延迟 AOE + UAT 验收区 | 蓝绿切换（12s） | 全量上线：三阶段扩张（52s） |
| AI Infra | Worker Pod：自主编队独立齐射 | Pod 迁移（11s） | GPU 集群扩容（55s） |

- 进化：Bash Lv.3 + 幂等性 → 基础设施即代码。
- Lv.3 / Lv.7 触发“岗位架构”三选一，可选择现场值守、零信任边界、查询治理或弹性训练集群；同一架构可叠至 II 阶，也可混合两条路线。
- 升级界面使用横向三张大卡，显示稀有度、岗位、攻击几何、协同提示、槽位状态，并提供每局 2 次重新评审。
- 升级采用叠层制：每次选择会同时强化伤害、频率、范围和并发中的多个维度；升级卡直接显示前后数值。
- 可见叠层：Bash 增加并发光束，Ping 增加回波，防火墙增加常驻规则环，日志采集增加并行落点。
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
- `combat_hud_overlay.png`：生命 / 经验框、Boss 警报、雷达、事件框、同事状态条和五槽技能托盘的像素装饰层；实际数值与交互仍由 Godot 原生控件驱动。

所有最终图、生成提示词、原始来源路径、请求编号和 SHA-256 都登记在 `ASSET_LICENSES.csv`。游戏运行时只引用 `res://assets/generated/` 下的最终资产。

本轮实机验收图保存在 `docs/screenshots/`：除战斗层级、职业档案和两类三选一外，还包含运维近战、网络抓包 / 风暴、安全范围墙 / 封禁三张职业动作图，均由 Godot 运行时直接截取。

## 自动验证

```bash
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/profile.log --script res://tests/profile_store_test.gd -- --profile-test
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/career.log --script res://tests/career_runtime_test.gd -- --career-runtime-test
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/career-actions.log --script res://tests/career_actions_test.gd -- --career-actions-test
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/menu.log --script res://tests/menu_flow_test.gd -- --menu-test
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/event-runtime.log --script res://tests/event_runtime_test.gd -- --event-runtime-test
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/event-hud.log --script res://tests/event_hud_test.gd -- --event-hud-test
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/visual-assets.log --script res://tests/visual_assets_test.gd -- --visual-assets-test
Godot --headless --path /Users/ye/code/iT-BATTLE --log-file /tmp/difficulty.log --script res://tests/difficulty_system_test.gd -- --difficulty-test
```

八项分别验证奖励幂等与阶梯解锁、10 职业协议、10 套固有攻击 / 小技能 / 大招与 CD、主菜单与暂停流程、4 个事件 / 12 个策略、事件三选一 HUD、全部生成素材，以及四档难度的出怪/精英/Boss/2000 敌人上限。
