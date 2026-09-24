# Troubleshoot the Incident

The `netpol-app` namespace holds a small three-tier application:
`frontend`, `backend`, and `database`. There's also an unrelated
workload, simply called `unrelated`, running in the same namespace.

Right now, none of the application's intended traffic works.

## Intended Communication Model

The application is supposed to behave like this:

| From         | To         | Should be   |
|--------------|------------|-------------|
| `frontend`   | `backend`  | **Allowed** |
| `backend`    | `database` | **Allowed** |
| `frontend`   | `database` | **Blocked** |
| `unrelated`  | `database` | **Blocked** |

## Your Task

Investigate why the required traffic isn't working, and fix it so the
table above holds true — without breaking the traffic that's supposed
to stay blocked.

## Constraints

* Do not delete or recreate any existing Deployment.
* Do not modify the existing Services or container ports.
* The database's isolation from `frontend` and `unrelated` must be
  preserved in your final solution — it can't just be broken by
  accident along the way.

## Where to Look

This challenge is about `NetworkPolicy`. If you're rusty on the
concepts, the official docs are worth a look before you start editing
anything:

* https://kubernetes.io/docs/concepts/services-networking/network-policies/

Pay attention to:
* How `podSelector` picks which Pods a policy applies to.
* The difference between `ingress` and `egress` rules.
* What happens when a Pod is selected by a policy that defines a
  `policyType` but gives it no rules at all.

## Helpful Commands

```bash
kubectl get pods -n netpol-app --show-labels
kubectl get networkpolicy -n netpol-app
kubectl describe networkpolicy <name> -n netpol-app
kubectl get svc -n netpol-app

# Test connectivity directly from inside a Pod:
kubectl exec -n netpol-app deploy/frontend -- wget -qO- -T 3 http://backend-svc:8080
kubectl exec -n netpol-app deploy/backend -- wget -qO- -T 3 http://database-svc:5432
```

## Final State

When you're done:

1. `frontend` can reach `backend`.
2. `backend` can reach `database`.
3. `frontend` cannot reach `database`.
4. `unrelated` cannot reach `database`.

## Success

The challenge is done when the final validation passes.
