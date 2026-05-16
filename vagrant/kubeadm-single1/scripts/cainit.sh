#!/bin/sh

# Generate CA Key

openssl genrsa -out k8ssingle1-ca.key 4096

# Generate CA Certificate

openssl req -x509 -new -nodes \
  -key k8ssingle1-ca.key \
  -sha256 \
  -days 3650 \
  -out k8ssingle1-ca.crt \
  -subj "/C=Fr/O=Dfitc/CN=k8ssingle1-CA"

# Create k8ssingle1 Private Key

openssl genrsa -out k8ssingle1.key 4096

# Generate CSR

openssl req -new \
  -key k8ssingle1.key \
  -out k8ssingle1.csr \
  -config k8ssingle1-openssl.cnf

# Sign Certificate with CA

openssl x509 -req \
  -in k8ssingle1.csr \
  -CA k8ssingle1-ca.crt \
  -CAkey k8ssingle1-ca.key \
  -CAcreateserial \
  -out k8ssingle1.crt \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile k8ssingle1-openssl.cnf


  
  # Clean up

  mv k8ssingle1.crt k8ssingle1.key k8ssingle1-ca.crt k8ssingle1-ca.key k8ssingle1.csr k8ssingle1-ca.srl ../cert
