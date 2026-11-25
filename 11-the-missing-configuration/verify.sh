#!/bin/bash
NS="missing-config"
DEPLOY="orders-api"
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; }

kubectl get namespace "$NS" >/dev/null 2>&1 || fail "Namespace $NS not found."
kubectl -n "$NS" get deployment "$DEPLOY" >/dev/null 2>&1 || fail "Deployment $DEPLOY not found."

# The Deployment must be the original one (no delete & recreate)
ORIG_UID=$(cat /tmp/.orders-deploy-uid 2>/dev/null)
NOW_UID=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.metadata.uid}')
[ -n "$ORIG_UID" ] && [ "$ORIG_UID" = "$NOW_UID" ] || fail "The Deployment was deleted and recreated. Fix the cause instead."
pass "Original Deployment is still in place."

# Every configuration dependency referenced by the Deployment must exist
REFS=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{range .spec.template.spec.containers[*].env[*]}{.name}|{.valueFrom.secretKeyRef.name}|{.valueFrom.secretKeyRef.key}|{.valueFrom.configMapKeyRef.name}|{.valueFrom.configMapKeyRef.key}{"\n"}{end}')
PASS_SECRET=""
while IFS='|' read -r ENVNAME SNAME SKEY CNAME CKEY; do
  [ -z "$ENVNAME" ] && continue
  if [ -n "$SNAME" ]; then
    kubectl -n "$NS" get secret "$SNAME" >/dev/null 2>&1 || fail "Secret '$SNAME' (used by $ENVNAME) does not exist."
    VAL=$(kubectl -n "$NS" get secret "$SNAME" -o jsonpath="{.data.$SKEY}" 2>/dev/null)
    [ -n "$VAL" ] || fail "Secret '$SNAME' has no non-empty key '$SKEY' (used by $ENVNAME)."
    [ "$ENVNAME" = "DB_PASSWORD" ] && PASS_SECRET="$SNAME"
  fi
  if [ -n "$CNAME" ]; then
    kubectl -n "$NS" get configmap "$CNAME" >/dev/null 2>&1 || fail "ConfigMap '$CNAME' (used by $ENVNAME) does not exist."
    VAL=$(kubectl -n "$NS" get configmap "$CNAME" -o jsonpath="{.data.$CKEY}" 2>/dev/null)
    [ -n "$VAL" ] || fail "ConfigMap '$CNAME' has no non-empty key '$CKEY'."
  fi
done <<< "$REFS"
[ -n "$PASS_SECRET" ] || fail "DB_PASSWORD must still be provided from a Secret."
pass "All referenced Secrets/ConfigMaps and keys exist."

# Poll until the rollout is fully healthy (max ~120s)
WANT=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.spec.replicas}')
OK=0
for i in $(seq 1 40); do
  READY=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.status.readyReplicas}')
  TOTAL=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.status.replicas}')
  [ "${READY:-0}" -ge 1 ] && [ "${READY:-0}" = "$WANT" ] && [ "${TOTAL:-0}" = "$WANT" ] && { OK=1; break; }
  sleep 3
done
[ "$OK" = 1 ] || fail "Deployment not Ready ($READY/$WANT ready). Check 'kubectl -n $NS get pods'."
pass "Deployment has $READY/$WANT Ready replicas."

# No Pod may still report CreateContainerConfigError
BAD=$(kubectl -n "$NS" get pods -l app=orders-api -o jsonpath='{range .items[*]}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}' | grep -c CreateContainerConfigError)
[ "$BAD" -eq 0 ] || fail "Some Pods still report CreateContainerConfigError."
pass "No Pod reports CreateContainerConfigError."

# Functional check inside a running Pod
POD=$(kubectl -n "$NS" get pods -l app=orders-api --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
[ -n "$POD" ] || fail "No Running Pod found."
RESP=$(kubectl -n "$NS" exec "$POD" -- wget -qO- -T 3 http://localhost/healthz 2>/dev/null)
echo "$RESP" | grep -q "orders-api ok" || fail "Application did not answer on /healthz."
pass "Application answers: $RESP"

EP=$(kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=orders-api -o jsonpath='{.items[*].endpoints[*].addresses[*]}')
[ -n "$EP" ] || fail "Service orders-api has no endpoints."
pass "Service orders-api has endpoints: $EP"

echo "🎉 Incident resolved."
exit 0
