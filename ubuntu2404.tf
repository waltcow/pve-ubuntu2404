# 创建 GPU Resource Mapping
resource "proxmox_virtual_environment_hardware_mapping_pci" "gpu_mapping" {
  count   = var.enable_gpu_passthrough ? 1 : 0
  name    = "gpu"
  comment = "RTX 5090 GPU mapping for Terraform VMs"

  map = [
    {
      comment      = "Gigabyte RTX 5090 on ${var.target_node}"
      id           = var.gpu_device_id
      iommu_group  = var.gpu_iommu_group
      node         = var.target_node
      path         = var.gpu_pci_path
      subsystem_id = var.gpu_subsystem_id
    }
  ]
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
    data = <<EOF
#cloud-config
# 禁用 SSH 密码认证
ssh_pwauth: false
disable_root: true

users:
  - name: ${var.cloud_init_user}
    groups: [adm, cdrom, dip, plugdev, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) ALL
    lock_passwd: ${var.cloud_init_password != "" ? false : true}
    ssh_authorized_keys:
      - ${var.ssh_public_key}

%{if var.cloud_init_password != "" ~}
# 设置用户密码（明文）
chpasswd:
  expire: false
  list:
    - ${var.cloud_init_user}:${var.cloud_init_password}
%{endif ~}

apt:
  primary:
    - arches: [default]
      uri: ${var.apt_mirror_url}
  security:
    - arches: [default]
      uri: ${var.apt_mirror_url}

package_update: true
package_upgrade: false

packages:
  - qemu-guest-agent
  - build-essential
  - dkms
  - linux-headers-generic

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
%{if var.enable_nvidia_driver ~}
  - wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb
  - dpkg -i /tmp/cuda-keyring.deb
  - apt-get update
  - apt-get install -y nvidia-driver-${var.nvidia_driver_version}-open
  - rm -f /tmp/cuda-keyring.deb
  - echo "NVIDIA open driver ${var.nvidia_driver_version}-open installation completed at $(date)" >> /var/log/nvidia-install.log
  - shutdown -r +1 "Rebooting in 1 minute to load NVIDIA driver"
%{endif ~}

final_message: "Cloud-Init 设置完成。${var.enable_nvidia_driver ? "NVIDIA 驱动已安装。系统将很快重启。" : "系统已就绪。"}"
EOF

    file_name = "user-data-vm-${var.vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name        = var.vm_name
  description = "Ubuntu 24.04 LTS VM ${var.enable_nvidia_driver ? "with NVIDIA driver " : ""}managed by Terraform"
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
      mapping = proxmox_virtual_environment_hardware_mapping_pci.gpu_mapping[0].name
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
