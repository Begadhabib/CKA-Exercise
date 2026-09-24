#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

IDENTITY="system:serviceaccount:rbac-lab:report-reader"
FAILURES=0

fail() {
  echo "FAILED: $1"
  FAILURES=$((FAILURES + 1))
}

can_i() {
  # $1=verb $2=resource $3=namespace (empty for cluster-scoped)
  if [ -n "$3" ]; then
    kubectl auth can-i "$1" "$2" -n "$3" --as="$IDENTITY" 2>/dev/null
  else
    kubectl auth can-i "$1" "$2" --as="$IDENTITY" 2>/dev/null
  fi
}

expect_yes() {
  local result
  result=$(can_i "$1" "$2" "$3")
  if [ "$result" != "yes" ]; then
    fail "$IDENTITY should be able to $1 $2${3:+ in $3}, but cannot."
  fi
}

expect_no() {
  local result
  result=$(can_i "$1" "$2" "$3")
  if [ "$result" != "no" ]; then
    fail "$IDENTITY should NOT be able to $1 $2${3:+ in $3}, but can."
  fi
}

# --------------------------------------------------
# 0. Integrity checks — nothing should have been
#    deleted or renamed to dodge the requirements
# --------------------------------------------------

for NS in rbac-lab internal; do
  if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
    fail "Namespace '$NS' is missing. Existing namespaces must not be deleted."
  fi
done

if ! kubectl get sa report-reader -n rbac-lab >/dev/null 2>&1; then
  fail "ServiceAccount 'report-reader' is missing from 'rbac-lab'."
fi

REPORT_READY=$(kubectl get deployment report-api -n rbac-lab -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$REPORT_READY" != "1" ]; then
  fail "Deployment 'report-api' in 'rbac-lab' is missing or not ready."
fi

INTERNAL_READY=$(kubectl get deployment internal-api -n internal -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$INTERNAL_READY" != "1" ]; then
  fail "Deployment 'internal-api' in 'internal' is missing or not ready."
fi

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "Environment integrity checks failed. Fix these before authorization will even be tested."
  exit 1
fi

# --------------------------------------------------
# 1. Positive permissions — rbac-lab, namespaced
# --------------------------------------------------

expect_yes get    pods        rbac-lab
expect_yes list   pods        rbac-lab
expect_yes watch  pods        rbac-lab

expect_yes get    configmaps  rbac-lab
expect_yes list   configmaps  rbac-lab
expect_yes watch  configmaps  rbac-lab

expect_yes get    deployments rbac-lab
expect_yes list   deployments rbac-lab

# --------------------------------------------------
# 2. Positive permissions — cluster-scoped
# --------------------------------------------------

expect_yes get nodes ""

# --------------------------------------------------
# 3. Negative permissions — write verbs in rbac-lab
# --------------------------------------------------

expect_no create pods        rbac-lab
expect_no update pods        rbac-lab
expect_no patch  pods        rbac-lab
expect_no delete pods        rbac-lab

expect_no create configmaps  rbac-lab
expect_no update configmaps  rbac-lab
expect_no patch  configmaps  rbac-lab
expect_no delete configmaps  rbac-lab

expect_no create deployments rbac-lab
expect_no update deployments rbac-lab
expect_no patch  deployments rbac-lab
expect_no delete deployments rbac-lab

# --------------------------------------------------
# 4. Negative permissions — cluster-scoped write verbs
# --------------------------------------------------

expect_no create nodes ""
expect_no update nodes ""
expect_no patch  nodes ""
expect_no delete nodes ""

# --------------------------------------------------
# 5. Negative permissions — Secrets, anywhere
# --------------------------------------------------

expect_no get    secrets rbac-lab
expect_no list   secrets rbac-lab
expect_no get    secrets internal
expect_no get    secrets kube-system
expect_no create secrets rbac-lab

# --------------------------------------------------
# 6. Negative permissions — the internal namespace
# --------------------------------------------------

expect_no get  pods        internal
expect_no list pods        internal
expect_no get  deployments internal
expect_no get  configmaps  internal

# --------------------------------------------------
# 7. Least privilege — no blanket/wildcard access
# --------------------------------------------------

expect_no "*" "*" rbac-lab
expect_no "*" "*" ""

# --------------------------------------------------

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "$FAILURES check(s) failed. report-reader does not yet match the required permission model."
  exit 1
fi

echo "All permission checks passed. report-reader has exactly the access it needs, and nothing more."
exit 0
