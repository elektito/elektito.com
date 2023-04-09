# elektito.com config

This repository contains the configuration and the scripts to setup elektito.com website and gemini capsule. The configuration has been tested on Ubuntu 22.04.

You are going to need a certificate. For a first time setup, you can use the following command to generate a 10-year valid self-signed certificate:

``` sh
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 3650 -nodes -addext "subjectAltName = DNS:elektito.com"
```

The script expects the `key.pem` and `cert.pem` files to be present in the working directory.

# qemu test

Create a `metadata.yaml` file with contents like this:

``` yaml
instance-id: test-vm1
local-hostname: cloudimg
```

Create a `user-data.yaml` file with contents like this:

``` yaml
#cloud-config
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7MGk+L1Gy3V6sVXNQs5vnSXWGTgqN7lAxSM3nz6Q1yKrpABRrS9Mk++5Cn9vxraW9O/Rw/DsUROL5K5QTDQiaOu09bz4nbyQzXu/TGMQdO1ceaYxylefJ5w4pjiXR+Zrxux6Z7ZfsdT1BSeR4xoezLwfOdG8f5ewlcZQbpxldWqOEUkwihpOxl+3PFyOpqjP1utLjxTLLKcM9xQ9CMj7VvquP/5oTlWWbZToUp3lpenju9VLGVJ5WbtadNdY3J3e9xp7zaZHWWGdHy3VZU6YT8/PDsP57UV6lFWG452Pkyrr9TLmxXNZKYriEye9VQN3f5dXluZ5MsDAfpNemj9Bf mostafa@elektito
mounts:
  - [ shared0, /mnt, "9p", "trans=virtio,version=9p2000.L"]
```

Create seed image:

``` sh
cloud-localds seed.img user-data.yaml metadata.yaml
```

Download base image:

``` sh
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

Create disk image:

``` sh
qemu-img create -f qcow2 -F qcow2 -b jammy-server-cloudimg-amd64.img foo.qcow2
```

Run qemu (fix shared directory path in `-virtfs` option, and possibly the `security_model`):

``` sh
qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host \
    -m 2G \
    -nographic \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -drive if=virtio,format=qcow2,file=foo.qcow2 \
    -drive if=virtio,format=raw,file=seed.img \
    -virtfs local,path=/home/mostafa/source/elektito.com/,mount_tag=shared0,security_model=mapped-xattr,id=shared0 \
    -snapshot 
```

You can then ssh into the machine using:

``` sh
ssh -p 2222 ubuntu@0.0.0.0
```
