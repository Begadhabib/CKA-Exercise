#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

NAMESPACE="shop-app"
DEPLOYMENT="checkout-service"
SERVICE="checkout-svc"

# 1. Deployment must be fully available (confirms image + config fixed)
READY=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
DESIRED=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$READY" != "$DESIRED" ] || [ -z "$READY" ]; then
  echo "Deployment $DEPLOYMENT is not fully ready ($READY/$DESIRED)"
  exit 1
fi

POD=$(kubectl get pods -n "$NAMESPACE" -l app=checkout-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD" ]; then
  echo "No Pod found for checkout-service"
  exit 1
fi

# 2. Pod must report Ready=True (confirms readiness probe fixed)
POD_READY=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [ "$POD_READY" != "True" ]; then
  echo "Pod $POD is not Ready"
  exit 1
fi

# 3. Pod must be stable (no restarts happening right now)
RESTARTS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
sleep 15
RESTARTS_AFTER=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
if [ "$RESTARTS_AFTER" != "$RESTARTS" ]; then
  echo "Pod $POD is still restarting ($RESTARTS -> $RESTARTS_AFTER)"
  exit 1
fi

# 4. Service must have at least one Endpoint
ENDPOINT=$(kubectl get endpoints "$SERVICE" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
if [ -z "$ENDPOINT" ]; then
  echo "Service $SERVICE has no endpoints"
  exit 1
fi

echo "Checkout is back online. Pod is Running, Ready, and serving traffic through the Service."
exit 0
