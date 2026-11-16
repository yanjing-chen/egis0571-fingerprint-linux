# EgisTec 1c7a:0571 触摸指纹驱动修复（Ubuntu 26.10 / GNOME 51）

让一颗被上游**错误识别为滑动式**的 EgisTec/LighTuning **触摸式**指纹传感器，在 Linux 上完整工作：录入、验证、sudo 认证、锁屏、登录界面。

> 实测环境：Ubuntu 26.10（Stonking Stingray）、GNOME Shell 51.0、GDM 51.0、fprintd 1.94.5、OpenCV 4.10。
> 这是社区补丁 + 本机参数标定的成果，**不是厂商官方驱动**。指纹是便利认证，请始终保留密码作为后备。

---

## 目录

- [症状与根因](#症状与根因)
- [修复方案](#修复方案)
- [匹配参数是怎么标定出来的](#匹配参数是怎么标定出来的)
- [快速安装](#快速安装)
- [完整配置：从录入到登录](#完整配置从录入到登录)
- [重要注意点](#重要注意点)
- [排障](#排障)
- [关于蓝灯](#关于蓝灯)
- [外挂 vs 改核心库](#外挂-vs-改核心库)
- [文件说明](#文件说明)
- [回滚](#回滚)
- [致谢与许可](#致谢与许可)

---

## 症状与根因

设备 USB ID 为 `1c7a:0571`，Windows 下正常（触摸式、工作蓝灯亮）；Linux 下能录入，但验证永远失败，老版本 Ubuntu 甚至提示"滑动手指"。

根因有两层：

1. **驱动类型错了**：上游 libfprint 的 `egis0570` 驱动 ID 表里同时含 `0570`/`0571`，却把 `scan_type` 写死为 `FP_SCAN_TYPE_SWIPE`（滑动式）。用滑动驱动去读触摸硬件，采集方式根本不对。
2. **匹配参数失效**：社区触摸补丁（`egis0570touch`）的匹配参数继承自 `0570` + OpenCV 5。直接套到 `0571` + OpenCV 4.10 上，SIFT 匹配完全失准。

顺带说明：厂商 Windows 驱动包是微软 **WBDI 模板**（INF 里是 `VID_2541&PID_9711` 加 TODO 注释），没有可用的 Linux 协议信息，未采用。

## 修复方案

基于社区 [`keno2003/libfprint-egis0570`](https://github.com/keno2003/libfprint-egis0570) 触摸驱动补丁，做了两类修改：

**硬件适配**

- USB ID `0570` → `0571`，驱动标识改为 `egis0571touch`
- `scan_type = PRESS`（触摸式，不再是滑动）

**匹配参数调优**（针对 0571 + OpenCV 4.10，经多轮真实数据标定）

| 参数 | 社区原值 | 最终值 | 依据 |
|---|---|---|---|
| Lowe ratio | 0.70 | 0.82 | 0.70 下匹配存活数近乎为 0；0.82 下每模板 15~50 个 |
| RANSAC 重投影阈值 | 3.0 | 5.0 | 放大 2 倍的图像上允许合理形变 |
| 评分函数 | `MIN(fwd,rev)` | `MAX(fwd,rev)` | probe 特征点远多于模板，匹配方向不对称，MIN 丢弃了真实匹配（实测 fwd=6、rev=10） |
| 匹配阈值 | 12 | 8 | 正确模板得分 9~10，错误模板 ≤7，阈值 8 正好落在分界点 |

产物是一个编译好的 `libfprint-2.so.2.0.0-final`，替换系统同名库。最终 SHA256：

```
e880a6e7a8073f92af98963dda0571eb4d90f75464874099e55933adbaca55d1
```

## 匹配参数是怎么标定出来的

这段记录调优过程，方便以后换硬件/换 OpenCV 版本时重新标定。

1. **先排除采集问题**：确认录入 12 个阶段全过、特征点充足（extract keypoints 1300+），问题在匹配而非采集。
2. **用独立 SIFT 测试**确认 OpenCV 4.10 的描述符值域正常（0~145，非二值化），排除序列化截断假设。
3. **加诊断日志**（`[EGIS-DIAG]` + ratio 直方图）统计真实分布。注意 fprintd 有 `PrivateTmp=true` + `ProtectSystem=strict`，写 `/tmp` 的日志会被隔离——改用 stderr + journald（通过 `/etc/systemd/system/fprintd.service.d/10-debug.conf` 设 `G_MESSAGES_DEBUG=all`，`adm` 组可读）。
4. **关键数据**：mean ratio≈0.95，说明 0.82 合理；真正瓶颈是 `MIN(forward,reverse)` 被不对称的内点数拖累，改 `MAX` 后分数从 ≤6 跳到 9~10。
5. **定版**：移除全部诊断代码，重新编译，确认库里无诊断符号。

调试期间的库（`-diag`/`-tuned`）是过程产物，最终版是干净的 `-final`。

## 快速安装

```bash
cd <本仓库目录>
sudo bash scripts/install-final.sh
fprintd-verify "$USER"     # 按手指验证
fprintd-list "$USER"       # 应显示 "Egis Technology Inc. 0571 touch sensor (press)"
```

`install-final.sh` 会：装运行时依赖 → 备份原厂库到 `/root/libfprint-backups/` → 停止 fprintd → 安装最终库 → 清理调试 drop-in → 重启服务。

**现有指纹模板可直接使用，无需重新录入**（模板格式未变）。

## 完整配置：从录入到登录

驱动只解决"设备能用"。要让指纹在 sudo 和登录界面都能用，还需要配 PAM。这台机器和另一台能正常用指纹的机器对照后，确认了完整配置。

**1. 录入指纹**

```bash
fprintd-enroll "$USER"     # 按提示反复"按下→抬起"，稍微挪动位置
```

**2. sudo 认证**（可选）

```bash
sudo bash scripts/setup-sudo-fingerprint.sh
```

关键点：Ubuntu 默认 sudoers 认证的是**调用者本人**，不是 root。所以 `pam_fprintd` 查的是 `chen` 的指纹——给当前用户录就行，**不需要给 root 录**。（这台用的 sudo-rs 0.2.14，源码里 `auth_user = AuthUser::from_current_user()`，PAM service 名是 `sudo`。）

脚本只在 `/etc/pam.d/sudo` 加一行，失败自动回落密码：

```
auth sufficient pam_fprintd.so max-tries=2 timeout=15
```

**3. 登录界面指纹**（关键，最容易漏）

```bash
sudo bash scripts/enable-login-fingerprint.sh
```

**这就是最容易被忽略的一步。** GNOME 51 的登录界面走 `gdm-password → @include common-auth`。真正让指纹提示出现并生效的，是 `common-auth` 里的 `pam_fprintd.so`——**不是 `gdm-fingerprint`**（GNOME 51 登录时并不用它）。

用官方工具启用（脚本内部就是这条）：

```bash
sudo pam-auth-update --enable fprintd
```

启用后 `common-auth` 会多一行类似：

```
auth [success=3 default=ignore] pam_fprintd.so max-tries=1 timeout=10
```

然后重启，登录界面按指纹即可。

> 排障历程中的重要教训：登录界面出现"指纹图案"只说明**设备层**在线；真正能不能登录取决于 **PAM 层**（common-auth）有没有配 pam_fprintd。两者是不同层，不要混为一谈。

## 重要注意点

1. **apt 升级会覆盖驱动**：这是整库替换方案，apt 升级 `libfprint` 后指纹会失效。建议锁版本：
   ```bash
   sudo apt-mark hold libfprint-2-2 libfprint-2-tod1
   ```
   要升级时 `sudo apt-mark unhold ...`，然后重跑 `install-final.sh`。

2. **务必保留密码**：指纹是便利认证，不是密码的替代。所有 PAM 配置都用 `sufficient` 或带回落，失败会自动回到密码，不会锁死。改 PAM 前建议留一个已开的 root 终端。

3. **`fprintd-delete` 不支持指定手指**：这个版本的 `fprintd-delete "$USER"` 会删掉该用户**所有**指纹，不是只删某一根。要保留其他手指请谨慎。

4. **录入按压要一致**：阈值是按本机传感器标定的，重新录入时尽量保持按压位置/角度一致，有助于匹配分数。

5. **sudo-rs 的 PAM_USER**：Ubuntu 26.10 默认用 sudo-rs，认证调用者是本人（不是 root）。别被老教程误导去给 root 录指纹。

6. **本仓库不含编译工具链**：只提供编译好的库和源码补丁。若要在别的机器重新编译，需自行准备 libfprint 构建环境（meson/ninja + 对应头文件 + OpenCV 4.10 运行时）。

## 排障

| 现象 | 处理 |
|---|---|
| `fprintd-list` 显示 `No devices available` | 库没装对或服务没重启；看 `journalctl -u fprintd`，检查库 hash |
| 能录入但 `verify-no-match` | 阈值/参数问题；先用 `diagnose` 脚本开 debug 读分数，参考上面的标定方法 |
| sudo 不提示指纹 | 检查 `/etc/pam.d/sudo` 有无 pam_fprintd；确认是给**当前用户**录的指纹 |
| 登录界面不提示指纹 | 检查 `common-auth` 有无 pam_fprintd，`sudo pam-auth-update --enable fprintd` |
| 登录提示 `gdm-authd was not found` | 通常是无害噪音（Ubuntu 官方说法），不必管 |
| 锁屏/唤醒后指纹不可用 | 见下方"关于蓝灯"外的说明；可重启 fprintd：`sudo systemctl restart fprintd` |

诊断脚本（都带备份、可回滚）：

- `scripts/diagnose-sudo-fp.sh` — 开 sudo 指纹 debug
- `scripts/diagnose-gdm-fp.sh` — 开 GDM 登录指纹 debug
- `scripts/inspect-other-machine.sh` — 在另一台已知能用的机器上做只读配置对照（排障利器）

## 关于蓝灯

**结论：蓝灯无法通过读 Windows 驱动文件直接实现，且不影响识别功能。**

查证过程：

- Windows 驱动（`WudfBioUsb.dll` / `CSAlgDll.dll` / `EngineAdapter.dll`）里搜不到任何 LED/light 字符串。它是标准微软 WBDI 框架驱动，算法封装在 `CSAlgDll.dll` 里（全是 `ChipSailing_*` 图像处理函数），没有点灯函数。
- Linux 驱动源码里也没有任何 LED 控制代码。
- 协议是私有 7 字节包（`EGIS` + 命令字节），社区从未标注哪个字节控制灯。

最可能的情况：灯由**芯片固件根据传感器状态自动点亮**，Windows 驱动初始化序列和 Linux 不同，导致灯的状态不同。

如果一定要试：在 Windows 下用 USBPcap 抓一次指纹工作时的 USB 流量，与 Linux 抓包对比，找出 Windows 多发且时机吻合的包——但**不保证成功**（若是硬件自动控制则抓不到命令），且灯纯粹是指示作用。

## 外挂 vs 改核心库

这里有两种驱动集成方式，你的两台机器正好各用一种：

| | 本机（EgisTec 0571） | 另一台（PXAT PT2887-CI） |
|---|---|---|
| 比对位置 | 主机 CPU（OpenCV SIFT） | 芯片内（match-on-chip） |
| libfprint 接口 | 内置驱动 | TOD 外挂驱动 |
| 补丁形态 | 编进核心库、整库替换 | 独立 `.so` 放 `tod-1/` 目录 |

**能外挂就外挂**（抗 apt 升级、安装卸载干净、不动系统核心库）。但本机是主机侧比对，匹配算法属于内置驱动，没有对应的 TOD 外挂机制，只能改核心库——这是硬件决定的，不是方案偏好。

## 文件说明

```
.
├── README.md
├── driver/
│   └── libfprint-2.so.2.0.0-final   # 编译好的最终驱动库
├── patches/
│   ├── 0001-egis0570-pixman.patch
│   ├── 0002-egis0570-touch.patch
│   ├── 0003-egis0570-verify-early-exit.patch
│   └── 0004-egis0570-touch-cleanup.patch
└── scripts/
    ├── install-final.sh              # 安装最终驱动
    ├── rollback.sh                   # 回滚原厂驱动
    ├── setup-sudo-fingerprint.sh     # 配 sudo 指纹
    ├── enable-login-fingerprint.sh   # 配登录界面指纹（common-auth）
    ├── finalize-sudo-fp.sh           # 清理 sudo 的 debug 参数
    ├── diagnose-sudo-fp.sh           # sudo 指纹诊断
    ├── diagnose-gdm-fp.sh            # 登录指纹诊断
    └── inspect-other-machine.sh      # 跨机器配置对照
```

## 回滚

```bash
sudo bash scripts/rollback.sh
```

恢复到系统原厂 libfprint。注意恢复后要重新用旧驱动录入指纹才能用滑动模式。

PAM 配置的回滚：各诊断/配置脚本运行时都会在 `/root/` 下留带时间戳的备份目录，按脚本末尾提示的命令恢复即可。

## 致谢与许可

- 触摸驱动基础：社区 [keno2003/libfprint-egis0570](https://github.com/keno2003/libfprint-egis0570)
- 匹配参数、LED 调查、PAM 配置为本项目新增。
- 指纹涉及身份凭证，请只在你自己拥有的设备上使用。
