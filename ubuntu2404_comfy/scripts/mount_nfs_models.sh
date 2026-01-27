#!/bin/bash
set -e

# NFS 配置
NFS_SERVER="192.168.50.40"
NFS_EXPORT="/mnt/models-store"
MOUNT_POINT="/mnt/models"
COMFYUI_DIR="${HOME}/ComfyUI"

echo "=========================================="
echo "NFS Models Mount Setup for ComfyUI"
echo "=========================================="

# 1) 安装 NFS 客户端
echo "[1/4] 安装 NFS 客户端..."
sudo apt update
sudo apt -y install nfs-common

# 2) 创建挂载点并挂载测试
echo "[2/4] 创建挂载点并测试挂载..."
sudo mkdir -p ${MOUNT_POINT}

# 测试 NFS 服务器连接
echo "测试 NFS 服务器连接..."
if ! showmount -e ${NFS_SERVER} 2>/dev/null; then
    echo "警告: 无法连接到 NFS 服务器 ${NFS_SERVER}"
    echo "请检查:"
    echo "  1. NFS 服务器是否运行"
    echo "  2. 网络连接是否正常"
    echo "  3. 防火墙规则是否允许 NFS 访问"
    exit 1
fi

# 挂载 NFS
echo "挂载 NFS 共享..."
sudo mount -t nfs -o vers=4.2,nconnect=8 ${NFS_SERVER}:${NFS_EXPORT} ${MOUNT_POINT}

# 验证挂载
if df -h | grep -q ${MOUNT_POINT}; then
    echo "✓ NFS 挂载成功!"
    df -h | grep ${MOUNT_POINT}
    echo ""
    echo "挂载点内容:"
    ls -lah ${MOUNT_POINT} | head -10
else
    echo "✗ NFS 挂载失败!"
    exit 1
fi

# 3) 配置开机自动挂载（fstab）
echo "[3/4] 配置开机自动挂载..."
FSTAB_ENTRY="${NFS_SERVER}:${NFS_EXPORT} ${MOUNT_POINT} nfs4 vers=4.2,nconnect=8,_netdev,noatime 0 0"

# 检查是否已存在配置
if grep -q "${NFS_SERVER}:${NFS_EXPORT}" /etc/fstab; then
    echo "fstab 配置已存在，跳过..."
else
    echo "添加 fstab 配置..."
    echo "${FSTAB_ENTRY}" | sudo tee -a /etc/fstab
    
    # 测试 fstab 配置
    echo "测试 fstab 配置..."
    sudo umount ${MOUNT_POINT}
    sudo mount -a
    
    if df -h | grep -q ${MOUNT_POINT}; then
        echo "✓ fstab 配置成功!"
        df -h | grep ${MOUNT_POINT}
    else
        echo "✗ fstab 配置失败!"
        exit 1
    fi
fi

# 4) 让 ComfyUI 使用 /mnt/models（软链接方式）
echo "[4/4] 配置 ComfyUI 使用 NFS models 目录..."

if [ ! -d "${COMFYUI_DIR}" ]; then
    echo "警告: ComfyUI 目录不存在: ${COMFYUI_DIR}"
    echo "ComfyUI 安装完成后，请手动运行以下命令:"
    echo "  cd ${COMFYUI_DIR}"
    echo "  mv models models.bak.$(date +%F-%H%M%S)"
    echo "  ln -sfn ${MOUNT_POINT} models"
    exit 0
fi

cd ${COMFYUI_DIR}

# 备份原 models 目录（如果存在且不是软链接）
if [ -d models ] && [ ! -L models ]; then
    BACKUP_NAME="models.bak.$(date +%F-%H%M%S)"
    echo "备份原 models 目录到 ${BACKUP_NAME}..."
    mv models "${BACKUP_NAME}"
fi

# 创建软链接
echo "创建软链接: ${COMFYUI_DIR}/models -> ${MOUNT_POINT}"
ln -sfn ${MOUNT_POINT} models

# 验证软链接
if [ -L models ]; then
    echo "✓ 软链接创建成功!"
    ls -lah models
else
    echo "✗ 软链接创建失败!"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ NFS Models 配置完成!"
echo "=========================================="
echo ""
echo "NFS 挂载信息:"
df -h | grep ${MOUNT_POINT}
echo ""
echo "ComfyUI models 目录:"
ls -lah ${COMFYUI_DIR}/models
echo ""
echo "请确保 NFS 服务器上的目录结构如下:"
echo "  ${MOUNT_POINT}/checkpoints"
echo "  ${MOUNT_POINT}/loras"
echo "  ${MOUNT_POINT}/vae"
echo "  ${MOUNT_POINT}/controlnet"
echo "  ${MOUNT_POINT}/embeddings"
echo "  ${MOUNT_POINT}/upscale_models"
echo ""
echo "完成!"
