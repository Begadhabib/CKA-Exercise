# 🔑 Access Granted — Correctly

Well done — `report-reader` can now do exactly what a read-only
reporting workload needs, and nothing else.

The key insight was that the requirements lived at two different
scopes: namespaced permissions (Pods, ConfigMaps, Deployments inside
`rbac-lab`) needed a `Role` and `RoleBinding`, while the cluster-scoped
requirement (Nodes) could only be granted through a `ClusterRole` and
`ClusterRoleBinding` — a `Role` simply has no way to reach a resource
that doesn't belong to any namespace.

Just as important: `report-reader` never gained access to `secrets` or
to the `internal` namespace, not because anything explicitly forbade
it, but because nothing ever granted it. In RBAC, that's what least
privilege really looks like — permissions that map one-to-one to
actual requirements, with nothing left over.
