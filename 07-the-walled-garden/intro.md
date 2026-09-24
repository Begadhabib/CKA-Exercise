# 🧱 The Walled Garden

A three-tier application (`frontend`, `backend`, `database`) has just
stopped talking to itself. Nothing seems to be able to reach anything
else, even though every Pod and Service is up and healthy.

You have administrative access to the cluster.

> **Before you start:** this scenario relies on Kubernetes
> `NetworkPolicy` actually being enforced, which requires a
> policy-aware CNI (such as Calico). If your cluster uses Flannel,
> NetworkPolicy objects will be silently ignored and this challenge
> won't behave as expected.

Click **Start** when you're ready to begin.
