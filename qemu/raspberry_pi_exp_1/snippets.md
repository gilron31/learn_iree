## What I did to setup

- install stuff

```
sudo apt install qemu-system-arm qemu-system-aarch64 qemu-utils
sudo apt install qemu-system qemu-utils
```

- run inside this folder

```
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2
```

- Create the login file

```
1️⃣ Install helper tool (on your host)
sudo apt install cloud-image-utils

2️⃣ Create a file user-data with this content:
#cloud-config
users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    plain_text_passwd: debian
    lock_passwd: false
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  list: |
    debian:debian
  expire: False

3️⃣ Create an empty meta-data file:
touch meta-data

4️⃣ Build the seed image:
cloud-localds seed.img user-data meta-data
```

- The final command line:

```
qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 2G -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd -drive if=virtio,file=debian-12-generic-arm64.qcow2 -drive file=seed.img,if=virtio -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0 -nographic
```

- And ssh `ssh -p 2222 debian@localhost`
