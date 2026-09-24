#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Reading Room] Preparing environment..."

# --------------------------------------------------
# 1. Create the two namespaces
# --------------------------------------------------

kubectl create namespace rbac-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace internal --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create the ServiceAccount. This is the only
#    authorization-related object that exists at the
#    start — no Role, RoleBinding, ClusterRole, or
#    ClusterRoleBinding is created for it.
# --------------------------------------------------

kubectl create serviceaccount report-reader \
  -n rbac-lab \
  --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 3. Create a ConfigMap and a Secret in rbac-lab, so
#    there's something real to read (and something
#    real that must stay off-limits).
# --------------------------------------------------

kubectl create configmap report-config \
  --from-literal=title="Quarterly Report" \
  -n rbac-lab \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic db-credentials \
  --from-literal=password=s3cr3t \
  -n rbac-lab \
  --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 4. Create report-api in rbac-lab, running as the
#    report-reader ServiceAccount.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-api
  namespace: rbac-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: report-api
  template:
    metadata:
      labels:
        app: report-api
    spec:
      serviceAccountName: report-reader
      containers:
        - name: report-api
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF

# --------------------------------------------------
# 5. Create a second, unrelated namespace and
#    workload. report-reader must never be able to
#    see or touch anything in here.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: internal-api
  namespace: internal
spec:
  replicas: 1
  selector:
    matchLabels:
      app: internal-api
  template:
    metadata:
      labels:
        app: internal-api
    spec:
      containers:
        - name: internal-api
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF

kubectl wait --for=condition=Ready pod -l app=report-api -n rbac-lab --timeout=90s
kubectl wait --for=condition=Ready pod -l app=internal-api -n internal --timeout=90s

echo "[Reading Room] Environment ready. No RBAC objects have been created yet."

exit 0
