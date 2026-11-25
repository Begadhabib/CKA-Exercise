# Solution - The Missing Configuration

## 1. Investigate

```bash
kubectl -n missing-config get deployments
kubectl -n missing-config get pods
```

The Deployment wants 2 replicas, but the Pods show `CreateContainerConfigError`. Not `ImagePullBackOff`, not `CrashLoopBackOff`.

```bash
kubectl -n missing-config describe pod -l app=orders-api
kubectl -n missing-config get events --sort-by=.lastTimestamp
```

The events contain a message of this form:

```
Error: secret "orders-db-credentials" not found
```

Confirm what exists and what the Deployment expects:

```bash
kubectl -n missing-config get secrets
kubectl -n missing-config get configmaps
kubectl -n missing-config get deployment orders-api -o yaml | grep -B2 -A4 -E 'secretKeyRef|configMapKeyRef'
```

Result: the ConfigMap `orders-config` exists, but the Secret `orders-db-credentials` (keys `username` and `password`) does not.

## 2. Root cause

The Pod spec reads `DB_USER` and `DB_PASSWORD` through `secretKeyRef`. Before starting a container, the kubelet must resolve every `valueFrom` reference to build the container's environment. The Secret no longer exists, so the kubelet cannot assemble the container config and reports `CreateContainerConfigError`.

The application process **never ran**. That is why `kubectl logs` is empty: there is no container to read logs from.

| Status | Meaning |
|---|---|
| `CreateContainerConfigError` | Kubelet could not build the container config (missing Secret/ConfigMap/key, invalid spec) |
| `ImagePullBackOff` | The image cannot be pulled |
| `CrashLoopBackOff` | Container started, then the process kept exiting |

## 3. Fix

Recreate the missing Secret with the right name and keys. The values are in `/root/handover/db-handover.txt`:

```bash
kubectl -n missing-config create secret generic orders-db-credentials \
  --from-literal=username=orders_svc \
  --from-literal=password='S3cure-Pa55-2026'
```

The kubelet retries on its own, so the Pods start after a short back-off. There is no need to delete Pods or recreate the Deployment.

## 4. Verify

```bash
kubectl -n missing-config get pods -w
kubectl -n missing-config get deployment orders-api
kubectl -n missing-config exec deploy/orders-api -- wget -qO- localhost/healthz
```

## 5. Production lessons

- Secrets and ConfigMaps are namespaced and are **hard dependencies** of the Pod unless marked `optional: true`.
- Manage Secrets declaratively (External Secrets Operator, Sealed Secrets, CSI Secrets Store) so they cannot silently disappear.
- Alert on `CreateContainerConfigError` and on Deployments whose available replicas drop below desired.
- A rollout or reschedule is often what reveals a long-hidden dependency problem, because running Pods keep their already-resolved environment.
- Use the status to pick the right tool: events/describe for config errors, logs for runtime errors.
