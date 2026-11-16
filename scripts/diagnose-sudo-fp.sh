#!/bin/bash
# 开启 pam_fprintd debug 日志，用于定位"sudo 时指纹不触发"的原因
# 用法：sudo bash diagnose-sudo-fp.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请用 sudo 运行: sudo bash $0"
    exit 1
fi

BK="/root/sudo-fp-debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp -a /etc/pam.d/sudo "$BK/sudo.bak"
echo "[1/2] 已备份 /etc/pam.d/sudo -> $BK/sudo.bak"

# 给 pam_fprintd.so 加 debug 参数（幂等）
if grep -q 'pam_fprintd\.so.*debug' /etc/pam.d/sudo; then
    echo "[2/2] debug 已开启，无需改动"
else
    sed -i -E 's#(pam_fprintd\.so[^ ]*)#\1 debug#' /etc/pam.d/sudo
    echo "[2/2] 已给 pam_fprintd.so 加上 debug 参数"
fi
echo "当前配置："
grep -n 'pam_fprintd' /etc/pam.d/sudo

echo ""
echo "================================================================"
echo "下一步：新开一个终端，运行下面这条命令测一次 sudo"
echo ""
echo "    sudo -k && sudo true"
echo ""
echo "出现 [sudo: 验证] 密码: 时，按 Ctrl+C 取消即可（不用输密码）。"
echo "测完后回来告诉我，我来读 debug 日志定位原因。"
echo "================================================================"
echo ""
echo "恢复命令（诊断完可选）：sudo cp $BK/sudo.bak /etc/pam.d/sudo"
