#!/bin/sh

# Add current node in  /etc/hosts
echo "Adding current node in /etc/hosts"
echo "127.0.1.1 $(hostname)" >> /etc/hosts
echo "192.168.56.83 $(hostname)" >> /etc/hosts

# Install prerequisite
echo "apt config"


apt-get update

apt-get install -y apt-transport-https ca-certificates curl net-tools bat bash-completion jq yq

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Preparing Helm install"

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

echo "Installing helm"

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# enable kernel modules
echo "enable reqired module kernel"
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# ufw rules
echo "Ufw config"
ufw allow "OpenSSH"
ufw allow 6443/tcp
ufw allow 2379:2380/tcp
ufw allow 10250/tcp
ufw allow 10259/tcp
ufw allow 10257/tcp
ufw allow 30000:32767/tcp
ufw enable

# systemctl parameters
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# disable swap
echo "Disabling swap"
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
free -m

# install containerd
echo "Installing containerd"

apt-get install -y containerd.io
systemctl stop containerd

mv /etc/containerd/config.toml /etc/containerd/config.toml.orig
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# install kubeadm, kubelet and kubectl
echo "Installing kubeadm, kubelet and kubectl"
apt install kubelet kubeadm kubectl -y
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet  # enable kubelet service  
systemctl start kubelet   # start kubelet service

# update apparmor

echo "Updating apparmor"
apt install apparmor apparmor-utils -y

# install crictl
echo "Installing crictl"
CRICTL_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest | grep tag_name | cut -d '"' -f 4)
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-$CRICTL_VERSION-linux-amd64.tar.gz

tar zxvf crictl-$CRICTL_VERSION-linux-amd64.tar.gz -C /usr/local/bin
# Init kubeadm
echo "Initializing kubeadm on $(hostname)"
export controlplane=$(hostname)
kubeadm init --control-plane-endpoint=$controlplane --apiserver-advertise-address "192.168.56.83" --pod-network-cidr "100.64.0.0/16" --service-cidr "100.65.0.0/16" --skip-phases=addon/kube-proxy

# install trivy

echo "Initializing trivy on $(hostname)"
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy -y

# install cilium cli

echo "Initializing cilium cli on $(hostname)"

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

echo "Installing cilium hubble cli on $(hostname)"

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}


# Configuring swap disabled at boot with grub
echo "Configuring swap disabled at boot with grub"

sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet systemd.swap=0"/g' /etc/default/grub

grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub

update-grub