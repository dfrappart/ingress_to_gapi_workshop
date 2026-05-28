#!/bin/sh

export POD_CIDR="100.65.0.0/16"
export K8SServiceHost="akslab1-jedrmydh.hcp.francecentral.azmk8s.io"
export K8SServicePort="443"
export K8SHostName="akslab1"
export RESOURCE_GROUP="rsg-cluster-aks"

helm template eg oci://docker.io/envoyproxy/gateway-crds-helm \
  --version v1.7.2 \
  --set crds.gatewayAPI.enabled=true \
  --set crds.gatewayAPI.channel=standard \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side -f -


helm upgrade cilium cilium/cilium \
    --install \
    --namespace kube-system \
    --reuse-values \
    --version "1.19.3" \
    --set kubeProxyReplacement=true \
    --set gatewayAPI.enabled=true \
    --set encryption.enabled=true \
    --set encryption.type=wireguard \
    --set enableProxyProtocol=true \
    --set hubble.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set k8sServiceHost=${K8SServiceHost} \
    --set k8sServicePort=${K8SServicePort} \
    --set ipam.operator.clusterPoolIPv4PodCIDRList=${POD_CIDR} \
    --set nodeinit.enabled=true \
    --set cluster.id=1 \
    --set cluster.name=${K8SHostName} \
    --set azure.resourceGroup=${RESOURCE_GROUP} 

helm upgrade eg oci://docker.io/envoyproxy/gateway-helm \
  --install \
  --version v1.7.2 \
  -n envoy-gateway-system \
  --create-namespace \
  --skip-crds

helm upgrade \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --install \
  --set "extraArgs={--enable-gateway-api}" \
  --values ./certmgmtvalue.yaml