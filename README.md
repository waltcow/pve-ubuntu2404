# 使用 Terraform 在 Proxmox 上部署 Ubuntu 24.04 虚拟机

此 Terraform 配置使用 [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) provider 在 Proxmox VE 上创建 Ubuntu 24.04 LTS 虚拟机。

## 功能特性

- 🚀 从 Ubuntu 24.04 云镜像自动创建虚拟机
- ☁️ 使用 Cloud-init 进行初始化配置
- 🔑 支持 SSH 密钥认证
- 🌐 支持静态 IP 或 DHCP 配置
- 📦 可自定义 CPU、内存和磁盘资源
- 🔄 自动从清华镜像源下载云镜像

## 前置要求

1. **Proxmox VE** 服务器（版本 7.x 或 8.x）
2. **Terraform**（版本 1.0 及以上）- [安装 Terraform](https://developer.hashicorp.com/terraform/downloads)
3. **Proxmox Terraform Provider**（v0.92+）- 在 `terraform init` 时自动下载
4. **Proxmox 凭据**，需具备相应权限
5. **已配置的存储**（例如 `local-lvm`）
6. **已配置的网络桥接**（例如 `vmbr0`）

## 快速开始

### 1. 克隆或下载此配置

确保你的目录中包含以下 Terraform 文件：
- `providers.tf`
- `variables.tf`
- `ubuntu2404.tf`
- `outputs.tf`

### 2. 创建变量配置文件

复制示例文件并自定义配置：

```bash
cp terraform.tfvars.example terraform.tfvars
```

编辑 `terraform.tfvars` 并填入实际值：

```hcl
# Proxmox 连接信息
proxmox_endpoint = "https://你的-PROXMOX-IP:8006"

# 方式 1: 使用 API Token（推荐）
proxmox_api_token = "terraform@pve!provider=你的-token-secret"

# 方式 2: 使用用户名密码（备选，如使用 API token 则注释掉）
# proxmox_username = "root@pam"
# proxmox_password = "你的密码"

# 虚拟机设置
vm_name      = "ubuntu-web-server"
vm_id        = 100
target_node  = "pve"
vm_memory    = 4096
vm_cores     = 4

# 网络配置（选择 DHCP 或静态 IP）
vm_ip_address = "192.168.1.100/24"  # 或使用 "" 启用 DHCP
vm_gateway    = "192.168.1.1"       # 或使用 "" 启用 DHCP

# SSH 公钥（用于免密登录）
ssh_public_key = "ssh-rsa AAAAB3... 你的公钥"
```

### 3. 初始化 Terraform

```bash
terraform init
```

此命令会下载 Proxmox provider 并准备工作空间。

### 4. 查看执行计划

```bash
terraform plan
```

此命令会显示将要创建的资源，但不会执行任何操作。

### 5. 创建虚拟机

```bash
terraform apply
```

输入 `yes` 确认。Terraform 将会：
1. 下载 Ubuntu 24.04 云镜像到 Proxmox 存储
2. 使用你指定的配置创建虚拟机
3. 配置 cloud-init 进行首次启动
4. 启动虚拟机（如果 `start_on_create = true`）

### 6. 访问虚拟机

创建完成后，你可以通过 SSH 连接到虚拟机：

```bash
# 如果使用静态 IP
ssh ubuntu@192.168.1.100

# 如果使用 DHCP，查看输出获取分配的 IP
terraform output vm_ip_addresses
ssh ubuntu@<IP地址>
```

## 配置选项

### Proxmox 连接

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `proxmox_endpoint` | Proxmox API 端点 URL | - |
| `proxmox_username` | Proxmox 用户名 | `root@pam` |
| `proxmox_password` | Proxmox 密码 | - |
| `proxmox_insecure` | 跳过 TLS 验证 | `true` |
| `proxmox_ssh_username` | Proxmox 主机 SSH 用户 | `root` |

### 虚拟机资源

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `vm_name` | 虚拟机名称 | `ubuntu-2404-vm` |
| `vm_id` | 唯一虚拟机 ID | `100` |
| `target_node` | Proxmox 节点名称 | `pve` |
| `vm_memory` | 内存大小（MB） | `2048` |
| `vm_cores` | CPU 核心数 | `2` |
| `vm_sockets` | CPU 插槽数 | `1` |
| `vm_disk_size` | 磁盘大小（如 "32G"） | `32G` |
| `vm_storage` | 存储池 | `local-lvm` |

### 网络配置

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `vm_bridge` | 网络桥接 | `vmbr0` |
| `vm_ip_address` | CIDR 格式的静态 IP 或留空使用 DHCP | `""` (DHCP) |
| `vm_gateway` | 网关 IP | `""` |
| `vm_nameserver` | DNS 服务器 | `8.8.8.8` |

### Cloud-Init

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `cloud_init_user` | 默认用户名 | `ubuntu` |
| `cloud_init_password` | 用户密码 | `""` |
| `ssh_public_key` | SSH 公钥 | `""` |
| `ubuntu_image_url` | Ubuntu 云镜像 URL | 清华镜像源 |

## 常见使用场景

### 创建多个虚拟机

可以使用 Terraform workspace 或创建独立的目录：

```bash
# 使用 workspace
terraform workspace new vm2
terraform apply -var="vm_name=ubuntu-vm2" -var="vm_id=101"
```

### 使用 API Token 代替密码（推荐）

**创建 API Token**:
1. 登录 Proxmox Web UI
2. 导航到 `Datacenter` → `Permissions` → `API Tokens`
3. 点击 `Add` 创建新 token
4. 填写信息：
   - User: `terraform@pve`
   - Token ID: `provider`
   - 取消勾选 `Privilege Separation`（赋予完整权限）
5. 点击 `Add`，复制生成的 secret（仅显示一次）

**在 terraform.tfvars 中使用**:
```hcl
# 使用完整的 token 字符串
proxmox_api_token = "terraform@pve!provider=3906db8d-edab-4582-86ad-3b65582e3f8c"

# 注释掉密码认证
# proxmox_username = "root@pam"
# proxmox_password = "your-password"
```

配置会自动检测并使用 API token 认证。

### 自定义 Cloud-Init 配置

你可以通过修改 `ubuntu2404.tf` 中的 `initialization` 块来添加自定义 cloud-init 配置。

## 输出信息

执行 apply 后，Terraform 会提供以下有用信息：

```bash
terraform output
```

可用的输出：
- `vm_id` - Proxmox 中的虚拟机 ID
- `vm_name` - 虚拟机名称
- `vm_node` - Proxmox 节点
- `vm_ip_addresses` - 分配给虚拟机的 IP 地址
- `vm_mac_addresses` - MAC 地址
- `vm_status` - 虚拟机是否已启动

## 故障排查

### 虚拟机无法获取 IP 地址

如果使用 DHCP 但虚拟机没有获取到 IP：
1. 确保你的网络有 DHCP 服务器
2. 等待几分钟让 cloud-init 完成
3. 检查 Proxmox 控制台：`数据中心 → 节点 → 虚拟机 → 控制台`
4. 验证 qemu-guest-agent 正在运行（可能需要等待一分钟启动）

### 云镜像下载失败

如果 Ubuntu 镜像下载失败：
1. 检查 Proxmox 节点是否有互联网访问权限
2. 验证存储池有足够的空间
3. 尝试手动下载并调整 `ubuntu_image_url`

### 找不到存储池

确保 Proxmox 中存在该存储池：
```bash
pvesm status
```

更新 `vm_storage` 变量以匹配可用的存储池（例如 `local`、`local-lvm`、`local-zfs`）。

### SSH 连接被拒绝

如果无法 SSH 到虚拟机：
1. 确保虚拟机已完全启动（检查控制台）
2. 验证 cloud-init 已完成：`cloud-init status`
3. 检查 SSH 公钥在 `terraform.tfvars` 中格式正确
4. 如果配置了密码，尝试使用密码登录

### 权限不足

确保你的 Proxmox 用户具有足够的权限。用户需要以下权限：
- VM.Allocate
- VM.Config.Disk
- VM.Config.Network
- Datastore.Allocate

### Terraform 超时

如果 Terraform 在创建或销毁虚拟机时超时：
1. 检查配置中 `agent.enabled = false` 和 `stop_on_destroy = true` 是否正确设置
2. Ubuntu 云镜像默认不包含 qemu-guest-agent，不要启用 agent 除非通过 cloud-init 安装
3. 临时解决方案：在 Proxmox 控制台手动停止卡住的虚拟机

## 清理资源

销毁虚拟机及所有关联资源：

```bash
terraform destroy
```

输入 `yes` 确认。这将删除虚拟机和已下载的云镜像。

## 安全最佳实践

1. **永远不要提交 `terraform.tfvars`** - 已添加到 `.gitignore`
2. **尽可能使用 SSH 密钥**代替密码
3. **使用 API token** 代替 root 密码
4. **在生产环境启用 TLS 验证**（`proxmox_insecure = false`）
5. **使用环境变量或密钥管理存储敏感变量**：

```bash
export TF_VAR_proxmox_password="你的密码"
export TF_VAR_cloud_init_password="虚拟机密码"
terraform apply
```

## 附加资源

- [Proxmox Provider 文档](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Ubuntu 云镜像](https://cloud-images.ubuntu.com/)
- [清华大学镜像源](https://mirrors.tuna.tsinghua.edu.cn/)
- [Cloud-Init 文档](https://cloudinit.readthedocs.io/)
- [Terraform 文档](https://developer.hashicorp.com/terraform/docs)

## 许可证

此配置按原样提供，可用于教育和生产环境。

## 贡献

欢迎根据你的具体需求自定义此配置。常见改进方向：
- 添加更多 cloud-init 自定义配置
- 配置额外的磁盘
- 设置多个网络接口
- 添加标签和描述
- 实现虚拟机模板

---

**注意**：首次执行 `terraform apply` 可能需要几分钟，因为需要下载 Ubuntu 云镜像（约 700MB）到 Proxmox 存储。后续使用相同镜像创建虚拟机将会快得多。
