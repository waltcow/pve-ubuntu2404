# Proxmox Connection Variables
variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint (e.g., https://proxmox.example.com:8006)"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox VE username (e.g., root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox VE password"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox host operations"
  type        = string
  default     = "root"
}

# VM Configuration Variables
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "ubuntu-2404-vm"
}

variable "vm_id" {
  description = "VM ID (must be unique on the Proxmox node)"
  type        = number
  default     = 100
}

variable "target_node" {
  description = "Proxmox node to create the VM on"
  type        = string
  default     = "pve"
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "vm_disk_size" {
  description = "Disk size (e.g., 32G)"
  type        = string
  default     = "32G"
}

variable "vm_storage" {
  description = "Storage pool for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vm_ip_address" {
  description = "Static IP address in CIDR notation (e.g., 192.168.1.100/24) or leave empty for DHCP"
  type        = string
  default     = ""
}

variable "vm_gateway" {
  description = "Default gateway IP address"
  type        = string
  default     = ""
}

variable "vm_nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "8.8.8.8"
}

variable "cloud_init_user" {
  description = "Cloud-init default user"
  type        = string
  default     = "ubuntu"
}

variable "cloud_init_password" {
  description = "Cloud-init user password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
  default     = ""
}

variable "ubuntu_image_url" {
  description = "URL to Ubuntu 24.04 cloud image"
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "start_on_create" {
  description = "Start the VM after creation"
  type        = bool
  default     = true
}