#!/bin/sh

# Generate CA Key

openssl genrsa -out k8ssingle2-ca.key 4096

# Generate CA Certificate

openssl req -x509 -new -nodes \
  -key k8ssingle2-ca.key \
  -sha256 \
  -days 3650 \
  -out k8ssingle2-ca.crt \
  -subj "/C=Fr/O=Dfitc/CN=k8ssingle2-CA"

# Create k8ssingle2 Private Key

openssl genrsa -out k8ssingle2.key 4096

# Generate CSR

openssl req -new \
  -key k8ssingle2.key \
  -out k8ssingle2.csr \
  -config k8ssingle2-openssl.cnf

# Sign Certificate with CA

openssl x509 -req \
  -in k8ssingle2.csr \
  -CA k8ssingle2-ca.crt \
  -CAkey k8ssingle2-ca.key \
  -CAcreateserial \
  -out k8ssingle2.crt \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile k8ssingle2-openssl.cnf


  
  # Clean up

  mv k8ssingle2.crt k8ssingle2.key k8ssingle2-ca.crt k8ssingle2-ca.key k8ssingle2.csr k8ssingle2-ca.srl ../cert
