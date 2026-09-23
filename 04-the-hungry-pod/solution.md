# Solution — The Hungry Pod

## Problem: Container OOMKilled (memory limit too low)

```bash
kubectl get pods -n memory-app
```

The Pod is stuck in `CrashLoopBackOff`, restarting repeatedly. Check the
last termination reason:

```bash
kubectl describe pod <pod-name> -n memory-app
```

Look for:

```
Last State:     Terminated
  Reason:       OOMKilled
```

The container (`polinux/stress`) is deliberately allocating more memory
(`150M`) than its configured limit allows:

```bash
kubectl get deployment cache-service -n memory-app -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

```
{"limits":{"memory":"50Mi"},"requests":{"memory":"50Mi"}}
```

`50Mi` is far too small for a `150M` allocation, so the kernel kills the
container every time it starts.

## Fix

Raise the memory limit (and request) to something the workload can
actually use:

```bash
kubectl patch deployment cache-service -n memory-app \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "250Mi"},
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "250Mi"}
  ]'
```

## Verify

```bash
kubectl get pods -n memory-app -w
```

The Pod should reach `Running` and stay there, with `RESTARTS` no longer
increasing.
