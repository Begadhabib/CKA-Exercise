#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

NAMESPACE="vault-app"
PVC="vault-pvc"
DEPLOYMENT="vault-writer"

# 1. PVC must be Bound
PVC_STATUS=$(kubectl get pvc "$PVC" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PVC_STATUS" != "Bound" ]; then
  echo "PVC $PVC is not Bound (status: $PVC_STATUS)"
  exit 1
fi

# 2. Deployment must be fully available
READY=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
DESIRED=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$READY" != "$DESIRED" ] || [ -z "$READY" ]; then
  echo "Deployment $DEPLOYMENT is not fully ready ($READY/$DESIRED)"
  exit 1
fi

# 3. Pod must be stable (no repeated restarts, meaning the
#    read-only mount issue has actually been fixed)
POD=$(kubectl get pods -n "$NAMESPACE" -l app=vault-writer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
RESTARTS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)

sleep 15

RESTARTS_AFTER=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
if [ "$RESTARTS_AFTER" != "$RESTARTS" ]; then
  echo "Pod $POD is still restarting ($RESTARTS -> $RESTARTS_AFTER)"
  exit 1
fi

echo "Vault restored. Storage is bound and the workload is stable."
exit 0
