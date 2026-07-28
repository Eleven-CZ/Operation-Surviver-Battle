# iT-BATTLE 音频系统

本项目的两套内置音乐与全部战斗音效由 `tools/generate_audio_assets.py` 确定性程序合成，不使用第三方采样；另有五首用户提供的 BGM 以 OGG 转码后接入运行时。程序合成音源只有正弦波、三角波、脉冲波、轻量 FM、确定性噪声和包络，因此可以安全重建，也与像素电子美术保持统一。

## 动态 BGM

默认背景音乐为用户导入并转码后的 `assets/audio/bgm/user/bgm01.ogg`。另有 `BGM02`、`Maximum Breach`、`Terminal Overwrite`、`Unauthorized Entry` 四首用户曲；程序合成的“脉冲值班”和原先的“夜班氛围”也都完整保留，可在设置菜单中即时切换。原始 MP3 仅归档在 Godot 忽略的 `assets/audio/source/`，不参与运行时播放。

| 曲风 | 上下文曲目 |
|---|---|
| `BGM01`（默认） | 所有背景音乐上下文使用 `res://assets/audio/bgm/user/bgm01.ogg`，运行时循环。|
| `BGM02` | 所有背景音乐上下文使用 `res://assets/audio/bgm/user/bgm02.ogg`，运行时循环。|
| `Maximum Breach` | 所有背景音乐上下文使用 `res://assets/audio/bgm/user/maximum_breach.ogg`，运行时循环。|
| `Terminal Overwrite` | 所有背景音乐上下文使用 `res://assets/audio/bgm/user/terminal_overwrite.ogg`，运行时循环。|
| `Unauthorized Entry` | 所有背景音乐上下文使用 `res://assets/audio/bgm/user/unauthorized_entry.ogg`，运行时循环。|
| 脉冲值班 | 108 / 124 / 128 / 132 / 106 BPM 的大厅、战斗、事件、Boss、恢复五曲。|
| 夜班氛围（原版） | 94 / 112 / 120 / 126 / 92 BPM 的原始五曲。|

两台 `AudioStreamPlayer` 使用等功率淡入淡出。升级、事件选择等暂停界面会自动将音乐降低 3 dB；大招、Boss 登场与阶段切换会短暂 duck 2.5–5 dB，保证预警音清晰。

## 战斗音效

- 八类局内工具各有聚合施放音，按照一次攻击而不是命中数量播放。
- 十个职业的固有攻击、小技能和大招按照动作 ID 映射到职业音色。
- 熔火、冻结、瞬移、雷暴、自爆和护盾拥有互相可辨认的预警音。
- 危险区仅在首次生效时播放冲击音；火焰地板的持续伤害 Tick 不重复发声。
- Boss 拥有登场、根因暴露、阶段变化和关闭四组独立长音效。
- 玩家受伤音最短间隔为 0.34 秒，不会与无敌帧重复轰鸣。

运行时只创建固定的 `8` 个普通声道和 `4` 个空间声道。相同攻击有独立的 0.10–0.22 秒节流；普通声音无空闲声道时会被丢弃，Boss 与大招可以抢占低优先级声音。

## 混音与设置

`default_bus_layout.tres` 提供 `Master / Music / SFX / UI` 四条总线。设置界面可以分别调整主音量、背景音乐、战斗与界面音效，并在五首用户曲、脉冲值班、夜班氛围之间即时切换；旧存档会迁移到 `BGM01` 默认值。

五首导入曲根据各自综合响度在播放端衰减 `5–7 dB`，使背景音乐不会盖住故障预警与 Boss 提示。程序合成音乐在 10.8 kHz 以上做低通，为长时间游玩和故障预警保留听觉空间。

## 重新生成

```bash
python3 tools/generate_audio_assets.py --all
# 只生成“脉冲值班”五首新增 BGM
python3 tools/generate_audio_assets.py --pulse-bgm
```

脚本使用固定随机种子生成两套、共十首 OGG 和四十四个 WAV。五首用户导入曲也以 OGG 放入 `assets/audio/bgm/user/`，不会被脚本覆盖；原 MP3 仅保留于被 Godot 忽略的源文件归档目录；生成后由 Godot 导入即可。

## 验证

```bash
Godot --headless --path /Users/ye/code/iT-BATTLE \
  --log-file /tmp/audio-system.log \
  --script res://tests/audio_system_test.gd -- --audio-test
```

测试覆盖七种音乐风格的五种上下文、运行时曲风切换、四条音频总线、独立音量、攻击与职业动作接线、Boss 登场仅播放一次，以及一千次攻击请求下的固定声道与节流。
