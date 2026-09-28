# Troubleshoot the Incident

A production Kubernetes cluster is having an outage. You have admin
access to the control-plane node.

Something is wrong with the cluster — and it's not just one issue.
Every time you fix something, expect to find something else waiting
behind it.

## Your Task

Investigate and restore normal operation. There's an application
running in the `dragon-app` namespace that should be fully available.
You need to figure out:

* Why API operations are failing.
* Why the application's Pods can't run.
* Why fixing the application alone doesn't bring it back.
* How to fix everything safely, without rebuilding the cluster or
  using destructive shortcuts.

## Final State

When you're done:

* `kubectl` works normally.
* All control-plane components are healthy.
* The `frontend` Deployment in `dragon-app` has all of its replicas
  running and ready, and still keeps sensible CPU requests.

## Success

The challenge is done when the final validation passes.

You're expected to investigate and figure it out yourself — no
individual hints in this step.
