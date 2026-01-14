terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.92"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  api_token = var.proxmox_api_token

  ssh {
    username    = var.proxmox_ssh_username != "" ? var.proxmox_ssh_username : null
    private_key = var.proxmox_ssh_private_key_path != "" ? file(var.proxmox_ssh_private_key_path) : null
  }
}
