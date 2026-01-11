# Proxmox Ubuntu 24.04 VM with Terraform

This Terraform configuration creates an Ubuntu 24.04 LTS virtual machine on Proxmox VE using the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) provider.

## Features

- 🚀 Automated VM creation from Ubuntu 24.04 cloud image
- ☁️ Cloud-init configuration for initial setup
- 🔑 SSH key authentication support
- 🌐 Static IP or DHCP configuration
- 📦 Customizable CPU, memory, and disk resources
- 🔄 Automatic cloud image download from Ubuntu's official repository

## Prerequisites

1. **Proxmox VE** server (version 7.x or 8.x)
2. **Terraform** (version 1.0 or later) - [Install Terraform](https://developer.hashicorp.com/terraform/downloads)
3. **Proxmox credentials** with appropriate permissions
4. **Storage configured** on your Proxmox node (e.g., `local-lvm`)
5. **Network bridge** configured (e.g., `vmbr0`)

## Quick Start

### 1. Clone or Download This Configuration

Ensure you have all the Terraform files in your directory:
- `providers.tf`
- `variables.tf`
- `ubuntu2404.tf`
- `outputs.tf`

### 2. Create Your Variables File

Copy the example file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
# Your Proxmox connection details
proxmox_endpoint = "https://YOUR-PROXMOX-IP:8006"
proxmox_username = "root@pam"
proxmox_password = "your-password"

# VM settings
vm_name      = "ubuntu-web-server"
vm_id        = 100
target_node  = "pve"
vm_memory    = 4096
vm_cores     = 4

# Network (choose DHCP or static)
vm_ip_address = "192.168.1.100/24"  # or "" for DHCP
vm_gateway    = "192.168.1.1"       # or "" for DHCP

# SSH key for passwordless login
ssh_public_key = "ssh-rsa AAAAB3... your-key-here"
```

### 3. Initialize Terraform

```bash
terraform init
```

This downloads the Proxmox provider and prepares your workspace.

### 4. Review the Plan

```bash
terraform plan
```

This shows what resources will be created without making any changes.

### 5. Create the VM

```bash
terraform apply
```

Type `yes` when prompted. Terraform will:
1. Download the Ubuntu 24.04 cloud image to your Proxmox storage
2. Create the VM with your specified configuration
3. Configure cloud-init for first boot
4. Start the VM (if `start_on_create = true`)

### 6. Access Your VM

After creation, you can SSH into your VM:

```bash
# If using static IP
ssh ubuntu@192.168.1.100

# If using DHCP, check the output for the assigned IP
terraform output vm_ip_addresses
ssh ubuntu@<IP-ADDRESS>
```

## Configuration Options

### Proxmox Connection

| Variable | Description | Default |
|----------|-------------|---------|
| `proxmox_endpoint` | Proxmox API endpoint URL | - |
| `proxmox_username` | Proxmox username | `root@pam` |
| `proxmox_password` | Proxmox password | - |
| `proxmox_insecure` | Skip TLS verification | `true` |
| `proxmox_ssh_username` | SSH user for Proxmox host | `root` |

### VM Resources

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | VM name | `ubuntu-2404-vm` |
| `vm_id` | Unique VM ID | `100` |
| `target_node` | Proxmox node name | `pve` |
| `vm_memory` | RAM in MB | `2048` |
| `vm_cores` | CPU cores | `2` |
| `vm_sockets` | CPU sockets | `1` |
| `vm_disk_size` | Disk size (e.g., "32G") | `32G` |
| `vm_storage` | Storage pool | `local-lvm` |

### Network Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_bridge` | Network bridge | `vmbr0` |
| `vm_ip_address` | Static IP in CIDR notation or empty for DHCP | `""` (DHCP) |
| `vm_gateway` | Gateway IP | `""` |
| `vm_nameserver` | DNS server | `8.8.8.8` |

### Cloud-Init

| Variable | Description | Default |
|----------|-------------|---------|
| `cloud_init_user` | Default username | `ubuntu` |
| `cloud_init_password` | User password | `""` |
| `ssh_public_key` | SSH public key | `""` |
| `ubuntu_image_url` | Ubuntu cloud image URL | Ubuntu 24.04 official |

## Common Use Cases

### Create Multiple VMs

You can use Terraform workspaces or create separate directories:

```bash
# Using workspaces
terraform workspace new vm2
terraform apply -var="vm_name=ubuntu-vm2" -var="vm_id=101"
```

### Use API Token Instead of Password

Edit `providers.tf` to use API token authentication:

```hcl
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = "root@pam!mytoken=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  insecure  = var.proxmox_insecure
}
```

### Customize Cloud-Init

You can add custom cloud-init configuration by modifying the `initialization` block in `ubuntu2404.tf`.

## Outputs

After applying, Terraform provides useful information:

```bash
terraform output
```

Available outputs:
- `vm_id` - The VM ID in Proxmox
- `vm_name` - The VM name
- `vm_node` - The Proxmox node
- `vm_ip_addresses` - IP addresses assigned to the VM
- `vm_mac_addresses` - MAC addresses
- `vm_status` - Whether the VM is started

## Troubleshooting

### VM Not Getting IP Address

If using DHCP and the VM doesn't get an IP:
1. Ensure your network has a DHCP server
2. Wait a few minutes for cloud-init to complete
3. Check the Proxmox console: `Datacenter → Node → VM → Console`
4. Verify the qemu-guest-agent is running (may take a minute to start)

### Cloud Image Download Fails

If the Ubuntu image download fails:
1. Check your Proxmox node has internet access
2. Verify the storage pool has enough space
3. Try downloading manually and adjust the `ubuntu_image_url`

### Storage Pool Not Found

Ensure the storage pool exists in Proxmox:
```bash
pvesm status
```

Update `vm_storage` variable to match an available storage pool (e.g., `local`, `local-lvm`, `local-zfs`).

### SSH Connection Refused

If you can't SSH into the VM:
1. Ensure the VM has booted completely (check console)
2. Verify cloud-init has finished: `cloud-init status`
3. Check your SSH public key is correctly formatted in `terraform.tfvars`
4. Try logging in with password if configured

### Permission Denied

Ensure your Proxmox user has sufficient permissions. The user needs:
- VM.Allocate
- VM.Config.Disk
- VM.Config.Network
- Datastore.Allocate

## Cleaning Up

To destroy the VM and all associated resources:

```bash
terraform destroy
```

Type `yes` to confirm. This will delete the VM and the downloaded cloud image.

## Security Best Practices

1. **Never commit `terraform.tfvars`** - Add it to `.gitignore`
2. **Use SSH keys** instead of passwords when possible
3. **Use API tokens** instead of root password
4. **Enable TLS verification** in production (`proxmox_insecure = false`)
5. **Store sensitive variables** using environment variables or secret management:

```bash
export TF_VAR_proxmox_password="your-password"
export TF_VAR_cloud_init_password="vm-password"
terraform apply
```

## Additional Resources

- [Proxmox Provider Documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)

## License

This configuration is provided as-is for educational and production use.

## Contributing

Feel free to customize this configuration for your specific needs. Common improvements:
- Add more cloud-init customization
- Configure additional disks
- Set up multiple network interfaces
- Add tags and descriptions
- Implement VM templates

---

**Note**: The first `terraform apply` may take several minutes as it downloads the Ubuntu cloud image (~700MB) to your Proxmox storage. Subsequent VMs using the same image will be much faster.