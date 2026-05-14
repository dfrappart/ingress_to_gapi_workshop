#!/bin/sh

# Generate CA Key

openssl genrsa -out ciliumsingle-ca.key 4096

# Generate CA Certificate

openssl req -x509 -new -nodes \
  -key ciliumsingle-ca.key \
  -sha256 \
  -days 3650 \
  -out ciliumsingle-ca.crt \
  -subj "/C=Fr/O=Dfitc/CN=CiliumSingle-CA"

# Create ciliumsingle Private Key

openssl genrsa -out ciliumsingle.key 4096

# Generate CSR

openssl req -new \
  -key ciliumsingle.key \
  -out ciliumsingle.csr \
  -config ciliumsingle-openssl.cnf

# Sign Certificate with CA

openssl x509 -req \
  -in ciliumsingle.csr \
  -CA ciliumsingle-ca.crt \
  -CAkey ciliumsingle-ca.key \
  -CAcreateserial \
  -out ciliumsingle.crt \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile ciliumsingle-openssl.cnf


  
  # Clean up

  mv ciliumsingle.crt ciliumsingle.key ciliumsingle-ca.crt ciliumsingle-ca.key ciliumsingle.csr ciliumsingle-ca.srl ../cert
