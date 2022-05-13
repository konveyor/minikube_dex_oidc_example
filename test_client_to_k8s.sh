#!/bin/sh

if [[ -z "${MY_K8S_SERVER}" ]]; then
  echo "Please ensure you have env var 'MY_K8S_SERVER' defined before running."
  exit 1
fi

TEST_NAMESPACE="test"
curl -H "Authorization: Bearer ${DEX_TOKEN}" -k ${MY_K8S_SERVER}/api/v1/namespaces/${TEST_NAMESPACE}/pods

