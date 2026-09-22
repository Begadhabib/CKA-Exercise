#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Dragon] Preparing incident..."

# --------------------------------------------------
# 1. Create the application namespace
# --------------------------------------------------

kubectl create namespace dragon-app --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create a normal workload
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: dragon-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: nginx:1.27
          resources:
            requests:
              cpu: "3000"
            limits:
              cpu: "3000"
EOF

# --------------------------------------------------
# 3. Create a second normal workload
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: diagnostic-pod
  namespace: dragon-app
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      resources:
        requests:
          cpu: "3000"
        limits:
          cpu: "3000"
EOF

# --------------------------------------------------
# 4. Wait for the API to be available
# --------------------------------------------------

sleep 5

# --------------------------------------------------
# 5. Break kube-apiserver -> etcd connectivity
# --------------------------------------------------

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

cp "$APISERVER_MANIFEST" \
   /root/kube-apiserver.yaml.dragon-backup

sed -i \
  's/127\.0\.0\.1:2379/127.0.0.1:2380/g' \
  "$APISERVER_MANIFEST"

echo "[Dragon] Incident planted."

exit 0