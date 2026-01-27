#!/bin/bash
# GPU 直通信息获取脚本
# 用于获取 Proxmox GPU passthrough 所需的设备参数

echo "========================================="
echo "  GPU 直通信息获取工具"
echo "========================================="
echo ""

# 检查是否在 Proxmox 主机上运行
if [ ! -d "/etc/pve" ]; then
    echo "⚠️  警告: 未检测到 /etc/pve 目录"
    echo "   此脚本应在 Proxmox VE 主机上运行"
    echo ""
fi

# 检查 IOMMU 是否启用
echo "=== 检查 IOMMU 状态 ==="
if dmesg | grep -q -i "IOMMU enabled"; then
    echo "✓ IOMMU 已启用"
else
    echo "✗ IOMMU 未启用或未检测到"
    echo "  请在 GRUB 配置中添加:"
    echo "  - Intel CPU: intel_iommu=on"
    echo "  - AMD CPU: amd_iommu=on"
    echo ""
fi

# 列出所有 GPU 设备
echo ""
echo "=== 检测到的 GPU 设备 ==="
GPU_LIST=$(lspci -nn | grep -i -E "vga|3d|display|nvidia|amd.*radeon")

if [ -z "$GPU_LIST" ]; then
    echo "✗ 未检测到 GPU 设备"
    exit 1
fi

echo "$GPU_LIST"
echo ""

# 让用户选择 GPU
echo "=== 请输入要直通的 GPU PCI 地址 ==="
echo "格式示例: 01:00.0"

# 循环直到用户输入有效的 PCI 地址
while true; do
    read -p "PCI 地址: " PCI_ADDR

    # 检查是否为空
    if [ -z "$PCI_ADDR" ]; then
        echo "✗ 错误: PCI 地址不能为空，请重新输入"
        continue
    fi

    # 标准化 PCI 地址格式
    PCI_ADDR_SHORT=$(echo "$PCI_ADDR" | sed 's/^0000://')
    PCI_ADDR_FULL="0000:$PCI_ADDR_SHORT"

    # 验证 PCI 地址格式
    if ! echo "$PCI_ADDR_SHORT" | grep -qE '^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]$'; then
        echo "✗ 错误: PCI 地址格式不正确，应为 XX:XX.X 格式（如 01:00.0）"
        continue
    fi

    # 验证 PCI 地址是否存在
    if ! lspci -s "$PCI_ADDR_SHORT" > /dev/null 2>&1; then
        echo "✗ 错误: PCI 地址 $PCI_ADDR_SHORT 不存在，请重新输入"
        continue
    fi

    # 验证是否是 GPU 设备
    DEVICE_CLASS=$(lspci -s "$PCI_ADDR_SHORT" | cut -d: -f2 | xargs)
    if ! echo "$DEVICE_CLASS" | grep -qi -E "vga|3d|display"; then
        echo "⚠️  警告: $PCI_ADDR_SHORT 似乎不是 GPU 设备: $DEVICE_CLASS"
        read -p "是否继续? (y/N): " CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            continue
        fi
    fi

    # 所有验证通过，退出循环
    break
done

echo ""
echo "========================================="
echo "  GPU 信息汇总"
echo "========================================="
echo ""

# 设备名称
DEVICE_NAME=$(lspci -s "$PCI_ADDR_SHORT" | cut -d: -f3- | xargs)
echo "设备名称: $DEVICE_NAME"
echo ""

# 1. PCI 路径
echo "--- PCI 路径 ---"
echo "gpu_pci_path = \"$PCI_ADDR_FULL\""
echo ""

# 2. Device ID (Vendor:Device)
echo "--- Device ID (vendor:device) ---"
DEVICE_ID=$(lspci -n -s "$PCI_ADDR_SHORT" | awk '{print $3}')
echo "gpu_device_id = \"$DEVICE_ID\""
echo ""

# 3. Subsystem ID
echo "--- Subsystem ID ---"
SUBSYSTEM_ID=""

# 优先使用 sysfs 方法（最可靠）
if [ -f "/sys/bus/pci/devices/$PCI_ADDR_FULL/subsystem_vendor" ] && [ -f "/sys/bus/pci/devices/$PCI_ADDR_FULL/subsystem_device" ]; then
    SUBSYSTEM_VENDOR=$(cat "/sys/bus/pci/devices/$PCI_ADDR_FULL/subsystem_vendor" 2>/dev/null | sed 's/0x//')
    SUBSYSTEM_DEVICE=$(cat "/sys/bus/pci/devices/$PCI_ADDR_FULL/subsystem_device" 2>/dev/null | sed 's/0x//')
    if [ -n "$SUBSYSTEM_VENDOR" ] && [ -n "$SUBSYSTEM_DEVICE" ]; then
        SUBSYSTEM_ID="${SUBSYSTEM_VENDOR}:${SUBSYSTEM_DEVICE}"
    fi
fi

# 备用方法: 使用 lspci -vmm (机器可读格式)
if [ -z "$SUBSYSTEM_ID" ]; then
    SUBSYSTEM_LINE=$(lspci -vmm -s "$PCI_ADDR_SHORT" 2>/dev/null | grep "^SSubVendor:\|^SSubDevice:")
    if [ -n "$SUBSYSTEM_LINE" ]; then
        SVENDOR=$(echo "$SUBSYSTEM_LINE" | grep "SSubVendor:" | awk '{print $2}' | sed 's/0x//')
        SDEVICE=$(echo "$SUBSYSTEM_LINE" | grep "SSubDevice:" | awk '{print $2}' | sed 's/0x//')
        if [ -n "$SVENDOR" ] && [ -n "$SDEVICE" ]; then
            SUBSYSTEM_ID="${SVENDOR}:${SDEVICE}"
        fi
    fi
fi

if [ -n "$SUBSYSTEM_ID" ]; then
    echo "gpu_subsystem_id = \"$SUBSYSTEM_ID\""
else
    echo "gpu_subsystem_id = \"\" # 未能自动获取，请手动填写或使用 lspci -vvv 查看"
fi
echo ""

# 4. IOMMU Group
echo "--- IOMMU Group ---"
IOMMU_GROUP=""

# 直接从 sysfs 读取（最快最可靠）
if [ -L "/sys/bus/pci/devices/$PCI_ADDR_FULL/iommu_group" ]; then
    IOMMU_GROUP=$(basename "$(readlink /sys/bus/pci/devices/$PCI_ADDR_FULL/iommu_group)" 2>/dev/null)
fi

if [ -n "$IOMMU_GROUP" ]; then
    echo "gpu_iommu_group = $IOMMU_GROUP"
else
    echo "gpu_iommu_group = 0 # 未能自动获取，请手动填写"
fi
echo ""

# 显示 IOMMU Group 中的所有设备
if [ -n "$IOMMU_GROUP" ] && [ -d "/sys/kernel/iommu_groups/$IOMMU_GROUP/devices" ]; then
    echo "--- IOMMU Group $IOMMU_GROUP 中的所有设备 ---"
    DEVICE_COUNT=0
    for device in /sys/kernel/iommu_groups/$IOMMU_GROUP/devices/*; do
        DEVICE_COUNT=$((DEVICE_COUNT + 1))
        DEV_ADDR=$(basename "$device")
        DEV_INFO=$(lspci -nns "$DEV_ADDR" 2>/dev/null || echo "未知设备")
        echo "  $DEV_INFO"
    done
    echo ""

    if [ "$DEVICE_COUNT" -gt 2 ]; then
        echo "⚠️  警告: IOMMU Group $IOMMU_GROUP 包含 $DEVICE_COUNT 个设备"
        echo "   理想情况下 GPU 应该在独立的 IOMMU group 中"
        echo "   如果有多个设备，可能需要将整个 group 的设备都直通"
        echo ""
    fi
fi

# 检查 GPU 音频设备
echo "--- 相关音频设备检测 ---"
GPU_BUS=$(echo "$PCI_ADDR_SHORT" | cut -d: -f1)
AUDIO_DEVICES=$(lspci -nn | grep "$GPU_BUS:" | grep -i audio)
if [ -n "$AUDIO_DEVICES" ]; then
    echo "检测到 GPU 相关的音频设备:"
    echo "$AUDIO_DEVICES"
    echo ""
    echo "💡 提示: GPU 直通时通常也需要直通相关的音频设备"
else
    echo "未检测到 GPU 相关的音频设备"
fi
echo ""

# 生成 terraform.tfvars 配置片段
echo "========================================="
echo "  terraform.tfvars 配置片段"
echo "========================================="
echo ""
cat << EOF
# GPU 直通配置
enable_gpu_passthrough = true
gpu_pci_path           = "$PCI_ADDR_FULL"
gpu_device_id          = "$DEVICE_ID"
gpu_subsystem_id       = "${SUBSYSTEM_ID:-请手动填写}"
gpu_iommu_group        = ${IOMMU_GROUP:-0}
EOF

echo ""
echo "========================================="

# 额外的验证检查
echo ""
echo "=== 额外检查 ==="

# 检查 vfio 模块
if lsmod | grep -q vfio_pci; then
    echo "✓ vfio_pci 模块已加载"
else
    echo "⚠️  vfio_pci 模块未加载"
    echo "   GPU 直通需要此模块，请确保在 Proxmox 中配置了 VFIO"
fi

# 检查设备是否被占用
DRIVER=$(lspci -k -s "$PCI_ADDR_SHORT" | grep "Kernel driver in use:" | awk '{print $5}')
if [ -n "$DRIVER" ]; then
    echo "设备当前驱动: $DRIVER"
    if [ "$DRIVER" != "vfio-pci" ]; then
        echo "⚠️  设备正在被 $DRIVER 使用"
        echo "   直通前可能需要将设备绑定到 vfio-pci 驱动"
    fi
else
    echo "设备当前未被任何驱动使用"
fi

echo ""
echo "✓ 信息收集完成!"
echo ""
echo "📋 下一步操作:"
echo "   1. 将上述配置添加到 terraform.tfvars 文件"
echo "   2. 确保 Proxmox 已正确配置 IOMMU 和 VFIO"
echo "   3. 运行 'terraform plan' 验证配置"
echo "   4. 运行 'terraform apply' 创建 VM"
echo ""
