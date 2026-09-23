#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

NAMESPACE="gate-app"
DEPLOYMENT="backend"
SERVICE="backend-svc"

# 1. Deployment must be fully available (this also confirms the
#    init container is no longer failing due to RBAC)
READY=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
DESIRED=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$READY" != "$DESIRED" ] || [ -z "$READY" ]; then
  echo "Deployment $DEPLOYMENT is not fully ready ($READY/$DESIRED)"
  exit 1
fi

# 2. Pod must be stable (no restarts happening right now)
POD=$(kubectl get pods -n "$NAMESPACE" -l app=backend-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD" ]; then
  POD=$(kubectl get pods -n "$NAMESPACE" -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

RESTARTS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
sleep 10
RESTARTS_AFTER=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
if [ "$RESTARTS_AFTER" != "$RESTARTS" ]; then
  echo "Pod $POD is still restarting ($RESTARTS -> $RESTARTS_AFTER)"
  exit 1
fi

# 3. Service must have at least one Endpoint (selector fixed)
ENDPOINTS=$(kubectl get endpoints "$SERVICE" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
if [ -z "$ENDPOINTS" ]; then
  echo "Service $SERVICE has no endpoints — selector still doesn't match the Pod's labels"
  exit 1
fi

# 4. End-to-end check: traffic actually reaches the backend
kubectl run gate-check --rm -i --restart=Never --image=busybox:1.36 -n "$NAMESPACE" \
  --command -- wget -qO- --timeout=5 "http://$SERVICE" > /tmp/gate-check-output 2>/dev/null

if ! grep -qi "html\|nginx\|Welcome" /tmp/gate-check-output; then
  echo "Could not reach $SERVICE from inside the cluster"
  exit 1
fi

echo "Gate opened. Backend is running, stable, and reachable through the Service."
exit 0
