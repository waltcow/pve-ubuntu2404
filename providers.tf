terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_insecure

  # Alternatively, you can use API token authentication:
  # api_token = var.proxmox_api_token
  
  # SSH connection for some operations
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}