#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

NAMESPACE="dragon-app"
DEPLOYMENT="frontend"
K="kubectl --request-timeout=10s"

fail() {
  echo "FAILED: $1"
  exit 1
}

# --------------------------------------------------
# 1. The API server must be answering and healthy
#    (/readyz also covers the apiserver -> etcd link)
# --------------------------------------------------

if ! $K get --raw='/readyz' >/dev/null 2>&1; then
  fail "The Kubernetes API is not healthy yet."
fi

# --------------------------------------------------
# 2. Every control-plane component must be Ready
# --------------------------------------------------

for COMPONENT in etcd kube-apiserver kube-controller-manager kube-scheduler; do
  READY=$($K get pods -n kube-system -l component="$COMPONENT" \
    -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [ "$READY" != "True" ]; then
    fail "One or more control-plane components are not healthy yet."
  fi
done

# --------------------------------------------------
# 3. Integrity: the workload must still be the original
#    Deployment, not a deleted/recreated stand-in
# --------------------------------------------------

IMAGE=$($K get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
DESIRED=$($K get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null)

if [ -z "$IMAGE" ]; then
  fail "Deployment '$DEPLOYMENT' is missing from '$NAMESPACE'."
fi
if [ "$IMAGE" != "nginx:1.27" ] || [ "$DESIRED" != "2" ]; then
  fail "Deployment '$DEPLOYMENT' has been changed beyond what this challenge requires."
fi

# The workload should keep a CPU request; removing it is a shortcut
CPU_REQUEST=$($K get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
if [ -z "$CPU_REQUEST" ]; then
  fail "The workload should keep a CPU request, just a realistic one."
fi

# --------------------------------------------------
# 4. All replicas must become ready (allow time for the
#    controller-manager to roll out and pods to start)
# --------------------------------------------------

for i in $(seq 1 18); do
  READY_REPLICAS=$($K get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  UPDATED=$($K get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
  TOTAL=$($K get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.status.replicas}' 2>/dev/null)

  if [ "$READY_REPLICAS" == "$DESIRED" ] && [ "$UPDATED" == "$DESIRED" ] && [ "$TOTAL" == "$DESIRED" ]; then
    echo "The dragon is tamed. The control plane is healthy and the application is fully available."
    exit 0
  fi
  sleep 5
done

fail "The application is not fully available yet ($READY_REPLICAS/$DESIRED ready)."
