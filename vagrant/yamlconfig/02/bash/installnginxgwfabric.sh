#!/bin/sh

helm upgrade ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
--install \
--create-namespace \
-n nginx-gateway \
--set nginx.service.type=NodePort \
--set nginxGateway.gwAPIExperimentalFeatures.enable=true
