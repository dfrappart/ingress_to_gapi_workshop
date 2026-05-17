#!/bin/sh

echo "Installing Envoy Gateway CRDs"

helm template eg oci://docker.io/envoyproxy/gateway-crds-helm \
  --version v1.7.2 \
  --set crds.gatewayAPI.enabled=false \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side -f -

echo "Installing Envoy Gateway"

helm upgrade eg oci://docker.io/envoyproxy/gateway-helm \
  --install \
  --version v1.7.2 \
  -n envoy-gateway-system \
  --create-namespace \
  --skip-crds

