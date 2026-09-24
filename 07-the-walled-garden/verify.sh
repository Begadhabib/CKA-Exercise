#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

NAMESPACE="netpol-app"
FAIL_MSG=""

fail() {
  echo "FAILED: $1"
  exit 1
}

# --------------------------------------------------
# 0. Integrity checks — block obvious shortcuts
# --------------------------------------------------

# Workloads must still exist and be ready (no deleting your way out)
for DEP in frontend backend database unrelated; do
  READY=$(kubectl get deployment "$DEP" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  DESIRED=$(kubectl get deployment "$DEP" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ -z "$DESIRED" ]; then
    fail "Deployment '$DEP' is missing. This challenge does not require deleting or recreating existing workloads."
  fi
  if [ "$READY" != "$DESIRED" ]; then
    fail "Deployment '$DEP' is not fully ready ($READY/$DESIRED)."
  fi
done

# Services must be unchanged (selector + port), so the "blocked" pairs
# can't be bypassed by quietly moving the app to a different port
BACKEND_SELECTOR=$(kubectl get svc backend-svc -n "$NAMESPACE" -o jsonpath='{.spec.selector.app}' 2>/dev/null)
BACKEND_PORT=$(kubectl get svc backend-svc -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
DATABASE_SELECTOR=$(kubectl get svc database-svc -n "$NAMESPACE" -o jsonpath='{.spec.selector.app}' 2>/dev/null)
DATABASE_PORT=$(kubectl get svc database-svc -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)

if [ "$BACKEND_SELECTOR" != "backend" ] || [ "$BACKEND_PORT" != "8080" ]; then
  fail "backend-svc has been modified. Services and ports must not be changed for this challenge."
fi
if [ "$DATABASE_SELECTOR" != "database" ] || [ "$DATABASE_PORT" != "5432" ]; then
  fail "database-svc has been modified. Services and ports must not be changed for this challenge."
fi

# --------------------------------------------------
# 1. Connectivity tests
# --------------------------------------------------

# check_conn <from-deploy> <target-url> <expect: allow|deny>
check_conn() {
  local FROM="$1"
  local URL="$2"
  local EXPECT="$3"
  local ATTEMPTS
  local RESULT

  if [ "$EXPECT" == "allow" ]; then
    ATTEMPTS=5
  else
    ATTEMPTS=1
  fi

  for i in $(seq 1 "$ATTEMPTS"); do
    if kubectl exec -n "$NAMESPACE" "deploy/$FROM" -- wget -qO- -T 3 "$URL" >/tmp/netpol-check-out 2>/dev/null; then
      RESULT="success"
    else
      RESULT="failure"
    fi

    if [ "$EXPECT" == "allow" ] && [ "$RESULT" == "success" ]; then
      return 0
    fi
    if [ "$EXPECT" == "deny" ] && [ "$RESULT" == "failure" ]; then
      return 0
    fi

    sleep 3
  done

  return 1
}

check_conn frontend "http://backend-svc:8080" "allow" \
  || fail "frontend cannot reach backend, but it should be able to."

check_conn backend "http://database-svc:5432" "allow" \
  || fail "backend cannot reach database, but it should be able to."

check_conn frontend "http://database-svc:5432" "deny" \
  || fail "frontend can reach database, but it should not be able to."

check_conn unrelated "http://database-svc:5432" "deny" \
  || fail "unrelated can reach database, but it should not be able to."

echo "All four connectivity requirements are satisfied. The garden's walls are in the right places."
exit 0
