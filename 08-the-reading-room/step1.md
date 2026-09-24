# Implement the Authorization Model

`report-api`, in the `rbac-lab` namespace, runs as the `report-reader`
ServiceAccount. It's a **read-only reporting workload** — it needs to
observe things, never change them.

Right now `report-reader` has no permissions at all. Your task is to
design and implement the RBAC model it needs, based purely on the
requirements below.

## Requirements

Inside the `rbac-lab` namespace, `report-reader` must be able to:

* `get`, `list`, and `watch` **Pods**
* `get`, `list`, and `watch` **ConfigMaps**
* `get` and `list` **Deployments**

It must **not** be able to:

* `create`, `update`, `patch`, or `delete` **Pods**
* `create`, `update`, `patch`, or `delete` **ConfigMaps**
* `update`, `patch`, or `delete` **Deployments**

The application also needs some cluster-level visibility. `report-reader`
must be able to:

* `get` **Nodes**

It must **not** be able to:

* `create`, `update`, `patch`, or `delete` **Nodes**

## Additional Constraints

* `report-reader` must **not** have any access to resources in the
  `internal` namespace — that namespace belongs to a different team
  entirely.
* `report-reader` must **not** have access to **Secrets**, anywhere in
  the cluster.
* Do not modify or delete any existing namespace or workload to get
  around these requirements — `report-api`, `internal-api`, and both
  namespaces need to stay exactly as they are.

## Something to Think About

Not all of these requirements live at the same scope. Some of them are
about what `report-reader` can do *inside a specific namespace*. At
least one of them is about something that isn't namespaced at all.
Kubernetes has more than one kind of authorization object for exactly
this reason — you'll need to figure out which ones apply where, and
how they connect a ServiceAccount to a set of permissions.

If you want a refresher, the official RBAC docs are here:

* https://kubernetes.io/docs/reference/access-authn-authz/rbac/

## Helpful Commands

```bash
# Check what report-reader can currently do:
kubectl auth can-i get pods -n rbac-lab --as=system:serviceaccount:rbac-lab:report-reader
kubectl auth can-i get nodes --as=system:serviceaccount:rbac-lab:report-reader

# After you create something, list what exists:
kubectl get role,rolebinding -n rbac-lab
kubectl get clusterrole,clusterrolebinding | grep report-reader
```

## Success

The challenge is done when the final validation passes. Validation
tests what `report-reader` can and cannot actually do — not which
objects you named things.
