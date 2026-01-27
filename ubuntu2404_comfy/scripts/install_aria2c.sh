#!/bin/bash
set -e

echo "=========================================="
echo "Installing aria2c"
echo "=========================================="

# 更新包列表
echo "[1/3] 更新包列表..."
sudo apt update

# 安装 aria2
echo "[2/3] 安装 aria2..."
sudo apt install -y aria2

# 验证安装
echo "[3/3] 验证安装..."
if command -v aria2c &> /dev/null; then
    echo "✓ aria2c 安装成功!"
    echo ""
    aria2c --version | head -1
    echo ""
    echo "使用示例:"
    echo "  下载单个文件:"
    echo "    aria2c https://example.com/file.zip"
    echo ""
    echo "  多线程下载（16 个连接）:"
    echo "    aria2c -x 16 https://example.com/file.zip"
    echo ""
    echo "  断点续传:"
    echo "    aria2c -c https://example.com/file.zip"
    echo ""
    echo "  限制下载速度（1MB/s）:"
    echo "    aria2c --max-download-limit=1M https://example.com/file.zip"
    echo ""
else
    echo "✗ aria2c 安装失败!"
    exit 1
fi

echo "完成!"
