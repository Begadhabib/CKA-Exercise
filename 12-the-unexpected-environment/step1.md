# Your Mission

Get the `backend` rollout in the `unexpected-env` namespace completed so that the application starts and can talk to the `inventory` Service.

## Requirements

- All `backend` replicas must be **Ready** on the latest revision.
- The backend must be able to reach the `inventory` Service.
- Keep the **original Deployment**: do not delete and recreate it, and leave the `inventory` Service as it is.
- Prefer a solution you would be comfortable shipping to production.

## Investigation Tasks

1. Compare the state of the old and new `backend` Pods.
2. Read the application's logs and the Pod specification.
3. Look at the environment variables of the `backend` Pods and of the `inventory` Pod.
4. Check how Pods in this namespace can find the `inventory` Service, and what actually works from inside a Pod.

Useful commands: `kubectl get pods -o yaml`, `kubectl describe pod`, `kubectl get deployment -o yaml`, `kubectl logs`, `kubectl exec`, `printenv`, `env`, `kubectl rollout history`.

When you believe the incident is resolved, click **Check**.
