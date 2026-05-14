#!/bin/sh

echo "get config file for kubernetes"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# set completion for kubectl

echo "set completion for kubectl"
echo "source <(kubectl completion bash)" >> $HOME/.bashrc
echo "source <(helm completion bash)" >> $HOME/.bashrc

# set kubectl alias
echo "set kubectl alias"
echo "alias k=kubectl" >> $HOME/.bashrc
echo "complete -F __start_kubectl k" >> $HOME/.bashrc

# install gateway api prereq

echo "Installing Gateway API CRDs"

kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/monthly-2026.05/monthly-2026.05-install.yaml

echo "Installing calico API CRDs"

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/operator-crds.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/tigera-operator.yaml

echo "downloading calico config file"

curl https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/custom-resources.yaml -O

echo "updating calico config file"

sed -i 's/192.168.0.0\/16/100.64.0.0\/16/g' ./custom-resources.yaml

echo "applying calico config file"

kubectl apply -f ./custom-resources.yaml

echo "untainting the node before install"

kubectl taint node k8scalico1 node-role.kubernetes.io/control-plane:NoSchedule-

echo "Installing Envoy Gateway CRDs"

helm template eg oci://docker.io/envoyproxy/gateway-crds-helm \
  --version v1.7.3 \
  --set crds.gatewayAPI.enabled=false \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side -f -
  
echo "Installing Envoy Gateway"

helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.3 \
  -n envoy-gateway-system \
  --create-namespace \
  --skip-crds