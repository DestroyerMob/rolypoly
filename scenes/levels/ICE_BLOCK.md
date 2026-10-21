# Ice Block — 冰块关卡

在 Godot 打开 `res://scenes/levels/ice_block.tscn`，运行当前场景（F6，Mac 必要时 Fn+F6）。项目默认入口未更改。不要误开旧的 `ice_block_kitchen.tscn` 或 `ice_cream_delivery.tscn`；本轮保留了这些已有文件中的编辑内容。

## 来源与边界

- 2026-10-16 在 `dev/zhe` 上先后快进合并 `origin/development`（已包含 Ethan / Vika 更新）和 `origin/dev/iroh`，HEAD 为 `df58194`。没有 push。合并前工作完整保存在保留的 stash `4de28b749e4a935bc733425323a2e3bd8284cec0`，已无冲突恢复。
- 现在使用合并后的 `scenes/level_editor/kitchen_interior.tscn`。生成器派生 `ice_block_environment.tscn`，只转换组织节点为 Node3D，使 0.25 缩放正确传递；模型、材质和其他依赖仍引用同学的原文件。旧 `assets/iroh_kitchen` 快照不再用于这个关卡，暂未删除。
- 沿用 Iroh 的餐桌、中岛、水槽、灶台和装饰，不另造厨房。局部灯光强度、范围按房间缩放适配，避免过曝。
- 参考仓库 `runway_level_01` 的错峰双压泥器与分段恢复平台，以及 `hole_two` 的地形 / 跳跃组合；复用现有压泥器、摆勺、下沉盘子和风扇模型。Iroh 提交提到的教学关卡可能在编辑器的 `user://levels/*.json` 中；仓库未找到该布局，不声称复刻了它。
- 玩家源场景为同学的 `player_ice_cream.tscn`。关卡专用 `shell.gd` 继承 Ethan 的冰装备：沿用碰撞、粒子和挂载，改为冰壳厚度显示与渐进补冰；`trail.gd` 复用 Vika 的冰淇淋地面痕迹，但只使用本关的一套生命值，避免双重融化。未修改公共玩家、冰装备、厨房脚本。
- 公共组件合并校验发现长漏斗缺少编辑器已提供的 `channel` 属性；补上与普通漏斗一致的出口频道查找，保留默认出口和手动 NodePath，并增加回归测试。

## 规则

- 外壳常温约 17 秒融完（原 22 秒）；可无限补充。停在补冰站内每秒增加 25%，约 4 秒从空充满，离开保留当前量；不会恢复本体。
- 本体共有 3 格连续生命值，没有冰壳时才逐渐融化。归零失败。
- 主线：餐桌补冰 → 上坡 / 错峰双压泥器 → 中岛补冰 → 热风捷径或冷绕行路 → 水槽补冰 → 摆勺 + 下沉盘子 → 台面补冰 → 抬高转弯 / 旋转擀面杖桥 → 第五补冰点 → 回转路 / 间歇加热板 → 定时弹射 → 移动大嘴。
- 掉落或 R 返回最后补冰站，保留已损失的本体生命；因此不能靠重生刷回三星。
- 掉下或被压会回到最后补冰站；冰壳仍需逐步充能，不会重生瞬间送满。
- 到最后弹簧盘上，等绿色提示再按 E：压缩蓄力 0.6 秒，向固定中心航线以真实抛物线发射。绿色提示考虑蓄力与飞行时间，但不会自动瞄准移动的嘴巴。时机错误会错过开口，随后返回最后补冰站。R 可安全取消蓄力。Space 始终只负责普通跳跃。
- 评分只看本体：剩余 > 2 格为 3 星，> 1 格且 ≤ 2 格为 2 星，> 0 且 ≤ 1 格为 1 星。外壳、耗时和收集物不计分。
- 结算后 Enter 开始全新一局。

## 组合机关的玩法

1. **两台压泥器 + 中间停步区**：两台错开 2.4 秒，不能把整条坡当作一次直冲。先过第一台，在薄荷色标记处刹住，再判断第二台。路线宽 10，冰块碰撞宽 4.4，保留调整余地。
2. **热托盘 + 预警阵风 + 冷绕行路**：直路短，但接触热面耗冰更快，阵风会侧推冰壳。风扇先预警 0.8 秒再吹，叶片与风线同步反馈；在平坦入口等风，不能在热盘上等。另一条带平坦转角的侧路更长，但不经过热面和风区。两路都接到同一个补冰站，不需要猜路线。
3. **下沉盘子 + 摆勺**：取消水槽上的实心通路。观察摆勺后，从岸边跳到第一盘、斜跳第二盘、再跳上岸；踩住盘子会下沉，离开会浮回。不能在盘子上无限等待摆勺。入水返回水槽补冰站。原厨房内的装饰盘碰撞仅在本关禁用，避免藏在水下的平台影响玩法。
4. **抬高转弯 + 旋转擀面杖桥**：原来的直通长坡改为绕回路线。先爬升再左转，穿过持续 48°/秒旋转的擀面杖。实际圆柱碰撞承载玩家，站着不调整会被带偏；条纹帮助判断旋转。跌落返回第四补冰点，该站放在平面上，重生后不会从斜坡滑走。
5. **间歇加热板 + 最后补冰规划**：过桥后第五站可以重新补满冰，再沿回转路到加热板。红色发热 2.2 秒、绿色冷却、黄色提前 0.6 秒预警；在木板处观察后通过。冷却时仅常温融化，发热时连续接触 3.5 秒消耗一层冰。所有发热条纹同步变色，碰撞与坡面齐平。
6. **移动嘴巴定时投送**：最后选择绿色窗口按 E。不是按 E 必中，也不靠普通跳跃硬跳进嘴。错过后返回第五补冰点。

机关失败点附近保留补冰 / 重生点；难度来自观察、刹车、跳跃与路线取舍，不是无预警秒杀或极窄道路。

## 操作

WASD 移动，Space 跳跃，E 在弹射台发射，方向键上下左右转动视角，R 返回补冰点。

C 恢复该段默认朝向 / 俯角，V 切换较高较远的路线俯瞰。补冰点会平滑提示下一段朝向，手动按左右方向键可打断自动转向。跟随镜头带墙体遮挡检测。

Tab 切换自由观察并暂停游戏和融化；自由观察下 WASD 飞行、Q/E 升降、方向键转向，再按 Tab 返回。

## 可调参数与独立资产

- 根节点：`shell_lifetime` 默认 17 秒，`refill_seconds` 默认 4 秒。
- `PlayerRig/Player`：`naked_melt_seconds` 默认裸露 24 秒融完 3 格（原 30 秒）；`maximum_speed`。
- `Course/TimingMasher` / `SecondMasher`：`wait_time` 2.6 秒、`hold_time` 0.65 秒、`drop_speed`；第二台 `phase_offset` 2.4 秒。
- `Course/SinkSweeper`：`swing_angle_degrees` 85°，`swing_period` 8 秒。已测试连续跳盘存在可用窗口，错误时机会被打断。
- `Course/SinkingPlateA` / `SinkingPlateB`：`sink_depth` 2、`sink_speed` 0.75、`return_speed` 1.15。
- `Course/HotTrayFan/EffectZone`：`period` 6 秒、`calm_seconds` 3 秒、`warning_seconds` 0.8 秒、`strength` 24。
- `Course/SpringServer`：`charge_seconds` 默认 0.6 秒，`flight_seconds` 默认 1.05 秒。
- `Course/MovingMouth`：`sweep_distance`、`cycle_seconds`、`opening_half_size`。
- `Course/WarmTray`：`ice_melt_seconds`，连续接触 4 秒融完一层壳（原 5 秒）。
- `Course/CounterRoller`：`rotation_speed_degrees` 48°/秒，复用现有 `rolling_pin_spinner.tscn` 和条纹模型。
- `Course/TimedHotplate/WalkableBoard`：`period` 5.5 秒、`hot_seconds` 2.2 秒、`warning_seconds` 0.6 秒、`ice_melt_seconds` 3.5 秒。新增脚本 `scripts/ice_delivery/timed_hotplate.gd`。
- 独立组件：`scenes/obstacles/moving_mouth_goal.tscn`、`ice_block_spring_server.tscn`、`ice_block_shell.tscn`。嘴沿由一个 AnimatableBody3D 整体带动，避免子碰撞体与视觉位置脱节。
- Blender 源文件：`models/ice_delivery/moving_mouth.blend`、`spring_server.blend`；Godot 模型：同目录 `.glb`。
- 重建模型：`tools/blender/build_delivery_mouth.py` / `build_spring_server.py`。重建关卡：`tools/build_ice_block.gd`（会覆盖本关及派生组件，手动调整后不要随意重跑）。

## 手动验证

自动测试脚本已移除。请在 Godot 中运行本关，检查路线、机关、补冰、复活和终点投掷，并由小组手动试玩来调整节奏和美术细节。
