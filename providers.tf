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

  # Use API token if provided, otherwise use username/password
  api_token = var.proxmox_api_token != "" ? var.proxmox_api_token : null
  username  = var.proxmox_api_token == "" ? var.proxmox_username : null
  password  = var.proxmox_api_token == "" ? var.proxmox_password : null

  # SSH connection for some operations
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
    # 如果 ssh-agent 不可用，可以指定私钥路径
    # private_key = file("~/.ssh/id_rsa")
  }
}