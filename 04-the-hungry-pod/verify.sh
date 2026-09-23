#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

NAMESPACE="memory-app"
DEPLOYMENT="cache-service"

# 1. Deployment must be fully available
READY=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
DESIRED=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$READY" != "$DESIRED" ] || [ -z "$READY" ]; then
  echo "Deployment $DEPLOYMENT is not fully ready ($READY/$DESIRED)"
  exit 1
fi

# 2. Pod must be stable (no restarts happening right now,
#    meaning it's no longer being OOMKilled)
POD=$(kubectl get pods -n "$NAMESPACE" -l app=cache-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
RESTARTS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)

sleep 20

RESTARTS_AFTER=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
if [ "$RESTARTS_AFTER" != "$RESTARTS" ]; then
  echo "Pod $POD is still restarting ($RESTARTS -> $RESTARTS_AFTER)"
  exit 1
fi

echo "Pod is fed. Memory limits are sufficient and the workload is stable."
exit 0
