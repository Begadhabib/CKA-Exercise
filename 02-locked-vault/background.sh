#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Vault] Preparing incident..."

# --------------------------------------------------
# 1. Create the application namespace
# --------------------------------------------------

kubectl create namespace vault-app --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create a PersistentVolume with a capacity that
#    is deliberately too small for the claim below.
# --------------------------------------------------

mkdir -p /mnt/vault-data

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: vault-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/vault-data
EOF

# --------------------------------------------------
# 3. Create a PersistentVolumeClaim asking for more
#    storage than the PV above can provide.
#    -> PVC stays Pending, no bind is possible.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vault-pvc
  namespace: vault-app
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# --------------------------------------------------
# 4. Create the workload. It mounts the PVC above
#    read-only, even though the app writes to it.
#    -> once the PVC finally binds, the Pod will
#       still crash loop on every write attempt.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-writer
  namespace: vault-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault-writer
  template:
    metadata:
      labels:
        app: vault-writer
    spec:
      containers:
        - name: writer
          image: busybox:1.36
          command:
            - "sh"
            - "-c"
            - "while true; do echo \"$(date) - writing\" >> /data/log.txt; sleep 5; done"
          volumeMounts:
            - name: vault-storage
              mountPath: /data
              readOnly: true
      volumes:
        - name: vault-storage
          persistentVolumeClaim:
            claimName: vault-pvc
EOF

echo "[Vault] Incident planted."

exit 0
