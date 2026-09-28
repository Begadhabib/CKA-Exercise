#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

MANIFESTS="/etc/kubernetes/manifests"
BACKUP="/var/lib/dragon-return-backup"

echo "[Dragon Return] Preparing incident..."

mkdir -p "$BACKUP"

# --------------------------------------------------
# 1. Create the application namespace and workload.
#
#    Fault #2 lives here: the CPU values are written
#    as whole cores ("500" / "1000") instead of
#    millicores ("500m" / "1000m"), so no node can
#    ever satisfy the request.
# --------------------------------------------------

kubectl create namespace dragon-app --dry-run=client -o yaml | kubectl apply -f -

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: dragon-app
spec:
  replicas: 2
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
              cpu: "500"
            limits:
              cpu: "1000"
EOF

# --------------------------------------------------
# 2. Wait until the ReplicaSet has created its Pods,
#    so the workload exists before the control plane
#    is broken.
# --------------------------------------------------

for i in $(seq 1 30); do
  COUNT=$(kubectl get pods -n dragon-app --no-headers 2>/dev/null | wc -l)
  if [ "$COUNT" -ge 2 ]; then
    break
  fi
  sleep 2
done

# --------------------------------------------------
# 3. Fault #3: kube-controller-manager gets a wrong
#    path for the service-account signing key.
#    The file lives at pki/sa.key; the manifest now
#    points at pki/sa.pem, which does not exist, so
#    the controller-manager crashes on startup and
#    nothing (ReplicaSets, rollouts...) gets reconciled.
# --------------------------------------------------

CM_MANIFEST="$MANIFESTS/kube-controller-manager.yaml"

cp "$CM_MANIFEST" "$BACKUP/kube-controller-manager.yaml"

sed -i \
's#--service-account-private-key-file=/etc/kubernetes/pki/sa.key#--service-account-private-key-file=/etc/kubernetes/pki/sa.pem#' \
"$CM_MANIFEST"

if ! grep -q 'pki/sa.pem' "$CM_MANIFEST"; then
  echo "[Dragon Return] ERROR: could not plant the controller-manager fault."
  exit 1
fi

# --------------------------------------------------
# 4. Fault #1: kube-apiserver -> etcd connectivity.
#    Done last, because once the API server stops
#    answering nothing else can be prepared via kubectl.
# --------------------------------------------------

API_MANIFEST="$MANIFESTS/kube-apiserver.yaml"

cp "$API_MANIFEST" "$BACKUP/kube-apiserver.yaml"

sed -i \
's#--etcd-servers=https://127.0.0.1:2379#--etcd-servers=https://127.0.0.1:2380#' \
"$API_MANIFEST"

if ! grep -q '127.0.0.1:2380' "$API_MANIFEST"; then
  echo "[Dragon Return] ERROR: could not plant the apiserver fault."
  exit 1
fi

echo "[Dragon Return] Incident planted."

exit 0
