# CLAUDE.md

此文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 项目概述

这是一个使用 Terraform 在 Proxmox VE 上自动化创建 Ubuntu 24.04 LTS 虚拟机的基础设施即代码(IaC)项目。使用 bpg/proxmox provider (v0.92+) 实现 VM 的声明式配置和管理。

## 核心架构

### 资源依赖关系
- `proxmox_virtual_environment_download_file` → 下载 Ubuntu 云镜像到 Proxmox 存储（使用清华镜像源）
- `proxmox_virtual_environment_vm` → 依赖云镜像资源创建 VM，使用 cloud-init 进行初始化配置

### 关键设计决策
- **云镜像方式**: 使用 Ubuntu cloud image 而非 ISO 安装，大幅缩短部署时间
- **镜像格式**: 使用 `content_type = "import"` + `import_from` 处理未压缩的 qcow2 镜像（性能最佳）
- **Guest Agent**: 默认禁用 `agent.enabled = false`，因为 Ubuntu 云镜像不预装 qemu-guest-agent
- **销毁行为**: 使用 `stop_on_destroy = true` 确保 VM 正常停止而非超时
- **Cloud-init 集成**: 通过 cloud-init 完成用户账户、网络、SSH 密钥等初始化配置
- **网络灵活性**: 支持 DHCP 或静态 IP 配置，通过条件表达式实现
- **生命周期管理**: 使用 `lifecycle.ignore_changes` 避免网络设备变化触发不必要的重建

## 常用命令

### 初始化和验证
```bash
terraform init                    # 初始化 provider 和模块
terraform validate               # 验证配置语法
terraform fmt                    # 格式化 Terraform 文件
```

### 规划和部署
```bash
terraform plan                   # 预览将要创建的资源
terraform apply                  # 创建/更新资源
terraform apply -auto-approve    # 跳过确认直接应用
```

### 变量覆盖
```bash
terraform apply -var="vm_name=test-vm" -var="vm_id=101"
terraform apply -var-file="custom.tfvars"
```

### 查看和管理
```bash
terraform output                 # 显示所有输出值
terraform output vm_ip_addresses # 查看 VM IP 地址
terraform show                   # 显示当前状态
terraform state list             # 列出所有资源
```

### 清理
```bash
terraform destroy               # 销毁所有资源
terraform destroy -target=proxmox_virtual_environment_vm.ubuntu_vm  # 仅销毁指定资源
```

## 文件结构

- **providers.tf**: Provider 配置 (v0.92+),定义 Proxmox 连接参数和认证方式
- **variables.tf**: 所有变量声明,包含 Proxmox 连接、VM 配置、网络和 cloud-init 设置
- **ubuntu2404.tf**: 主资源定义文件,包含云镜像下载和 VM 创建逻辑
- **outputs.tf**: 输出定义,暴露 VM 的 ID、IP、MAC 地址等信息
- **terraform.tfvars**: (需要创建) 实际变量值,包含敏感信息,已在 .gitignore 中排除
- **terraform.tfvars.example**: 变量配置模板

## 关键配置点

### 云镜像下载配置
- **content_type**: 必须使用 `"import"` 而非 `"iso"`（Ubuntu 云镜像是未压缩的 qcow2 格式）
- **import_from vs file_id**:
  - 使用 `import_from` 配合 `content_type = "import"` 处理未压缩镜像（推荐）
  - `file_id` 仅用于压缩镜像（配合 `content_type = "iso"` + `decompression_algorithm`）
- **file_name**: 建议明确指定为 `.qcow2` 扩展名，避免 Proxmox 文件扩展名验证错误
- **镜像源**: 默认使用清华大学镜像源，国内下载速度更快

### QEMU Guest Agent 配置
⚠️ **重要**: Ubuntu 云镜像默认**不安装** qemu-guest-agent！

**当前配置（默认）**:
```hcl
agent {
  enabled = false
}
stop_on_destroy = true
```

**影响**:
- ✅ VM 创建和销毁速度快，无超时风险
- ❌ 无法自动获取 VM 的动态 IP 地址（`ipv4_addresses` 输出为空）
- ❌ Proxmox 使用 ACPI 而非 guest agent 进行关机操作

**如需启用 agent**，必须通过 cloud-init 自定义配置安装并启动 qemu-guest-agent：
```hcl
agent {
  enabled = true
}
# 移除 stop_on_destroy，因为 agent 可以正常关机
```
参考 provider 文档的 cloud-init.md 指南创建自定义 user_data_file_id。

### NVIDIA GPU Passthrough 和驱动配置
⚠️ **重要**: RTX 5090 等新一代 GPU **必须**使用 NVIDIA 开源内核模块！

**自动驱动安装配置**:
```hcl
enable_nvidia_driver = true
nvidia_driver_version = "570"  # 将自动安装 nvidia-driver-570-open
```

**关键要点**:
- ✅ **开源驱动要求**: RTX 5090 和其他新 GPU 必须使用 `nvidia-driver-xxx-open` 包（配置已自动处理）
- ✅ **UEFI 模式**: 已配置 `bios = "ovmf"` 和 `machine = "q35"` 以支持 GPU passthrough
- ✅ **PCIe 模式**: GPU mapping 配置 `pcie = true` 以获得最佳性能
- ⚠️ **驱动加载错误**: 如果看到 `requires use of the NVIDIA open kernel modules`，说明安装了闭源驱动，需改为开源驱动

**手动切换到开源驱动**（如果已安装闭源驱动）:
```bash
# 卸载闭源驱动
sudo apt remove --purge nvidia-driver-570 nvidia-dkms-570

# 安装开源驱动
sudo apt install nvidia-driver-570-open

# 重启系统
sudo reboot
```

**验证驱动**:
```bash
nvidia-smi                    # 应显示 GPU 信息
lsmod | grep nvidia           # 确认内核模块已加载
sudo dmesg | grep -i nvidia   # 检查加载日志
```

### Proxmox 认证
支持两种认证方式，provider 会自动根据配置选择：

**方式 1 - API Token（推荐）**:
```hcl
proxmox_api_token = "terraform@pve!provider=3906db8d-edab-4582-86ad-3b65582e3f8c"
```
- ✅ 更安全，无需暴露 root 密码
- ✅ 可精细控制权限
- ✅ 便于撤销和轮换

创建 API Token:
1. Proxmox Web UI → Datacenter → Permissions → API Tokens
2. 点击 "Add" 创建新 token
3. 用户选择 `terraform@pve`（或其他用户）
4. Token ID 设置为 `provider`（或自定义）
5. 取消勾选 "Privilege Separation"（如果需要完整权限）
6. 复制生成的 token secret（仅显示一次）

**方式 2 - 用户名/密码（备选）**:
```hcl
```

**SSH 连接**: 某些 provider 操作需要 SSH，默认使用 SSH agent

### 网络配置逻辑
在 ubuntu2404.tf 的 `initialization.ip_config.ipv4` 块:
- `vm_ip_address = ""` → 使用 DHCP
- `vm_ip_address = "192.168.1.100/24"` → 使用静态 IP (需要同时设置 `vm_gateway`)

### 存储要求
- `vm_storage` 必须在 Proxmox 节点上存在且有足够空间 (~700MB 用于云镜像)
- 常见存储池: `local-lvm`, `local`, `local-zfs`
- 使用 `pvesm status` 在 Proxmox 主机上验证可用存储

### VM ID 唯一性
- `vm_id` 在 Proxmox 节点上必须唯一
- 创建多个 VM 时需确保 VM ID 不冲突

## 修改指南

### 添加多网卡
在 ubuntu2404.tf 中添加额外的 `network_device` 块:
```hcl
network_device {
  bridge = "vmbr1"
  model  = "virtio"
}
```

### 添加额外磁盘
在 ubuntu2404.tf 中添加额外的 `disk` 块:
```hcl
disk {
  datastore_id = var.vm_storage
  interface    = "virtio1"
  size         = "100G"
}
```

### 自定义 cloud-init 配置
修改 ubuntu2404.tf 的 `initialization` 块,可添加:
- `user_data_file_id`: 自定义 cloud-init 用户数据
- `vendor_data_file_id`: Vendor 特定配置
- `network_data_file_id`: 高级网络配置

### 使用环境变量传递敏感信息
```bash
export TF_VAR_cloud_init_password="vm-password"
terraform apply
```

## 故障排查

### 云镜像下载失败
- 验证 Proxmox 节点网络连通性:
  ```bash
  curl -I https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cloud-images/noble/current/noble-server-cloudimg-amd64.img
  ```
- 检查存储空间: `pvesm status`
- 确认防火墙规则允许 HTTPS 出站连接
- 如果清华镜像源不可用，可改用 Ubuntu 官方源: `https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img`

### VM 无法获取 IP (DHCP 模式)
- 确认网络有 DHCP 服务器
- 等待 cloud-init 完成 (可能需要 1-2 分钟)
- 在 Proxmox 控制台检查 VM 启动日志
- 验证 qemu-guest-agent 运行状态: `systemctl status qemu-guest-agent`

### Terraform 创建或销毁 VM 时超时
**原因**: `agent.enabled = true` 但 qemu-guest-agent 未在 VM 中运行

**解决方案**:
1. 检查当前配置是否正确设置 `agent.enabled = false` 和 `stop_on_destroy = true`
2. 如果已设置 `agent.enabled = true`，确保通过 cloud-init 安装了 guest agent
3. 临时解决: 在 Proxmox 控制台手动停止卡住的 VM

### SSH 连接被拒绝
- 验证 `ssh_public_key` 格式正确 (完整的 `ssh-rsa AAAAB3...` 字符串)
- 检查 cloud-init 完成状态: `cloud-init status` (在 VM 控制台中)
- 确认 VM 已完全启动并且 SSH 服务正在运行

### 无法获取 VM 的 IP 地址（ipv4_addresses 为空）
**原因**: `agent.enabled = false` 时，provider 无法通过 guest agent 获取 IP 信息

**解决方案**:
- 使用静态 IP 配置（推荐）
- 或通过 cloud-init 安装 guest agent 并设置 `agent.enabled = true`
- 或从 Proxmox 控制台查看 VM 的 IP 地址

### 权限错误
确保 Proxmox 用户具有以下权限:
- `VM.Allocate` - 创建 VM
- `VM.Config.Disk` - 配置磁盘
- `VM.Config.Network` - 配置网络
- `Datastore.Allocate` - 在存储上分配空间

## 安全考虑

- **terraform.tfvars** 已在 .gitignore 中排除,绝不提交包含密码的文件
- 生产环境建议设置 `proxmox_insecure = false` 启用 TLS 验证
- 优先使用 SSH 密钥而非密码进行 VM 访问
- 考虑使用 API token 代替 root 密码进行 Proxmox 认证
- 敏感变量 (`cloud_init_password`) 已标记为 `sensitive = true`
