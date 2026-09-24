# Solution — The Reading Room

## Reading the Requirements

Two things stand out once you sort the requirements by scope:

* Pods, ConfigMaps, and Deployments are all **namespaced** resources,
  and every requirement about them is scoped to `rbac-lab` only. That
  points to `Role` + `RoleBinding` — a `Role` only ever grants
  permissions within the single namespace it's created in.
* Nodes are a **cluster-scoped** resource — they don't belong to any
  namespace. A `Role` physically cannot grant permission on a
  cluster-scoped resource, no matter which namespace you create it in;
  Kubernetes will let you create the `Role`, but the rule will simply
  never match anything. Cluster-scoped resources require a
  `ClusterRole`, bound with a `ClusterRoleBinding`.

So this requires **two separate authorization objects**, bound to the
same identity in two different ways.

## Step 1: Namespaced permissions (Role + RoleBinding)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: report-reader-role
  namespace: rbac-lab
rules:
  - apiGroups: [""]
    resources: ["pods", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: report-reader-binding
  namespace: rbac-lab
subjects:
  - kind: ServiceAccount
    name: report-reader
    namespace: rbac-lab
roleRef:
  kind: Role
  name: report-reader-role
  apiGroup: rbac.authorization.k8s.io
```

A few things worth noticing:

* `pods` and `configmaps` are in the **core** API group, written as
  `""` — a common source of confusion.
  `deployments` belongs to the `apps` API group.
* Only `get`, `list`, and `watch` are granted — no write verbs
  (`create`, `update`, `patch`, `delete`) appear anywhere, and
  `deployments` doesn't even get `watch`, since it wasn't requested.
* Because a `RoleBinding` lives in `rbac-lab` and references a `Role`
  in `rbac-lab`, these permissions only ever apply inside that one
  namespace — `report-reader` gets nothing in `internal` from this
  object, automatically.
* Neither rule mentions `secrets` at all — there's no need to
  explicitly deny them. In RBAC, everything is denied by default
  unless a rule explicitly allows it. Least privilege here just means
  *not adding* a rule you don't need.

## Step 2: Cluster-scoped permissions (ClusterRole + ClusterRoleBinding)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: report-reader-node-binding
subjects:
  - kind: ServiceAccount
    name: report-reader
    namespace: rbac-lab
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

`ClusterRole` objects aren't namespaced themselves, which is what lets
them grant permission on cluster-scoped resources like `nodes` in the
first place. The `ClusterRoleBinding` then grants that `ClusterRole`
to `report-reader` cluster-wide — but since the `ClusterRole` itself
only mentions `get` on `nodes`, that's the entirety of what
`report-reader` gains from it. A `ClusterRoleBinding` doesn't
automatically mean broad access; it just means the binding isn't
limited to one namespace. The permissions are still exactly whatever
the bound role says, no more.

## Why This Adds Up to Least Privilege

* Every verb granted maps directly to a stated requirement — nothing
  extra was added "to be safe" or "just in case."
* `internal` was never mentioned in any rule, so `report-reader` has
  zero access there — not because it was explicitly blocked, but
  because nothing ever granted it.
* Same story for `secrets` — never referenced, so never accessible.
* Write verbs (`create`, `update`, `patch`, `delete`) never appear for
  any resource, matching the "read-only reporting workload"
  description from the requirements.

## Verify

```bash
kubectl auth can-i get pods -n rbac-lab --as=system:serviceaccount:rbac-lab:report-reader
kubectl auth can-i get nodes --as=system:serviceaccount:rbac-lab:report-reader
kubectl auth can-i delete pods -n rbac-lab --as=system:serviceaccount:rbac-lab:report-reader
kubectl auth can-i get secrets -n rbac-lab --as=system:serviceaccount:rbac-lab:report-reader
kubectl auth can-i get pods -n internal --as=system:serviceaccount:rbac-lab:report-reader
```

The first two should return `yes`; the last three should return `no`.
