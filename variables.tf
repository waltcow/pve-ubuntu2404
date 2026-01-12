# Proxmox Connection Variables
variable "proxmox_endpoint" {
  description = "Proxmox VE API 端点 (例如: https://proxmox.example.com:8006)"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox VE 用户名 (例如: root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox VE 密码 (如果使用 API token 则留空)"
  type        = string
  sensitive   = true
  default     = ""
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
  description = "用于 Proxmox 主机操作的 SSH 用户名"
  type        = string
  default     = "root"
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
  default     = 2048
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
  description = "磁盘大小 (单位: GB)"
  type        = number
  default     = 32
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
  default     = "8.8.8.8"
}

variable "cloud_init_user" {
  description = "Cloud-init 默认用户"
  type        = string
  default     = "ubuntu"
}

variable "cloud_init_password" {
  description = "Cloud-init 用户密码"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "用于 Cloud-init 的 SSH 公钥"
  type        = string
  default     = ""
}

variable "ubuntu_image_url" {
  description = "Ubuntu 24.04 云镜像 URL"
  type        = string
  default     = "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cloud-images/noble/current/noble-server-cloudimg-amd64.img"
}

variable "start_on_create" {
  description = "创建后启动虚拟机"
  type        = bool
  default     = true
}