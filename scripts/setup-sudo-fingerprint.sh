#!/bin/bash
# 配置 sudo 指纹认证（PAM 配置 + 给调用用户本人录指纹）
#
# 重要事实（已核对 sudo-rs 0.2.14 源码）：
#   - Ubuntu 默认 sudoers 认证的是「调用者本人」(InvokingUser)，不是 root。
#   - sudo-rs 在 pam_start() 时把调用者 (chen) 作为 PAM_USER，
#     所以 pam_fprintd.so 查询的是 chen 名下的指纹，不是 root 的。
#   - 因此只需要给 chen 录指纹即可，不需要（也不应该）给 root 录。
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请用 sudo 运行: sudo bash $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-chen}"
echo "=== 配置 sudo 指纹认证（用户 $REAL_USER）==="

# 1) 备份
echo "[1/3] 备份 sudo 的 PAM 配置..."
BK="/root/sudo-pam-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp -a /etc/pam.d/sudo "$BK/sudo.bak"
echo "  备份: $BK/sudo.bak"

# 2) 只改 sudo：sufficient = 指纹成功即放行，失败自动回落密码，不会锁死
echo "[2/3] 修改 /etc/pam.d/sudo ..."
if grep -q "pam_fprintd" /etc/pam.d/sudo; then
    echo "  已存在 pam_fprintd，跳过（当前配置保持不动）"
else
    sed -i '/^#%PAM-1.0/a auth sufficient pam_fprintd.so max-tries=2 timeout=15' /etc/pam.d/sudo
    echo "  已加入 auth sufficient pam_fprintd.so"
fi
grep -E "^auth|pam_fprintd|common-auth" /etc/pam.d/sudo

# 3) 给调用者本人录指纹（sudo 认证用的是 chen 的指纹）
echo ""
echo "[3/3] 录入 $REAL_USER 的指纹（sudo 认证查询的就是这个用户）..."
echo "  默认录右手食指；想换手指可改下面的 -f 参数。"
read -r -p "  指纹名 [right-index-finger]: " FINGER
FINGER="${FINGER:-right-index-finger}"
fprintd-enroll -f "$FINGER" "$REAL_USER"

echo ""
echo "=== 完成 ==="
echo "查看指纹: fprintd-list $REAL_USER"
echo ""
echo "测试（保持当前管理员窗口别关，新开一个终端）:"
echo "  sudo -k && sudo -i"
echo "  提示放手指时 → 用刚录入的那根手指"
echo "  想用密码 → 直接输入密码（指纹失败会自动回落，不会锁死）"
echo ""
echo "回滚 PAM 配置: sudo cp $BK/sudo.bak /etc/pam.d/sudo"
