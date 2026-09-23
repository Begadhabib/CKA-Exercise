# Troubleshoot the Incident

A workload in the `gate-app` namespace won't start, and once it does,
nothing can reach it.

## Your Task

Investigate and restore the workload to a fully working state. You need
to figure out:

* Why the backend Pod never becomes `Running`.
* Why, even after that's fixed, the Service in front of it isn't
  routing any traffic to it.

`kubectl describe` will only get you so far here — at least one of these
issues only shows itself in the logs.

## Final State

When you're done:

* The backend Pod in `gate-app` is `Running` and stable.
* The Service in front of it has at least one Endpoint.

## Success

The challenge is done when the final validation passes.

You're expected to investigate and figure it out yourself — no
individual hints in this step.
