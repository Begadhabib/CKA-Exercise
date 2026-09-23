# Solution — The Stubborn Sidecar

## The Problem

```bash
kubectl get pods -n batch-app
```

The Pod stays `Running` (showing something like `1/2` containers
ready) long after the report has clearly finished:

```bash
kubectl logs <pod-name> -n batch-app -c generator
```

```
starting report generation
config-ready
done generating
```

The `generator` container has already exited successfully. But:

```bash
kubectl logs <pod-name> -n batch-app -c log-shipper
```

```
shipping logs...
shipping logs...
shipping logs...
```

`log-shipper` is stuck in an infinite loop and will never exit on its
own. A Job only counts as `Complete` once **every** container in the
Pod has terminated successfully — so as long as `log-shipper` keeps
running, the Job never finishes, the Pod never gets cleaned up, and the
Job just sits there consuming resources forever. This is a classic,
dangerous production mistake: bolting a "sidecar" onto a Job as an
ordinary container.

## The Fix: Native Sidecar Containers

Since Kubernetes 1.29, you can declare a sidecar as an **init
container with `restartPolicy: Always`**. Containers configured this
way:

* Start before the regular containers, in order, like any init
  container.
* Once started, keep running in the background — they don't block the
  next init container or the main containers from starting.
* Are automatically sent a termination signal once **all regular
  (non-init) containers have completed** — which is exactly what lets
  a Job reach `Complete`.

Move `log-shipper` out of `containers` and into `initContainers`, and
add `restartPolicy: Always` to it:

```bash
kubectl patch job report-generator -n batch-app \
  --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/initContainers/-", "value": {
      "name": "log-shipper",
      "image": "busybox:1.36",
      "restartPolicy": "Always",
      "command": ["sh", "-c", "while true; do echo shipping logs...; sleep 5; done"]
    }},
    {"op": "remove", "path": "/spec/template/spec/containers/1"}
  ]'
```

> Jobs are immutable once created in most fields, so in practice you'll
> usually need to delete and recreate the Job with the corrected
> manifest rather than patching a live one:
>
> ```bash
> kubectl delete job report-generator -n batch-app
> ```
> then reapply a corrected manifest with `log-shipper` under
> `initContainers` and `restartPolicy: Always` set on it.

## Verify

```bash
kubectl get job report-generator -n batch-app
kubectl get pods -n batch-app -w
```

The Pod should show all containers ready while running, then
disappear as `Completed` once `generator` finishes — and the Job
should show `COMPLETIONS: 1/1`.
