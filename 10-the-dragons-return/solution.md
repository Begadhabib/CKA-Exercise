# Solution — The Dragon's Return

Three separate faults, each hiding the next one. They have to be fixed
in this order, because each layer only becomes visible once the
previous one is solved.

## Fault 1: kube-apiserver can't reach etcd

```bash
kubectl get nodes
```

```
The connection to the server ... was refused
```

`kubectl` is useless here, so go around it and look at the containers
directly on the node:

```bash
crictl ps -a | grep kube-apiserver
crictl logs <apiserver-container-id> --tail 20
```

The logs show gRPC errors dialing `127.0.0.1:2380`: connection refused.

Compare against the static pod manifest:

```bash
grep etcd-servers /etc/kubernetes/manifests/kube-apiserver.yaml
```

The API server is pointed at port `2380`, which is etcd's **peer** port
(used between etcd members). Clients, including the API server, talk to
etcd on **2379**. Fix it:

```bash
sed -i 's#127.0.0.1:2380#127.0.0.1:2379#' /etc/kubernetes/manifests/kube-apiserver.yaml
```

The kubelet watches that directory and recreates the static pod on its
own. Wait 20–40 seconds, then:

```bash
kubectl get nodes
```

## Fault 2: Pods stuck Pending (CPU written in the wrong units)

```bash
kubectl get pods -n dragon-app
kubectl describe pod <pod-name> -n dragon-app
```

```
Warning  FailedScheduling  ... Insufficient cpu
```

Look at what the Deployment asks for:

```bash
kubectl get deployment frontend -n dragon-app \
  -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

```
{"limits":{"cpu":"1000"},"requests":{"cpu":"500"}}
```

CPU values without a suffix are **whole cores**. This asks for 500
cores. What was almost certainly meant is `500m` (half a core), where
`m` means millicores. No node can ever satisfy 500 cores, so the
scheduler keeps the Pods Pending. Fix it with realistic values:

```bash
kubectl set resources deployment frontend -n dragon-app \
  --requests=cpu=100m --limits=cpu=200m
```

## Fault 3: nothing happens after the fix (controller-manager is down)

After that change, you'd expect a rolling update. Instead:

```bash
kubectl get pods -n dragon-app
```

The old Pending Pods are still there and no new ones appear. The
Deployment was updated, but nothing acted on the change. Deployments
are turned into ReplicaSets and Pods by the **controller-manager**, so
check the control plane:

```bash
kubectl get pods -n kube-system
```

`kube-controller-manager-*` is in `Error` / `CrashLoopBackOff`. Read its
logs:

```bash
kubectl logs -n kube-system kube-controller-manager-controlplane
```

The message is along the lines of:

```
error reading key for service account token controller:
open /etc/kubernetes/pki/sa.pem: no such file or directory
```

Confirm what really exists on disk and what the manifest points at:

```bash
ls /etc/kubernetes/pki/ | grep sa
grep service-account-private-key-file /etc/kubernetes/manifests/kube-controller-manager.yaml
```

The key file is `sa.key`, but the manifest references `sa.pem`. Fix the
path:

```bash
sed -i 's#pki/sa.pem#pki/sa.key#' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

The kubelet recreates the static pod. Once the controller-manager is
back, it rolls out the updated Deployment.

## Verify

```bash
kubectl get pods -n kube-system
kubectl get deployment frontend -n dragon-app
kubectl get pods -n dragon-app
```

All control-plane pods are `Running`, and `frontend` shows `2/2` ready.

## Why the order matters

* Nothing can be fixed through the API until the API server can reach
  etcd.
* The CPU fault is a workload problem, but fixing it only works if
  something is running to act on the change.
* The controller-manager fault is invisible until you've fixed the
  first two, which is what makes it easy to miss.

The lesson: when a fix "doesn't take", look one layer down.
