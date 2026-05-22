#!/bin/sh

helm repo add traefik https://traefik.github.io/charts
helm repo update
kubectl create namespace traefik

# 1) Generate a self‑signed certificate valid for *.docker.localhost
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=*.docker.localhost"

# 2) Create the TLS secret in the traefik namespace
kubectl create secret tls local-selfsigned-tls \
  --cert=tls.crt --key=tls.key \
  --namespace traefik

# 3) Install Traefik with the TLS secret

# Install the chart into the 'traefik' namespace
helm install traefik traefik/traefik \
  --namespace traefik \
  --values traefikvalues.yaml

