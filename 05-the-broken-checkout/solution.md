# Solution — The Broken Checkout

## Problem 1: ImagePullBackOff (bad image tag)

```bash
kubectl get pods -n shop-app
kubectl describe pod <pod-name> -n shop-app
```

Events will show something like:

```
Failed to pull image "nginx:1.27.99": ... not found
```

The tag `1.27.99` doesn't exist. Fix it:

```bash
kubectl set image deployment/checkout-service checkout=nginx:1.27 -n shop-app
```

## Problem 2: CreateContainerConfigError (wrong Secret key)

Once the image is fixed, the Pod still won't start. Check events again:

```bash
kubectl describe pod <pod-name> -n shop-app
```

```
Error: couldn't find key APIKEY in Secret shop-app/checkout-secret
```

The Secret actually has the key `API_KEY`, not `APIKEY`:

```bash
kubectl get secret checkout-secret -n shop-app -o jsonpath='{.data}'
```

Fix the Deployment's env reference:

```bash
kubectl patch deployment checkout-service -n shop-app \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key", "value": "API_KEY"}]'
```

## Problem 3: Pod Running but not Ready (bad readiness probe path)

The container is running now, but `kubectl get pods` shows `0/1` ready:

```bash
kubectl describe pod <pod-name> -n shop-app
```

```
Warning  Unhealthy  ... Readiness probe failed: HTTP probe failed with statuscode: 404
```

The probe checks `/healthz`, which nginx doesn't serve. Point it at a
path that actually exists (nginx serves `/` by default):

```bash
kubectl patch deployment checkout-service -n shop-app \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path", "value": "/"}]'
```

## Verify

```bash
kubectl get pods -n shop-app
kubectl get endpoints checkout-svc -n shop-app
```

The Pod should be `1/1 Running`, with no further restarts, and
`checkout-svc` should now list an endpoint.
