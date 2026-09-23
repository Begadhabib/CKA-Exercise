# 🍽️ Pod Fed

Well done — the workload is stable now.

The Pod was being **OOMKilled**: it needed more memory than its
container's `resources.limits.memory` allowed, so the kernel killed it
every time it started, which Kubernetes then restarted — over and over.

This is one of the most common production incidents in Kubernetes: a
resource limit that doesn't match what the workload actually needs.
`kubectl describe pod` and the container's last termination reason are
usually the fastest way to spot it.
