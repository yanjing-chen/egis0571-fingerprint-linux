#!/bin/bash
# 收尾：移除 pam_fprintd 的 debug 参数，恢复干净的 sudo 指纹配置
# 用法：sudo bash finalize-sudo-fp.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请用 sudo 运行: sudo bash $0"
    exit 1
fi

echo "=== 恢复干净的 sudo 指纹配置 ==="
# 移除 pam_fprintd.so 行尾的 debug 参数（保留 max-tries / timeout）
sed -i -E 's#(pam_fprintd\.so[^#]*)\bdebug\b#\1#' /etc/pam.d/sudo
# 清理可能产生的双空格
sed -i -E 's#(pam_fprintd\.so)  +#\1 #' /etc/pam.d/sudo

echo "当前 /etc/pam.d/sudo 的指纹配置行："
grep -n 'pam_fprintd' /etc/pam.d/sudo

echo ""
echo "=== 完成。sudo 指纹已配置妥当（无 debug 日志）==="
echo "验证方法：新开终端跑  sudo -k && sudo true  ，放右手食指即可。"
