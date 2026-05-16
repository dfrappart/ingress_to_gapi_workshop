#!/bin/sh

echo "Creating TLS secret for gundamapp"

kubectl create secret tls gundamapp-tls \
  --namespace gundam \
  --key <path_to_key_file> \
  --cert <path_to_cert_file>