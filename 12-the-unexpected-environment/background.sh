#!/bin/bash
# Scenario 12 - The Unexpected Environment
NS="unexpected-env"
rm -f /tmp/.scenario-ready /tmp/.backend-deploy-uid

echo "Waiting for the cluster..."
until kubectl get nodes >/dev/null 2>&1; do sleep 2; done
kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null 2>&1

# Idempotent: the namespace is dedicated to this scenario
kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1
kubectl create namespace "$NS" >/dev/null

# ---- Supporting service: inventory (created BEFORE the backend) -------------
kubectl -n "$NS" apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  labels:
    app: inventory
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inventory
  template:
    metadata:
      labels:
        app: inventory
    spec:
      containers:
      - name: inventory
        image: nginx:1.27-alpine
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "inventory-service-online" > /usr/share/nginx/html/index.html
          exec nginx -g 'daemon off;'
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
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
  name: inventory
spec:
  selector:
    app: inventory
  ports:
  - port: 80
    targetPort: 80
YAML
kubectl -n "$NS" rollout status deployment/inventory --timeout=240s >/dev/null

# ---- Phase 1: a working backend (default Service links behaviour) ----------
kubectl -n "$NS" apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: busybox:1.36
        command: ["/bin/sh", "-c"]
        args:
        - |
          URL="${INVENTORY_URL:-}"
          if [ -z "$URL" ] && [ -n "${INVENTORY_SERVICE_HOST:-}" ]; then
            URL="http://${INVENTORY_SERVICE_HOST}:${INVENTORY_SERVICE_PORT:-80}"
          fi
          if [ -z "$URL" ]; then
            echo "backend: no inventory endpoint configured (INVENTORY_URL and INVENTORY_SERVICE_HOST are unset)" >&2
            exit 1
          fi
          echo "backend: using inventory endpoint $URL"
          mkdir -p /www
          echo starting > /www/status
          (
            while true; do
              if wget -q -T 2 -O- "$URL" 2>/dev/null | grep -q inventory-service-online; then
                echo ok > /www/status
              else
                echo fail > /www/status
              fi
              sleep 3
            done
          ) &
          exec httpd -f -p 8080 -h /www
        ports:
        - containerPort: 8080
        readinessProbe:
          exec:
            command: ["sh", "-c", "grep -qx ok /www/status"]
          periodSeconds: 3
        resources:
          requests:
            cpu: 10m
            memory: 8Mi
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
YAML
kubectl -n "$NS" rollout status deployment/backend --timeout=240s >/dev/null
kubectl -n "$NS" get deployment backend -o jsonpath='{.metadata.uid}' > /tmp/.backend-deploy-uid

# ---- Phase 2: the "configuration change" ------------------------------------
kubectl -n "$NS" patch deployment backend --type=merge \
  -p '{"spec":{"template":{"spec":{"enableServiceLinks":false}}}}' >/dev/null

# Wait until the new Pod has started failing
for i in $(seq 1 60); do
  n=$(kubectl -n "$NS" get pods -l app=backend \
      -o jsonpath='{range .items[*]}{.status.containerStatuses[0].state.waiting.reason}{"\n"}{end}' \
      2>/dev/null | grep -c -E 'CrashLoopBackOff|Error')
  [ "$n" -ge 1 ] && break
  sleep 2
done

echo "=== Incident environment ready ==="
kubectl -n "$NS" get deploy,pods,svc
touch /tmp/.scenario-ready
