resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = var.vm_image_storage
  node_name    = var.target_node
  url          = var.ubuntu_image_url
  file_name    = "ubuntu-24.04-server-cloudimg-amd64.qcow2"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name        = var.vm_name
  description = "Ubuntu 24.04 LTS VM managed by Terraform"
  node_name   = var.target_node
  vm_id       = var.vm_id

  started = var.start_on_create

  agent {
    enabled = false
  }

  stop_on_destroy = true

  cpu {
    cores   = var.vm_cores
    sockets = var.vm_sockets
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = var.vm_storage
    import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.vm_disk_size
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.vm_ip_address != "" ? var.vm_ip_address : "dhcp"
        gateway = var.vm_gateway != "" ? var.vm_gateway : null
      }
    }

    user_account {
      username = var.cloud_init_user
      password = var.cloud_init_password != "" ? var.cloud_init_password : null
      keys     = var.ssh_public_key != "" ? [var.ssh_public_key] : []
    }

    dns {
      servers = [var.vm_nameserver]
    }
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}