#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Hungry Pod] Preparing incident..."

# --------------------------------------------------
# 1. Create the application namespace
# --------------------------------------------------

kubectl create namespace memory-app --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create a workload whose memory limit is far too
#    low for what it actually tries to allocate.
#    -> the container will be OOMKilled repeatedly,
#       causing CrashLoopBackOff.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-service
  namespace: memory-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache-service
  template:
    metadata:
      labels:
        app: cache-service
    spec:
      containers:
        - name: cache-service
          image: polinux/stress
          command: ["stress"]
          args: ["--vm", "1", "--vm-bytes", "150M", "--vm-hang", "1"]
          resources:
            requests:
              memory: "50Mi"
            limits:
              memory: "50Mi"
EOF

echo "[Hungry Pod] Incident planted."

exit 0
