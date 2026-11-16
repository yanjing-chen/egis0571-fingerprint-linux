#!/bin/bash
# 认证 GitHub 后，运行本脚本创建仓库并推送。
# 用法：bash push-to-github.sh
set -euo pipefail

REPO="yanjing-chen/egis0571-fingerprint-linux"
cd "$(dirname "$0")"

echo "=== 检查 GitHub 认证 ==="
if ! gh auth status >/dev/null 2>&1; then
    echo "认证失效，请先运行：gh auth login -h github.com"
    echo "（按提示选 GitHub.com → HTTPS → 浏览器或 token 完成登录）"
    exit 1
fi
echo "认证 OK"

echo ""
echo "=== 创建远程仓库（若已存在会提示，可忽略）==="
gh repo create "$REPO" --public --source=. --remote=origin --push 2>&1 || {
    echo ""
    echo "仓库可能已存在，尝试直接推送..."
    git push -u origin HEAD
}

echo ""
echo "=== 完成 ==="
echo "仓库地址：https://github.com/$REPO"
