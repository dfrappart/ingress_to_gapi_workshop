#!/bin/sh

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx-again ingress-nginx/ingress-nginx \
  --namespace ingress-nginx-again \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.ingressClassResource.name="another-nginx"
