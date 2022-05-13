#!/bin/sh

if [[ -z "${GITHUB_CLIENT_ID}" ]]; then
  echo "Please ensure you have env var 'GITHUB_CLIENT_ID' defined before running."
  exit 1
fi

if [[ -z "${GITHUB_CLIENT_SECRET}" ]]; then
  echo "Please ensure you have env var 'GITHUB_CLIENT_SECRET' defined before running."
  exit 1
fi

kubectl create namespace dex

kubectl -n dex create secret tls dex.example.com.tls --cert=ssl/cert.pem --key=ssl/key.pem

kubectl -n dex create secret \
    generic github-client \
    --from-literal=client-id=$GITHUB_CLIENT_ID \
    --from-literal=client-secret=$GITHUB_CLIENT_SECRET

kubectl create -f dex.yaml


