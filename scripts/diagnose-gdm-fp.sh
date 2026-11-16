#!/bin/bash
# 打开 GDM 登录界面的指纹 debug 日志，用于定位"登录界面指纹不通过"
# 做两件事：
#   1) 给 /etc/pam.d/gdm-fingerprint 的 pam_fprintd.so 加 debug
#   2) 确认 authd 安装状态（GNOME 51 登录界面对它敏感）
# 用法：sudo bash diagnose-gdm-fp.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请用 sudo 运行: sudo bash $0"
    exit 1
fi

BK="/root/gdm-fp-debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp -a /etc/pam.d/gdm-fingerprint "$BK/gdm-fingerprint.bak"
echo "[1/3] 已备份 -> $BK/gdm-fingerprint.bak"

# 给 gdm-fingerprint 的 pam_fprintd 加 debug（幂等）
if grep -q 'pam_fprintd\.so.*debug' /etc/pam.d/gdm-fingerprint; then
    echo "[2/3] gdm-fingerprint debug 已开启"
else
    sed -i -E 's#(pam_fprintd\.so[^ ]*)#\1 debug#' /etc/pam.d/gdm-fingerprint
    echo "[2/3] 已给 gdm-fingerprint 的 pam_fprintd 加 debug"
fi
grep -n 'pam_fprintd' /etc/pam.d/gdm-fingerprint

echo "[3/3] authd 相关状态："
if dpkg -l 2>/dev/null | grep -q '^ii\s\+authd\s'; then
    dpkg -l | grep '^ii\s\+authd\s'
    systemctl is-active authd 2>/dev/null || true
else
    echo "  authd 未安装（Ubuntu 26.10 的 GNOME 51 登录界面可能会尝试用它）"
fi

echo ""
echo "================================================================"
echo "下一步（关键）："
echo "  1) 重启电脑"
echo "  2) 在登录界面按一次已录入的指纹（不管成没成）"
echo "  3) 用密码登录进来，回来告诉我一声"
echo "  然后我读 journald 里 gdm-fingerprint 的 debug 日志，就能确定原因。"
echo "================================================================"
echo ""
echo "恢复命令：sudo cp $BK/gdm-fingerprint.bak /etc/pam.d/gdm-fingerprint"
