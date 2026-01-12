# API Token 配置指南

## 快速配置步骤

### 1. 创建 terraform.tfvars 文件

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. 编辑 terraform.tfvars

```bash
nano terraform.tfvars  # 或使用你喜欢的编辑器
```

### 3. 填入你的配置

```hcl
# Proxmox 连接设置
proxmox_endpoint     = "https://你的PVE服务器IP:8006"
proxmox_insecure     = true
proxmox_ssh_username = "root"

# 使用 API Token 认证（已为你填好）
proxmox_api_token = "terraform@pve!provider=3906db8d-edab-4582-86ad-3b65582e3f8c"

# VM 配置
vm_name      = "ubuntu-test"
vm_id        = 100
target_node  = "pve"  # 改为你的节点名称
vm_memory    = 2048
vm_cores     = 2
vm_disk_size = "32G"
vm_storage   = "local-lvm"  # 改为你的存储池名称

# 网络配置
vm_bridge      = "vmbr0"
vm_ip_address  = ""  # 留空使用 DHCP，或填 "192.168.1.100/24"
vm_gateway     = ""
vm_nameserver  = "8.8.8.8"

# SSH 公钥（推荐配置）
ssh_public_key = "ssh-rsa AAAAB3NzaC... 你的公钥"

# Cloud-init 用户配置
cloud_init_user     = "ubuntu"
cloud_init_password = ""  # 留空，使用 SSH 密钥登录更安全
```

### 4. 初始化并应用

```bash
# 初始化 Terraform
terraform init

# 验证配置
terraform validate

# 查看计划
terraform plan

# 应用配置（创建 VM）
terraform apply
```

## 权限检查

确保 `terraform@pve` 用户具有以下权限：

```bash
# 在 Proxmox 服务器上执行
pveum user list | grep terraform

# 检查权限
pveum acl list | grep terraform
```

如果权限不足，需要在 Proxmox Web UI 或命令行添加权限：
- VM.Allocate
- VM.Config.Disk
- VM.Config.Network
- Datastore.Allocate
- Datastore.AllocateSpace

## 测试 Token

可以使用 curl 测试 token 是否有效：

```bash
curl -k -H "Authorization: PVEAPIToken=terraform@pve!provider=3906db8d-edab-4582-86ad-3b65582e3f8c" \
  "https://你的PVE服务器IP:8006/api2/json/version"
```

如果返回版本信息，说明 token 工作正常。

## 安全建议

1. **不要提交 terraform.tfvars 到版本控制**（已在 .gitignore 中排除）
2. **定期轮换 API token**
3. **使用最小权限原则** - 仅授予必要的权限
4. **妥善保管 token secret** - 它只在创建时显示一次

## 故障排查

### Token 认证失败

如果遇到认证错误：

1. 检查 token 格式是否正确（USER@REALM!TOKENID=SECRET）
2. 验证 `Privilege Separation` 是否已取消勾选
3. 检查用户 `terraform@pve` 是否存在并有足够权限
4. 确认 token 未过期或被删除

### 切换回密码认证

如需切换回密码认证，只需在 `terraform.tfvars` 中：

```hcl
# 注释掉或删除 API token
# proxmox_api_token = "..."

# 启用用户名密码
proxmox_username = "root@pam"
proxmox_password = "你的密码"
```
