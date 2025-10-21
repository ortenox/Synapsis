#!/bin/bash

# ===========================================

# K8S SETUP SCRIPT

# Pre-installation → Point 1 (a,b,c)

# ===========================================

set -e # Hentikan jika ada error

# --------- [ PRE-INSTALLATION STAGE ] ---------

echo "[1] Update system & install dependencies"

sudo apt update -y

sudo apt upgrade -y

sudo apt install -y apt-transport-https ca-certificates curl gpg

echo "[2] Install containerd"

sudo apt install -y containerd

sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo systemctl restart containerd

sudo systemctl enable containerd

echo "[3] Disable swap (required by kubelet)"

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "[4] Load required kernel modules"

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf

overlay

br_netfilter

EOF

sudo modprobe overlay

sudo modprobe br_netfilter

# --------- [ CONFIGURE SYSCTL ] ---------

echo "[5] Setup sysctl params for Kubernetes networking"

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf

net.bridge.bridge-nf-call-iptables = 1

net.bridge.bridge-nf-call-ip6tables = 1

net.ipv4.ip_forward = 1

EOF

sudo sysctl --system

# --------- [ INSTALL KUBERNETES COMPONENTS ] ---------

echo "[6] Add Kubernetes repository"

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \

 | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \

https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \

 | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

sudo apt install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

# --------- [ POINT 1a: Initialize Cluster ] ---------

echo "[7] Initialize Kubernetes cluster (control-plane node)"

sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Simpan kubeconfig ke user biasa

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config

# --------- [ POINT 1b: Install Pod Network (Flannel) ] ---------

echo "[8] Deploy Flannel CNI"

kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kubeflannel.yml

# --------- [ POINT 1c: Securely distribute kubeconfig to developers ] ---------

echo "[9] Securely distribute kubeconfig"

# Contoh: buat salinan khusus untuk tim dev

DEV_KUBECONFIG=~/k8s-project/kubeconfig/dev-team/config

mkdir -p $(dirname $DEV_KUBECONFIG)

sudo cp /etc/kubernetes/admin.conf $DEV_KUBECONFIG

sudo chown $(id -u):$(id -g) $DEV_KUBECONFIG

# Encrypt sebelum dikirim via SFTP/SCP

tar czf - $DEV_KUBECONFIG | gpg -c > ~/k8s-project/kubeconfig/devteam/config.tar.gz.gpg

echo "File encrypted: ~/k8s-project/kubeconfig/dev-team/config.tar.gz.gpg"

echo "[10] To share securely via SCP:"

echo "scp ~/k8s-project/kubeconfig/dev-team/config.tar.gz.gpg 

developer@<server_ip>:/home/developer/"

echo "Developer will decrypt using: gpg -d config.tar.gz.gpg | tar xz"

echo " Setup complete!"
