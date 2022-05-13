mkdir -p ~/.minikube/files/var/lib/minikube/certs/ && \
 cp -a ./ssl/* ~/.minikube/files/var/lib/minikube/certs/

mkdir -p ~/.minikube/files/etc
cat << EOF > ~/.minikube/files/etc/hosts 
127.0.0.1       localhost
255.255.255.255	broadcasthost
::1             localhost

${MY_MINIKUBE_IP} dex.example.com
EOF

minikube start --v=5 --vm-driver=docker --memory=4096 \
--extra-config=apiserver.authorization-mode=Node,RBAC \
--extra-config=apiserver.oidc-issuer-url=https://dex.example.com:32000 \
--extra-config=apiserver.oidc-username-claim=email \
--extra-config=apiserver.oidc-ca-file=/var/lib/minikube/certs/ca.pem \
--extra-config=apiserver.oidc-client-id=example-app \
--extra-config=apiserver.oidc-groups-claim=groups
