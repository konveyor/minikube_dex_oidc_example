#!/bin/sh

TEST_NAMESPACE="test"

if [[ -z "${MY_USERNAME}" ]]; then
  echo "Please ensure you have env var 'MY_USERNAME' defined before running."
  exit 1
fi

cat << EOF > ./sample_rbac_role_and_binding.yml
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
   namespace: ${TEST_NAMESPACE}
   name: test
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["deployments", "replicasets", "pods"]
  verbs: ["list", "get", "watch", "create", "update", "patch", "delete"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
   name: test-role-binding
   namespace: ${TEST_NAMESPACE}
subjects:
- kind: User
  name: ${MY_USERNAME}
  apiGroup: ""
roleRef:
  kind: Role
  name: test
  apiGroup: ""
EOF


echo "Creating '$TEST_NAMESPACE' namespace"
kubectl create namespace $TEST_NAMESPACE

echo "Apply RBAC resources for '${MY_USERNAME}'"
kubectl apply -f ./sample_rbac_role_and_binding.yml
