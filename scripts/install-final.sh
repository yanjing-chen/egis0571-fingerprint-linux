#!/bin/bash
# 安装最终版 EgisTec 1c7a:0571 触摸指纹驱动
# 已针对本机 OpenCV 4.10 调优：ratio 0.82 / RANSAC 5.0 / MAX 评分 / 阈值 8
set -euo pipefail
LIB="/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0"
BACKUP="/root/libfprint-backups/libfprint-2.so.2.0.0.orig"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DROPIN="/etc/systemd/system/fprintd.service.d/10-debug.conf"

if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请用 sudo 运行: sudo bash $0"
    exit 1
fi
if [ ! -f "$SCRIPT_DIR/libfprint-2.so.2.0.0-final" ]; then
    echo "错误：找不到 libfprint-2.so.2.0.0-final"
    exit 1
fi

# 1) 运行时依赖
echo "[1/5] 检查运行时依赖..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq \
    libopencv-core410 libopencv-imgproc410 libopencv-features2d410 \
    libopencv-calib3d410 libopencv-flann410 \
    liblapack3 libblas3 libtbb12 libgfortran5 2>/dev/null || true

# 2) 备份原厂库（仅首次）
echo "[2/5] 备份原厂库..."
if [ ! -f "$BACKUP" ]; then
    mkdir -p /root/libfprint-backups
    cp -a "$LIB" "$BACKUP"
    echo "  已备份到 $BACKUP"
else
    echo "  备份已存在，跳过"
fi

# 3) 停止服务、安装最终库
echo "[3/5] 安装最终驱动库..."
systemctl stop fprintd 2>/dev/null || true
cp -f "$SCRIPT_DIR/libfprint-2.so.2.0.0-final" "$LIB"
chmod 644 "$LIB"
ldconfig

# 4) 移除调试用的 drop-in（如果之前装过）
echo "[4/5] 清理调试配置..."
if [ -f "$DROPIN" ]; then
    rm -f "$DROPIN"
    rmdir /etc/systemd/system/fprintd.service.d 2>/dev/null || true
    echo "  已移除 debug drop-in"
fi
systemctl daemon-reload

# 5) 启动服务
echo "[5/5] 启动 fprintd..."
systemctl start fprintd 2>/dev/null || true

echo ""
echo "=========================================="
echo " 最终版驱动安装完成"
echo "=========================================="
echo "现有指纹模板可直接使用，无需重新录入。"
echo "测试: fprintd-verify \"\$USER\""
echo "回滚: sudo bash $(dirname "$0")/rollback.sh"
