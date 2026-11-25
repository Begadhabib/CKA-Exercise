# Your Mission

Restore the `orders-api` application in the `missing-config` namespace.

## Requirements

- Both replicas of the `orders-api` Deployment must become **Ready**.
- The `orders-api` Service must have healthy endpoints.
- Keep the **original Deployment**: do not delete and recreate it, and do not change its image.

## Investigation Tasks

1. Look at the Deployment, its Pods, and what state they are really in.
2. Read the Pod details and the namespace events carefully.
3. Inspect the Secrets and ConfigMaps that exist in the namespace.
4. Work out **why the container cannot even be created**, then fix the cause.

Useful commands: `kubectl get`, `kubectl describe`, `kubectl get events`.

The platform team left some notes at `/root/handover/db-handover.txt`.

When you believe the incident is resolved, click **Check**.
