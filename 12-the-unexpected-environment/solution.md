# Solution - The Unexpected Environment

## 1. Investigate

```bash
kubectl -n unexpected-env get pods
```

Two older `backend` Pods are Running, while the new one is in `CrashLoopBackOff` (the rollout is stuck).

```bash
kubectl -n unexpected-env logs <new-backend-pod>
```

The log says no inventory endpoint is configured: neither `INVENTORY_URL` nor `INVENTORY_SERVICE_HOST` is set.

Compare environments. The Service exists, and a Pod that was created with default settings sees the injected variables:

```bash
kubectl -n unexpected-env exec deploy/inventory -- printenv | grep SERVICE
kubectl -n unexpected-env exec <old-backend-pod> -- printenv | grep INVENTORY
```

Look at the Pod spec of the Deployment and its history:

```bash
kubectl -n unexpected-env get deployment backend -o yaml | grep -n enableServiceLinks
kubectl -n unexpected-env rollout history deployment/backend
kubectl -n unexpected-env get service inventory
```

The new revision contains `enableServiceLinks: false`.

You can also prove DNS is unaffected:

```bash
kubectl -n unexpected-env run dns-test --rm -it --restart=Never --image=busybox:1.36 -- nslookup inventory
```

## 2. Root cause

By default (`enableServiceLinks: true`), the kubelet injects variables such as `INVENTORY_SERVICE_HOST` and `INVENTORY_SERVICE_PORT` for each Service in the namespace into every container. The backend relied on those variables. The hardening change set `enableServiceLinks: false`, so the new Pods start with no such variables and the application stops during initialization.

This is **not** a DNS or networking problem. `inventory` is still resolvable and reachable. Only the automatic environment variable injection was turned off.

## 3. Fix

**Option A, quick and compatible (re-enable the legacy behaviour):**

```bash
kubectl -n unexpected-env patch deployment backend --type=merge \
  -p '{"spec":{"template":{"spec":{"enableServiceLinks":true}}}}'
```

**Option B, production-relevant (keep links disabled and use explicit DNS-based configuration):**

```bash
kubectl -n unexpected-env set env deployment/backend \
  INVENTORY_URL=http://inventory.unexpected-env.svc.cluster.local:80
```

Option B keeps the hardening and makes the dependency explicit. The application already prefers `INVENTORY_URL` when it is set. Both options trigger a new rollout.

## 4. Verify

```bash
kubectl -n unexpected-env rollout status deployment/backend
kubectl -n unexpected-env get pods
kubectl -n unexpected-env exec deploy/backend -- printenv | grep INVENTORY
kubectl -n unexpected-env exec deploy/backend -- wget -qO- http://localhost:8080/status
```

## 5. Production lessons

- Variables are injected **only at container start**, and only for Services that **already exist** in the namespace at that moment, so the behaviour depends on creation order.
- In namespaces with many Services, links inflate every Pod's environment (several variables per Service port). That is the main reason many teams disable them.
- Service links and DNS are separate mechanisms. Prefer DNS names (`<service>.<namespace>.svc.cluster.local`) in explicit configuration (env vars, ConfigMaps) rather than depending on implicit injection.
- Review PodSpec-level changes such as `enableServiceLinks` against what the application actually reads.
