# Fix the Incident

The `report-generator` Job in the `batch-app` namespace never reaches
`Complete`, even though the report it's supposed to generate is
finished every time.

> **Note:** this task uses native sidecar containers, a feature that
> requires Kubernetes 1.29 or newer.

## Your Task

Investigate why the Job never completes, and fix it — without changing
what the workload actually does (the report should still get
generated, and the logs should still get shipped for as long as the
real work is happening).

Specifically, you need to:

* Make the log-shipping container start **before** the main container.
* Keep it running for as long as the main container is doing real
  work.
* Make sure it no longer prevents the Job from reaching `Complete`.

## Where to Look

This is a documented, built-in Kubernetes feature — you don't need to
invent a workaround. Read the official docs on **sidecar containers**
before you touch anything:

* Concept guide: https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/
* Hands-on tutorial: https://kubernetes.io/docs/tutorials/configuration/container-startup-order/

Pay close attention to:
* Where a sidecar is declared in the Pod spec (it isn't under
  `containers`).
* Which single field turns a normal init container into a sidecar
  that keeps running.
* The section on **Jobs** specifically — it explains exactly why a
  sidecar defined the "old" way blocks a Job from completing, and why
  a native sidecar doesn't.

## Helpful Commands

```bash
kubectl get job report-generator -n batch-app
kubectl get pods -n batch-app
kubectl describe pod <pod-name> -n batch-app
kubectl logs <pod-name> -n batch-app -c generator
kubectl logs <pod-name> -n batch-app -c log-shipper
```

Think about what a Job actually waits for before it considers itself
finished — and whether every container in this Pod is expected to ever
exit on its own.

## Final State

When you're done:

* The `report-generator` Job reaches `Complete`.
* The log-shipping container still starts early and runs for the full
  duration of the real work — it just needs to stop being the reason
  the Job hangs forever.

## Success

The challenge is done when the final validation passes.