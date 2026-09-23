# Troubleshoot the Incident

A workload in the `memory-app` namespace keeps restarting.

## Your Task

Find out why the Pod keeps restarting, and fix it so it stays up.

## Helpful Commands

You can use these to guide your investigation:

```bash
kubectl get pods -n memory-app
kubectl describe pod <pod-name> -n memory-app
kubectl get pod <pod-name> -n memory-app -o jsonpath='{.status.containerStatuses[0].lastState}'
```

Pay close attention to the container's **last termination reason** and
its configured **resource limits**.

## Final State

When you're done:

* The Pod in `memory-app` is `Running` and stable — no more restarts.

## Success

The challenge is done when the final validation passes.
