# New Pi Setup

## 1. Install Image

- **Image:** Raspberry Pi OS Lite (64-bit) *(under "Other OS")*
- **Hostname:** `main` or `node-x`
- **Username:** `pi`
- **Password:** `password`

Plug USB into Pi and wait 3 minutes.

## 2. Configure Boot Parameters

Plug into PC and edit `cmdline.txt` — append to the end of the existing line:

```
cgroup_memory=1 cgroup_enable=memory
```

## 3. Set Up Master Node

SSH in and run:

```bash
sudo apt update -y
sudo apt upgrade -y
sudo mkdir -p /var/log/journal                                                                          
sudo systemctl restart systemd-journald                                                                 

sudo curl -sfL https://get.k3s.io | sh -
```

Grab the k3s token for worker nodes:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

## 4. Set Up Worker Nodes

Run on each worker node:

```bash
sudo apt update -y
sudo apt upgrade -y
sudo mkdir -p /var/log/journal                                                                          
sudo systemctl restart systemd-journald   
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.10:6443 K3S_TOKEN=<token> K3S_NODE_NAME="node-1" sh -
```
