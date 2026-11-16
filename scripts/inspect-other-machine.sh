#!/bin/bash
# 在【另一台能指纹登录的机器】上运行，只读检查，不修改任何东西。
# 用法：bash inspect-other-machine.sh   （不需要 sudo，个别项会提示）
echo "==================== 指纹登录相关配置对照 ===================="

echo "--- [1] 系统版本 ---"
cat /etc/os-release 2>/dev/null | grep -E 'PRETTY_NAME|VERSION_ID'
gnome-shell --version 2>/dev/null
dpkg -l 2>/dev/null | grep -E '^ii\s+(gdm3|gnome-shell|fprintd|libpam-fprintd|libfprint-2-2|libfprint-2-tod1)\s' | awk '{print $2, $3}'

echo ""
echo "--- [2] authd 是否安装/运行（重点）---"
if dpkg -l 2>/dev/null | grep -q '^ii\s\+authd\s'; then
    dpkg -l | grep '^ii\s\+authd\s' | awk '{print $2, $3}'
    echo "authd 服务状态:"
    systemctl is-enabled authd 2>/dev/null
    systemctl is-active authd 2>/dev/null
else
    echo "authd 未安装"
fi
echo "gdm-authd PAM 文件是否存在:"
ls -la /etc/pam.d/gdm-authd 2>/dev/null || echo "  不存在"

echo ""
echo "--- [3] PAM 指纹配置 ---"
echo "[gdm-fingerprint 的指纹行]"
grep -n 'pam_fprintd' /etc/pam.d/gdm-fingerprint 2>/dev/null || echo "  无"
echo "[gdm-authd 的指纹/authd 行]"
grep -nE 'pam_fprintd|pam_authd|common-auth' /etc/pam.d/gdm-authd 2>/dev/null || echo "  无或无此文件"
echo "[common-auth 的指纹行]"
grep -nE 'pam_fprintd|pam_unix|pam_sss' /etc/pam.d/common-auth 2>/dev/null
echo "[pam-auth-update 已启用的认证模块]"
ls -la /var/lib/pam/ 2>/dev/null | grep -iE 'fprint|authd' || echo "  无"

echo ""
echo "--- [4] GDM 登录界面 dconf（指纹相关）---"
echo "[greeter.dconf-defaults 里的指纹项]"
grep -nE 'fingerprint' /etc/gdm3/greeter.dconf-defaults 2>/dev/null || echo "  无（用默认）"

echo ""
echo "--- [5] 是否有 GNOME shell 补丁痕迹（重点）---"
echo "[G_RESOURCE_OVERLAYS 环境变量]"
grep -rn 'G_RESOURCE_OVERLAYS' /etc/systemd/ /etc/environment /etc/profile.d/ /etc/gdm3/ 2>/dev/null | head -20 || echo "  无"
echo "[gdm 用户的 systemd drop-in]"
find /etc/systemd/user/ /usr/lib/systemd/user/ -iname '*shell*' 2>/dev/null | head -20

echo ""
echo "--- [6] 指纹设备与驱动形态 ---"
echo "[fprintd 识别到的设备]"
fprintd-list "$USER" 2>&1 | head -12
echo "[libfprint 核心库 vs TOD 外挂]"
sha256sum /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 2>/dev/null
ls -la /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/ 2>/dev/null || echo "  无 tod-1 目录"

echo ""
echo "==================== 检查完成，请把全部输出贴回 ===================="
