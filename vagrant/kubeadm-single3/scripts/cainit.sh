#!/bin/sh

# Generate CA Key

openssl genrsa -out k8ssingle3-ca.key 4096

# Generate CA Certificate

openssl req -x509 -new -nodes \
  -key k8ssingle3-ca.key \
  -sha256 \
  -days 3650 \
  -out k8ssingle3-ca.crt \
  -subj "/C=Fr/O=Dfitc/CN=k8ssingle3-CA"

# Create k8ssingle3 Private Key

openssl genrsa -out k8ssingle3.key 4096

# Generate CSR

openssl req -new \
  -key k8ssingle3.key \
  -out k8ssingle3.csr \
  -config k8ssingle3-openssl.cnf

# Sign Certificate with CA

openssl x509 -req \
  -in k8ssingle3.csr \
  -CA k8ssingle3-ca.crt \
  -CAkey k8ssingle3-ca.key \
  -CAcreateserial \
  -out k8ssingle3.crt \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile k8ssingle3-openssl.cnf


  
  # Clean up

  mv k8ssingle3.crt k8ssingle3.key k8ssingle3-ca.crt k8ssingle3-ca.key k8ssingle3.csr k8ssingle3-ca.srl ../cert
