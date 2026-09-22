# Solution — The Locked Vault

## Problem 1: PVC stuck Pending (capacity mismatch)

```bash
kubectl get pvc -n vault-app
kubectl get pv
```

The PV `vault-pv` only has `1Gi` capacity, while the PVC `vault-pvc` requests `5Gi`.
A PV can only bind to a PVC if its capacity is greater than or equal to the request
(and `accessModes` / `storageClassName` match). Since no PV satisfies the request,
the PVC stays `Pending`.

Fix — increase the PV's capacity so it can satisfy the claim:

```bash
kubectl patch pv vault-pv -p '{"spec":{"capacity":{"storage":"5Gi"}}}'
```

Confirm it's bound:

```bash
kubectl get pvc -n vault-app
```

## Problem 2: Pod stuck in CrashLoopBackOff (read-only mount)

Once the PVC binds, the Pod starts — but soon enters `CrashLoopBackOff`.
`kubectl describe pod` won't explain *why*; the real reason is in the logs:

```bash
kubectl logs deploy/vault-writer -n vault-app
kubectl logs deploy/vault-writer -n vault-app --previous
```

Expected output:

```
sh: can't create /data/log.txt: Read-only file system
```

The container writes to `/data/log.txt`, but the volume is mounted with
`readOnly: true` in the Deployment spec.

Fix — edit the Deployment and remove the read-only mount:

```bash
kubectl patch deployment vault-writer -n vault-app \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/volumeMounts/0/readOnly", "value": false}]'
```

## Verify

```bash
kubectl get pvc -n vault-app
kubectl get pods -n vault-app -w
```

The PVC should be `Bound`, and the Pod should reach `Running` and stay there
without restarting.
