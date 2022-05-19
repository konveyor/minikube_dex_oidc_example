#!/bin/bash

command -v openssl >/dev/null 2>&1 || { echo >&2 "openssl is not installed.  Please install and continue."; exit 1; }


mkdir -p ssl

cat << EOF > ssl/req.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = dex.example.com
EOF

openssl genrsa -out ssl/ca-key.pem 4096
openssl req -x509 -new -nodes -sha256 -key ssl/ca-key.pem -days 365 -out ssl/ca.pem -subj "/CN=kube-ca"

openssl genrsa -out ssl/key.pem 4096
openssl req -new -key ssl/key.pem -out ssl/csr.pem -subj "/CN=kube-ca" -config ssl/req.cnf -sha256
openssl x509 -req -in ssl/csr.pem -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out ssl/cert.pem -days 365 -extensions v3_req -extfile ssl/req.cnf -sha256

echo "Check Signature Algorithm in csr.pem"
openssl req -verify -in ssl/csr.pem -text -noout

echo "Check Signature Algorithm for ca.pem"
openssl x509 -text -in ssl/ca.pem | grep "Signature Algorithm"  

echo "Check Signature Algorithm for cert.pem"
openssl x509 -text -in ssl/cert.pem | grep "Signature Algorithm"
