output "vm_id" {
  description = "The ID of the created VM"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.id
}

output "vm_name" {
  description = "The name of the created VM"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.name
}

output "vm_node" {
  description = "The Proxmox node where the VM is running"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.node_name
}

output "vm_ip_addresses" {
  description = "The IP addresses assigned to the VM"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses
}

output "vm_mac_addresses" {
  description = "The MAC addresses of the VM's network interfaces"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.mac_addresses
}

output "vm_status" {
  description = "The current status of the VM"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.started
}