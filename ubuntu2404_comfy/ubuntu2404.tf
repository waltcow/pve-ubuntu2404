# 复用已存在的 GPU Resource Mapping
data "proxmox_virtual_environment_hardware_mapping_pci" "gpu_mapping" {
  count   = var.enable_gpu_passthrough ? 1 : 0
  name    = "gpu"
}

# 使用 data source 引用已存在的云镜像文件
data "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.vm_image_storage
  node_name    = var.target_node
  file_name    = var.ubuntu_image_file_name
}

# 创建自定义 cloud-init user-data 文件
resource "proxmox_virtual_environment_file" "cloud_init_user_config" {
  content_type = "snippets"
  datastore_id = var.vm_snippets_storage
  node_name    = var.target_node

  source_raw {
    data = templatefile("${path.module}/user-data.tpl", {
      cloud_init_user          = var.cloud_init_user
      cloud_init_password      = var.cloud_init_password
      ssh_public_key           = var.ssh_public_key
      apt_mirror_url           = var.apt_mirror_url
      proxychains_socks5_entry = var.proxychains_socks5_entry
      enable_nvidia_driver     = var.enable_nvidia_driver
      nvidia_driver_version    = var.nvidia_driver_version
    })

    file_name = "user-data-vm-${var.vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name        = var.vm_name
  description = "Ubuntu 24.04 LTS VM${var.enable_gpu_passthrough ? " with RTX GPU passthrough" : ""}${var.enable_nvidia_driver ? " and NVIDIA driver ${var.nvidia_driver_version}-open" : ""} managed by Terraform"
  node_name   = var.target_node
  vm_id       = var.vm_id

  started = var.start_on_create

  # 启用 guest agent（在 cloud-init 中安装）
  agent {
    enabled = true
    timeout = "60s"
  }

  bios = "ovmf"

  machine = "q35"

  cpu {
    cores   = var.vm_cores
    sockets = var.vm_sockets
    type    = "host"
  }

  memory {
    dedicated = var.vm_memory
    floating  = var.vm_memory_balloon
  }

  # EFI 磁盘（UEFI 启动所需）
  efi_disk {
    datastore_id = var.vm_storage
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = var.vm_storage
    file_id      = data.proxmox_virtual_environment_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    discard      = "on"
    ssd          = true
    size         = var.vm_disk_size
  }

  initialization {
    datastore_id      = var.vm_storage
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_config.id

    ip_config {
      ipv4 {
        address = var.vm_ip_address != "" ? var.vm_ip_address : "dhcp"
        gateway = var.vm_gateway != "" ? var.vm_gateway : null
      }
    }

    # 不使用 user_account 块，因为用户账户已在 user_data_file_id 中定义
    # 同时定义会导致冲突

    dns {
      servers = [var.vm_nameserver]
    }
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  dynamic "hostpci" {
    for_each = var.enable_gpu_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      mapping = data.proxmox_virtual_environment_hardware_mapping_pci.gpu_mapping[0].name
      pcie    = true
      rombar  = true
      xvga    = false
    }
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  on_boot = true

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}
