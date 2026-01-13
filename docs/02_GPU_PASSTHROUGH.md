# GPU 直通参数获取指南

本文说明如何获取 `gpu_device_id`、`gpu_subsystem_id`、`gpu_iommu_group`、`gpu_pci_path`，用于 Terraform 配置 GPU 直通。

## 1. 获取 GPU PCI 设备路径

在 Proxmox 节点上执行：

```bash
lspci | grep -i nvidia
```

示例输出：
```
01:00.0 VGA compatible controller: NVIDIA Corporation ...
01:00.1 Audio device: NVIDIA Corporation ...
```

将 `01:00.0` 转为完整 PCI 路径：
```
0000:01:00
```
填写到 `gpu_pci_path`。

## 2. 获取 GPU 设备 ID 与子系统 ID

在 Proxmox 节点上执行：

```bash
lspci -n -s 01:00.0
```

示例输出：
```
01:00.0 0300: 10de:2b85 (rev a1)
```
其中 `10de:2b85` 对应 `gpu_device_id`。

继续获取子系统 ID：

```bash
lspci -nn -s 01:00.0
```

示例输出：
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ... [10de:2b85] (rev a1) Subsystem: Gigabyte Technology Co., Ltd [1458:4198]
```
其中 `1458:4198` 对应 `gpu_subsystem_id`。

## 3. 获取 IOMMU group

在 Proxmox 节点上执行：

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  echo "$(basename "$(dirname "$d")"): $(lspci -nns "${d##*/}")"
done
```

找到包含你的 GPU 的行，其前面的数字即为 `gpu_iommu_group`。

## 4. 写入 terraform.tfvars

将以上信息填入 `terraform.tfvars`：

```hcl
enable_gpu_passthrough = true
gpu_device_id     = "10de:2b85"
gpu_subsystem_id  = "1458:4198"
gpu_iommu_group   = 30
gpu_pci_path      = "0000:01:00"
```

## 5. 注意事项

- 若 GPU 处于同一个 IOMMU group 且无法隔离，需在主机侧调整硬件或内核参数。
- `gpu_pci_path` 为 PCI 设备前缀，不包含功能号（`.0`）。
- 如需直通同一 GPU 的音频设备，请确保宿主机侧配置一致。
