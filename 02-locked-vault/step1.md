# Troubleshoot the Incident

A workload in the `vault-app` namespace is not running correctly.

Something is wrong with its storage — and it's not just one issue.

## Your Task

Investigate and restore the workload to a healthy, stable state. You need to figure out:

* Why the workload's storage isn't ready.
* Why the Pod still isn't stable even after storage becomes available.
* How to fix it safely, without deleting and recreating everything from scratch.

You'll need more than just `kubectl get` and `kubectl describe` for this one — at some point, the logs are the only place that tell the real story.

## Final State

When you're done:

* The PersistentVolumeClaim in `vault-app` is `Bound`.
* The workload's Pod is `Running` and stable — no restarts.

## Success

The challenge is done when the final validation passes.

You're expected to investigate and figure it out yourself — no individual hints in this step.