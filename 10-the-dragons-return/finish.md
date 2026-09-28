# 🐲 The Dragon Is Tamed

Well done: the cluster is healthy again and the application is fully
available.

You found three separate faults, each hiding behind the one before it:

* **kube-apiserver → etcd**: the API server was pointed at etcd's peer
  port instead of its client port, so the whole API was down.
* **CPU units**: resource values written as whole cores instead of
  millicores made the Pods unschedulable.
* **A bad certificate path in a static pod manifest**: the
  controller-manager couldn't find its service-account key, so it
  crashed and nothing reconciled, even after the workload was fixed.

Real outages rarely have one cause. Fix one layer, re-check, and keep
looking until everything is actually healthy.
