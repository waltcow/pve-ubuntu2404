#cloud-config
# 禁用 SSH 密码认证
ssh_pwauth: false
disable_root: true

users:
  - name: ${cloud_init_user}
    groups: [adm, cdrom, dip, plugdev, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) ALL
    lock_passwd: ${cloud_init_password != "" ? false : true}
    ssh_authorized_keys:
      - ${ssh_public_key}

%{if cloud_init_password != ""~}
# 设置用户密码（明文）
chpasswd:
  expire: false
  list:
    - ${cloud_init_user}:${cloud_init_password}
%{endif~}

apt:
  primary:
    - arches: [default]
      uri: ${apt_mirror_url}
  security:
    - arches: [default]
      uri: ${apt_mirror_url}

package_update: true
package_upgrade: false

packages:
  - qemu-guest-agent
  - build-essential
  - net-tools
  - dkms
  - linux-headers-generic
  - proxychains4

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
%{if proxychains_socks5_entry != ""~}
  - sed -i '/^socks4/d' /etc/proxychains4.conf
  - bash -c "grep -qF '${proxychains_socks5_entry}' /etc/proxychains4.conf || echo '${proxychains_socks5_entry}' >> /etc/proxychains4.conf"
%{endif~}
%{if enable_nvidia_driver~}
  - wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb
  - dpkg -i /tmp/cuda-keyring.deb
  - apt-get update
  - apt-get install -y nvidia-driver-${nvidia_driver_version}-open
  - rm -f /tmp/cuda-keyring.deb
  - echo "NVIDIA open driver ${nvidia_driver_version}-open installation completed at $(date)" >> /var/log/nvidia-install.log
  - shutdown -r +1 "Rebooting in 1 minute to load NVIDIA driver"
%{endif~}

final_message: "Cloud-Init 设置完成。${enable_nvidia_driver ? "NVIDIA 驱动已安装。系统将很快重启。" : "系统已就绪。"}"
