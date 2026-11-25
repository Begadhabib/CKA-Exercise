#!/bin/bash
NS="unexpected-env"
DEPLOY="backend"
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; }

kubectl get namespace "$NS" >/dev/null 2>&1 || fail "Namespace $NS not found."
kubectl -n "$NS" get deployment "$DEPLOY" >/dev/null 2>&1 || fail "Deployment $DEPLOY not found."

ORIG_UID=$(cat /tmp/.backend-deploy-uid 2>/dev/null)
NOW_UID=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.metadata.uid}')
[ -n "$ORIG_UID" ] && [ "$ORIG_UID" = "$NOW_UID" ] || fail "The Deployment was deleted and recreated. Fix the cause instead."
pass "Original Deployment is still in place."

# Supporting Service must be intact
CLUSTER_IP=$(kubectl -n "$NS" get service inventory -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
PORT=$(kubectl -n "$NS" get service inventory -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
[ -n "$CLUSTER_IP" ] && [ "$CLUSTER_IP" != "None" ] || fail "Service 'inventory' is missing or has no ClusterIP."
[ "$PORT" = "80" ] || fail "Service 'inventory' must keep port 80."
EP=$(kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=inventory -o jsonpath='{.items[*].endpoints[*].addresses[*]}')
[ -n "$EP" ] || fail "Service 'inventory' has no endpoints."
pass "Service inventory is healthy ($CLUSTER_IP:$PORT, endpoints: $EP)."

# Poll until the rollout is complete and all Pods are Ready (max ~150s)
WANT=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.spec.replicas}')
OK=0
for i in $(seq 1 50); do
  READY=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.status.readyReplicas}')
  UPD=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.status.updatedReplicas}')
  TOTAL=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.status.replicas}')
  if [ "${READY:-0}" -ge 1 ] && [ "${READY:-0}" = "$WANT" ] && [ "${UPD:-0}" = "$WANT" ] && [ "${TOTAL:-0}" = "$WANT" ]; then OK=1; break; fi
  sleep 3
done
[ "$OK" = 1 ] || fail "Rollout not complete (ready=${READY:-0}, updated=${UPD:-0}, total=${TOTAL:-0}, wanted=$WANT)."
pass "Rollout complete: $READY/$WANT Ready replicas on the latest revision."

POD=$(kubectl -n "$NS" get pods -l app=backend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
[ -n "$POD" ] || fail "No Running backend Pod found."

# Actual environment behaviour inside the running Pod
ENVDUMP=$(kubectl -n "$NS" exec "$POD" -- printenv 2>/dev/null)
LINKS=$(kubectl -n "$NS" get deployment "$DEPLOY" -o jsonpath='{.spec.template.spec.enableServiceLinks}')

if [ "$LINKS" = "false" ]; then
  # Service links are off: the app must be migrated to explicit, DNS-based discovery
  URL=$(echo "$ENVDUMP" | grep '^INVENTORY_URL=' | cut -d= -f2-)
  [ -n "$URL" ] || fail "enableServiceLinks is false, but INVENTORY_URL is not set in the Pod."
  echo "$URL" | grep -Eq '^http://inventory(\.unexpected-env(\.svc(\.cluster\.local)?)?)?(:80)?/?$' \
    || fail "INVENTORY_URL ($URL) must use the Service DNS name, not an IP address or another host."
  RES=$(kubectl -n "$NS" exec "$POD" -- nslookup "inventory.$NS.svc.cluster.local" 2>/dev/null)
  echo "$RES" | grep -q "$CLUSTER_IP" || fail "DNS lookup of inventory.$NS.svc.cluster.local did not return $CLUSTER_IP from inside the Pod."
  pass "Service links are disabled and the app uses DNS discovery ($URL)."
else
  # Service links are on: the injected variables must be present and correct
  H=$(echo "$ENVDUMP" | grep '^INVENTORY_SERVICE_HOST=' | cut -d= -f2-)
  P=$(echo "$ENVDUMP" | grep '^INVENTORY_SERVICE_PORT=' | cut -d= -f2-)
  [ "$H" = "$CLUSTER_IP" ] || fail "INVENTORY_SERVICE_HOST is '$H', expected '$CLUSTER_IP'."
  [ "$P" = "80" ] || fail "INVENTORY_SERVICE_PORT is '$P', expected '80'."
  pass "Service links are enabled and variables are injected ($H:$P)."
fi

# Application health and real communication with the inventory Service
STATUS=$(kubectl -n "$NS" exec "$POD" -- wget -qO- -T 3 http://localhost:8080/status 2>/dev/null)
[ "$STATUS" = "ok" ] || fail "Backend /status returned '$STATUS' (expected 'ok')."
pass "Backend reports healthy."

RESP=$(kubectl -n "$NS" exec "$POD" -- wget -qO- -T 3 "http://inventory.$NS.svc.cluster.local" 2>/dev/null)
echo "$RESP" | grep -q inventory-service-online || fail "Backend Pod cannot reach the inventory Service."
pass "Backend Pod can reach the inventory Service."

echo "🎉 Incident resolved."
exit 0
