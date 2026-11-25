#!/bin/bash
# Scenario 11 - The Missing Configuration
NS="missing-config"
rm -f /tmp/.scenario-ready /tmp/.orders-deploy-uid

echo "Waiting for the cluster..."
until kubectl get nodes >/dev/null 2>&1; do sleep 2; done
kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null 2>&1

# Idempotent: the namespace is dedicated to this scenario
kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1
kubectl create namespace "$NS" >/dev/null

# Handover notes left by the platform team
mkdir -p /root/handover
cat > /root/handover/db-handover.txt <<'NOTES'
Platform team handover - orders-api
-----------------------------------
Orders DB host      : orders-db.internal (already in ConfigMap orders-config)
DB service account  : orders_svc
DB password         : S3cure-Pa55-2026   (rotated on Monday)
These credentials are NOT stored in git.
NOTES

# ---- Phase 1: a healthy application ----------------------------------------
kubectl -n "$NS" create secret generic orders-db-credentials \
  --from-literal=username=orders_svc \
  --from-literal=password='S3cure-Pa55-2026' >/dev/null
kubectl -n "$NS" create configmap orders-config \
  --from-literal=db_host=orders-db.internal >/dev/null

kubectl -n "$NS" apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
  labels:
    app: orders-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orders-api
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
      - name: orders-api
        image: nginx:1.27-alpine
        command: ["/bin/sh", "-c"]
        args:
        - |
          if [ -z "$DB_PASSWORD" ]; then
            echo "DB_PASSWORD is empty, refusing to start"
            exit 1
          fi
          echo "orders-api ok (db=$DB_HOST user=$DB_USER)" > /usr/share/nginx/html/healthz
          exec nginx -g 'daemon off;'
        ports:
        - containerPort: 80
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: orders-config
              key: db_host
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: orders-db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: orders-db-credentials
              key: password
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          periodSeconds: 3
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
---
apiVersion: v1
kind: Service
metadata:
  name: orders-api
spec:
  selector:
    app: orders-api
  ports:
  - port: 80
    targetPort: 80
YAML

kubectl -n "$NS" rollout status deployment/orders-api --timeout=240s >/dev/null
kubectl -n "$NS" get deployment orders-api -o jsonpath='{.metadata.uid}' > /tmp/.orders-deploy-uid

# ---- Phase 2: the incident -------------------------------------------------
# The Secret disappears (e.g. namespace cleanup job) and the Pods get rescheduled.
kubectl -n "$NS" delete secret orders-db-credentials >/dev/null
kubectl -n "$NS" delete pods -l app=orders-api --wait=true >/dev/null

for i in $(seq 1 60); do
  n=$(kubectl -n "$NS" get pods -l app=orders-api \
      -o jsonpath='{range .items[*]}{.status.containerStatuses[0].state.waiting.reason}{"\n"}{end}' \
      2>/dev/null | grep -c CreateContainerConfigError)
  [ "$n" -ge 2 ] && break
  sleep 2
done

echo "=== Incident environment ready ==="
kubectl -n "$NS" get deploy,pods,svc
touch /tmp/.scenario-ready
