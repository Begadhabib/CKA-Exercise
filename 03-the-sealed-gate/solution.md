# Solution — The Sealed Gate

## Problem 1: Pod stuck in Init:CrashLoopBackOff (missing RBAC permission)

```bash
kubectl get pods -n gate-app
```

The backend Pod is stuck with an init container that never completes.
`kubectl describe pod` shows the init container is failing, but not why.
Check its logs directly:

```bash
kubectl logs <backend-pod> -n gate-app -c config-check
```

Expected output:

```
Error from server (Forbidden): configmaps "app-config" is forbidden:
User "system:serviceaccount:gate-app:backend-sa" cannot get resource
"configmaps" in API group "" in the namespace "gate-app"
```

The init container runs `kubectl get configmap app-config`, which requires
the `get` verb. Check the Role bound to `backend-sa`:

```bash
kubectl get role cm-reader -n gate-app -o yaml
```

It only grants `list`, not `get`. Fix it:

```bash
kubectl patch role cm-reader -n gate-app \
  --type='json' \
  -p='[{"op": "add", "path": "/rules/0/verbs/-", "value": "get"}]'
```

The init container will succeed on its next retry, and the Pod will
become `Running`.

## Problem 2: Service has no Endpoints (selector mismatch)

Even with the Pod `Running`, nothing can reach it:

```bash
kubectl get endpoints backend-svc -n gate-app
```

The `ENDPOINTS` column is empty. Compare the Service's selector with the
Pod's actual labels:

```bash
kubectl get svc backend-svc -n gate-app -o jsonpath='{.spec.selector}'
kubectl get pods -n gate-app --show-labels
```

The Service selects `app: backend`, but the Pod is labeled
`app: backend-app`. Fix the Service to match the Pod's real label:

```bash
kubectl patch svc backend-svc -n gate-app \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend-app"}]'
```

## Verify

```bash
kubectl get pods -n gate-app
kubectl get endpoints backend-svc -n gate-app
```

The Pod should be `Running` with no further restarts, and the Service
should now list a Pod IP under `ENDPOINTS`.
