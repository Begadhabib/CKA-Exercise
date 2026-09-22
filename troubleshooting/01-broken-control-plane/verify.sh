#!/bin/bash

set -u

export KUBECONFIG=/etc/kubernetes/admin.conf

fail() {
    echo ""
    echo "❌ CHALLENGE FAILED"
    echo "$1"
    exit 1
}

echo "======================================"
echo "     DRAGON FINAL VALIDATION"
echo "======================================"

# --------------------------------------------------
# API server
# --------------------------------------------------

kubectl get --raw=/readyz >/dev/null 2>&1 \
    || fail "Kubernetes API server is not healthy."

echo "✓ API server healthy"

# --------------------------------------------------
# etcd
# --------------------------------------------------

ETCD_ENDPOINT=$(grep -oE 'https://127\.0\.0\.1:[0-9]+' \
    /etc/kubernetes/manifests/kube-apiserver.yaml \
    | head -1)

[ "$ETCD_ENDPOINT" = "https://127.0.0.1:2379" ] \
    || fail "kube-apiserver is still using the wrong etcd endpoint."

echo "✓ kube-apiserver -> etcd endpoint correct"

# --------------------------------------------------
# Scheduler
# --------------------------------------------------

kubectl -n kube-system get pod \
    -l component=kube-scheduler \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null \
    | grep -q Running \
    || fail "kube-scheduler is not Running."

echo "✓ kube-scheduler running"

# --------------------------------------------------
# Controller Manager
# --------------------------------------------------

kubectl -n kube-system get pod \
    -l component=kube-controller-manager \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null \
    | grep -q Running \
    || fail "kube-controller-manager is not Running."

echo "✓ kube-controller-manager running"

# --------------------------------------------------
# Node
# --------------------------------------------------

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

READY=$(kubectl get node "$NODE" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

[ "$READY" = "True" ] \
    || fail "Node is not Ready."

echo "✓ Node Ready"

# --------------------------------------------------
# Application
# --------------------------------------------------

kubectl -n dragon-app get deployment frontend >/dev/null 2>&1 \
    || fail "Frontend deployment is missing."

READY_REPLICAS=$(kubectl -n dragon-app get deployment frontend \
    -o jsonpath='{.status.readyReplicas}')

[ "${READY_REPLICAS:-0}" = "1" ] \
    || fail "Frontend is not Ready."

echo "✓ Frontend healthy"

# --------------------------------------------------
# Diagnostic workload must be schedulable
# --------------------------------------------------

PHASE=$(kubectl -n dragon-app get pod diagnostic-pod \
    -o jsonpath='{.status.phase}' 2>/dev/null)

[ "$PHASE" = "Running" ] \
    || fail "Diagnostic workload is still not running."

echo "✓ Workload schedulable"

echo ""
echo "======================================"
echo "       🐉 DRAGON DEFEATED"
echo "======================================"
echo ""
echo "All validation checks passed."
echo ""

exit 0