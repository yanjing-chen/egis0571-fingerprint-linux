#!/bin/bash
# 启用 GDM 登录界面指纹：用官方 pam-auth-update 把 pam_fprintd 加入 common-auth
# 依据：另一台能指纹登录的机器，唯一差异就是 common-auth 里有 pam_fprintd.so
# 用法：sudo bash enable-login-fingerprint.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请用 sudo 运行: sudo bash $0"
    exit 1
fi

BK="/root/login-fp-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp -a /etc/pam.d/common-auth "$BK/common-auth.bak"
echo "[1/4] 已备份 common-auth -> $BK/common-auth.bak"

# 如果已经有 pam_fprintd 就跳过
if grep -q 'pam_fprintd' /etc/pam.d/common-auth; then
    echo "[2/4] common-auth 已含 pam_fprintd，无需改动"
else
    echo "[2/4] 通过 pam-auth-update 启用指纹认证模块..."
    pam-auth-update --enable fprintd
fi

echo "[3/4] 修改后的 common-auth 认证段："
grep -nE 'pam_fprintd|pam_unix|pam_sss|pam_deny|pam_permit' /etc/pam.d/common-auth

# 移除诊断期给 gdm-fingerprint 加的 debug（恢复干净）
if grep -q 'pam_fprintd.so.*debug' /etc/pam.d/gdm-fingerprint; then
    sed -i -E 's#(pam_fprintd\.so[^#]*)\bdebug\b#\1#' /etc/pam.d/gdm-fingerprint
    sed -i -E 's#(pam_fprintd\.so)  +#\1 #' /etc/pam.d/gdm-fingerprint
    echo "[4/4] 已移除 gdm-fingerprint 的 debug 参数"
else
    echo "[4/4] gdm-fingerprint 无 debug 参数，跳过"
fi

echo ""
echo "=== 完成 ==="
echo "现在重启，在登录界面按已录入的指纹即可。"
echo ""
echo "回滚：sudo cp $BK/common-auth.bak /etc/pam.d/common-auth && sudo pam-auth-update --force"
