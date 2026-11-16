#!/bin/bash
# 回滚到系统原厂 libfprint
set -euo pipefail

LIB="/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0"
BACKUP="/root/libfprint-backups/libfprint-2.so.2.0.0.orig"

if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请用 sudo 运行：sudo bash $0"
    exit 1
fi

if [ ! -f "$BACKUP" ]; then
    echo "错误：找不到备份 $BACKUP"
    exit 1
fi

echo "停止 fprintd 并恢复原厂库..."
systemctl stop fprintd 2>/dev/null || true
cp -f "$BACKUP" "$LIB"
chmod 644 "$LIB"
ldconfig
systemctl start fprintd 2>/dev/null || true

echo "已回滚到原厂 libfprint。"
echo "注意：恢复后需要重新用旧驱动录入指纹才能使用滑动模式。"
