#!/bin/sh

# Generate CA Key

openssl genrsa -out cndromania-ca.key 4096

# Generate CA Certificate

openssl req -x509 -new -nodes \
  -key cndromania-ca.key \
  -sha256 \
  -days 3650 \
  -out cndromania-ca.crt \
  -subj "/C=Fr/O=Dfitc/CN=cndromania-CA"

# Create cndromania Private Key

openssl genrsa -out cndromania.key 4096

# Generate CSR

openssl req -new \
  -key cndromania.key \
  -out cndromania.csr \
  -config cndromania-openssl.cnf

# Sign Certificate with CA

openssl x509 -req \
  -in cndromania.csr \
  -CA cndromania-ca.crt \
  -CAkey cndromania-ca.key \
  -CAcreateserial \
  -out cndromania.crt \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile cndromania-openssl.cnf


  
  # Clean up

  mv cndromania.crt cndromania.key cndromania-ca.crt cndromania-ca.key cndromania.csr cndromania-ca.srl ../cert
