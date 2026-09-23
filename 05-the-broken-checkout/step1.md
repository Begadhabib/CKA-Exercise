# Troubleshoot the Incident

The `checkout-service` Deployment in the `shop-app` namespace is not
serving traffic. Every fix you try seems to uncover a new problem
underneath it.

## Your Task

Investigate and get `checkout-service` fully up and serving traffic
through its Service. You need to figure out:

* Why the Pod never starts pulling up its container image correctly.
* Why, even after that's fixed, the container still won't start.
* Why, even after that's fixed, the Pod is `Running` but the Service
  still isn't sending it any traffic.

## Helpful Commands

```bash
kubectl get pods -n shop-app
kubectl describe pod <pod-name> -n shop-app
kubectl get deployment checkout-service -n shop-app -o yaml
kubectl get secret checkout-secret -n shop-app -o yaml
kubectl get endpoints checkout-svc -n shop-app
```

`kubectl describe pod` shows you *events* — pay attention to the order
they happened in, and to the reason given for each one.

## Final State

When you're done:

* The Pod in `shop-app` is `Running` and `Ready`, with no restarts.
* The `checkout-svc` Service has at least one Endpoint.

## Success

The challenge is done when the final validation passes.
