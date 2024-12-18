#!/bin/sh

# hjdjsj husjsj
apk add curl && curl -Lo ubuntu-22.qcow2 https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img && apk add qemu qemu-img qemu-system-x86_64 qemu-ui-gtk && curl -Lo user-data https://raw.githubusercontent.com/Shivanshbrop/install.sh/refs/heads/main/user-data.txt

# 40 gb 
curl -Lo user-data.img https://github.com/Shivanshbrop/install.sh/raw/refs/heads/main/user-data.img && qemu-img resize ubuntu-22.qcow2 +10G && qemu-system-x86_64 -drive file=ubuntu-22.qcow2,format=qcow2 -drive file=user-data.img,format=raw -device virtio-net-pci,netdev=n0 -netdev user,id=n0 -m 40G -accel tcg -cpu qemu64 -nographic
