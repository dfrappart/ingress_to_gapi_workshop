#!/bin/sh

# Generate CA Key

openssl genrsa -out ListenerSet-ca.key 4096

# Generate CA Certificate

openssl req -x509 -new -nodes \
  -key ListenerSet-ca.key \
  -sha256 \
  -days 3650 \
  -out ListenerSet-ca.crt \
  -subj "/C=Fr/O=Dfitc/CN=ListenerSet-CA"

# Create ListenerSet Private Key

openssl genrsa -out ListenerSet.key 4096

# Generate CSR

openssl req -new \
  -key ListenerSet.key \
  -out ListenerSet.csr \
  -config ListenerSet-openssl.cnf

# Sign Certificate with CA

openssl x509 -req \
  -in ListenerSet.csr \
  -CA ListenerSet-ca.crt \
  -CAkey ListenerSet-ca.key \
  -CAcreateserial \
  -out ListenerSet.crt \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile ListenerSet-openssl.cnf

# Create Gateway Private Key

openssl genrsa -out Gateway.key 4096

# Generate CSR

openssl req -new \
  -key Gateway.key \
  -out Gateway.csr \
  -config Gateway-openssl.cnf

# Sign Certificate with CA

openssl x509 -req \
  -in Gateway.csr \
  -CA ListenerSet-ca.crt \
  -CAkey ListenerSet-ca.key \
  -CAcreateserial \
  -out Gateway.crt \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile Gateway-openssl.cnf
  
  # Clean up

  mv ListenerSet.crt ListenerSet.key ListenerSet-ca.crt ListenerSet-ca.key ListenerSet.csr ListenerSet-ca.srl Gateway.crt Gateway.key Gateway.csr ../cert
