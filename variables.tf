# Proxmox Connection Variables
variable "proxmox_endpoint" {
  description = "Proxmox VE API 端点 (例如: https://proxmox.example.com:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox VE API 令牌 (格式: USER@REALM!TOKENID=SECRET)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_insecure" {
  description = "跳过 Proxmox API 的 TLS 验证"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "Proxmox 节点 SSH 用户名（用于上传 cloud-init snippets）"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Proxmox 节点 SSH 私钥路径（本地文件，必须是绝对路径）"
  type        = string
  default     = ""
}

# VM Configuration Variables
variable "vm_name" {
  description = "虚拟机名称"
  type        = string
  default     = "ubuntu-2404-vm"
}

variable "vm_id" {
  description = "虚拟机 ID (在 Proxmox 节点上必须唯一)"
  type        = number
  default     = 100
}

variable "target_node" {
  description = "创建虚拟机的 Proxmox 节点"
  type        = string
  default     = "pve"
}

variable "vm_memory" {
  description = "内存大小 (单位: MB)"
  type        = number
  default     = 4096
}

variable "vm_memory_balloon" {
  description = "内存气球最小值 (单位: MB，留空则不启用气球)"
  type        = number
  default     = null
}

variable "vm_cores" {
  description = "CPU 核心数"
  type        = number
  default     = 2
}

variable "vm_sockets" {
  description = "CPU 插槽数"
  type        = number
  default     = 1
}

variable "vm_disk_size" {
  description = "磁盘大小 (例如: \"32G\")"
  type        = string
  default     = "32G"
}

variable "vm_storage" {
  description = "虚拟机磁盘存储池 (可以是基于 LVM 的存储如 local-lvm)"
  type        = string
  default     = "local-lvm"
}

variable "vm_image_storage" {
  description = "云镜像下载存储池 (必须是基于文件的存储如 local)"
  type        = string
  default     = "local"
}

variable "vm_snippets_storage" {
  description = "Cloud-init snippets 存储池 (必须支持 snippets 内容类型)"
  type        = string
  default     = "local"
}

variable "vm_bridge" {
  description = "网络桥接"
  type        = string
  default     = "vmbr0"
}

variable "vm_ip_address" {
  description = "静态 IP 地址 (CIDR 格式, 例如: 192.168.1.100/24) 或留空使用 DHCP"
  type        = string
  default     = ""
}

variable "vm_gateway" {
  description = "默认网关 IP 地址"
  type        = string
  default     = ""
}

variable "vm_nameserver" {
  description = "DNS 名称服务器"
  type        = string
  default     = "114.114.114.114"
}

variable "cloud_init_user" {
  description = "Cloud-init 默认用户"
  type        = string
  default     = "ubuntu"
}

variable "cloud_init_password" {
  description = "Cloud-init 用户密码 (留空则不设置密码并锁定本地口令)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "用于 Cloud-init 的 SSH 公钥"
  type        = string
  default     = ""
}

variable "ubuntu_image_file_name" {
  description = "云镜像文件名（需与 Proxmox 存储中的文件一致）"
  type        = string
  default     = "ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "start_on_create" {
  description = "创建后启动虚拟机"
  type        = bool
  default     = true
}

# APT Mirror Configuration
variable "apt_mirror_url" {
  description = "APT 镜像源 URL (用于加速软件包下载)"
  type        = string
  default     = "https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
}

# NVIDIA Driver Configuration
variable "enable_nvidia_driver" {
  description = "是否自动安装 NVIDIA 驱动"
  type        = bool
  default     = false
}

variable "nvidia_driver_version" {
  description = "NVIDIA 驱动版本 (例如: 570 用于 RTX 5090，将自动使用 nvidia-driver-{version}-open 开源驱动)"
  type        = string
  default     = "570"
}

# GPU Passthrough Configuration
variable "enable_gpu_passthrough" {
  description = "是否启用 GPU 直通"
  type        = bool
  default     = false
}

variable "gpu_device_id" {
  description = "GPU 设备 ID (例如: 10de:2b85)"
  type        = string
  default     = ""
}

variable "gpu_subsystem_id" {
  description = "GPU 子系统 ID (例如: 1458:4198)"
  type        = string
  default     = ""
}

variable "gpu_iommu_group" {
  description = "GPU IOMMU group 编号"
  type        = number
  default     = 0
}

variable "gpu_pci_path" {
  description = "GPU PCI 路径 (例如: 0000:01:00)"
  type        = string
  default     = ""
}
