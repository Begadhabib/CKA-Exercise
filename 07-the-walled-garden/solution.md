# Solution — The Walled Garden

## Investigating the Problem

Start by confirming the Pods and Services themselves are healthy:

```bash
kubectl get pods -n netpol-app -o wide
kubectl get svc -n netpol-app
```

Everything is `Running`, and the Services look correctly configured —
so this isn't a scheduling or Service-selector problem. Try the
connection directly:

```bash
kubectl exec -n netpol-app deploy/frontend -- wget -qO- -T 3 http://backend-svc:8080
```

This times out, even though `backend-svc` clearly points at a healthy
`backend` Pod. That combination — everything looks fine, but
connections just hang — is a strong signal to check `NetworkPolicy`:

```bash
kubectl get networkpolicy -n netpol-app
kubectl describe networkpolicy default-deny-all -n netpol-app
```

## Why It Was Broken

```yaml
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

An empty `podSelector: {}` selects **every** Pod in the namespace. A
policy that declares a `policyType` but defines no matching rules for
it means "block all traffic of that type, unless another policy
explicitly allows it." Here, both `Ingress` and `Egress` are declared
with no rules at all — so every Pod in `netpol-app` is cut off from
all incoming and outgoing traffic, full stop.

A second policy, `allow-dns`, carves out an exception for DNS traffic
to `kube-system`, which is why Service names still resolve — but
nothing about the actual application traffic (`frontend → backend`,
`backend → database`) was ever allowed.

NetworkPolicies are additive: a Pod's effective rules are the union of
every policy that selects it. So the fix isn't to remove
`default-deny-all` — deleting it would just make everything reachable
again, including the traffic that's supposed to stay blocked. The fix
is to add policies that open exactly the connections that should be
allowed, and nothing else.

## The Fix

Allow ingress to `backend` from `frontend` only:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: netpol-app
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

Allow ingress to `database` from `backend` only:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: netpol-app
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 5432
```

Apply both with `kubectl apply -f`.

## Why This Works

* `backend`'s `podSelector` now has an `Ingress` rule allowing traffic
  only from Pods labeled `app: frontend`, on port `8080`. Everything
  else aimed at `backend` — including from `unrelated` — is still
  denied by `default-deny-all`.
* `database`'s `podSelector` now has an `Ingress` rule allowing traffic
  only from Pods labeled `app: backend`, on port `5432`. Traffic from
  `frontend` or `unrelated` still has no matching `allow` rule from any
  policy, so `default-deny-all` continues to block it.
* Because `frontend` and `unrelated` were never given a matching
  `ingress` rule on `database`, their isolation from it holds — not by
  accident, but because nothing ever opened a path for them.

## Verify

```bash
kubectl exec -n netpol-app deploy/frontend -- wget -qO- -T 3 http://backend-svc:8080
kubectl exec -n netpol-app deploy/backend  -- wget -qO- -T 3 http://database-svc:5432
kubectl exec -n netpol-app deploy/frontend -- wget -qO- -T 3 http://database-svc:5432
kubectl exec -n netpol-app deploy/unrelated -- wget -qO- -T 3 http://database-svc:5432
```

The first two should return their `*-ok` payload; the last two should
time out.
