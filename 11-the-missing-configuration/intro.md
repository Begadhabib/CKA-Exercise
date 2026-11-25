# 11 - The Missing Configuration

**Difficulty:** Intermediate to Advanced

## Incident Report

**Severity:** SEV-2  
**Service:** `orders-api` (namespace `missing-config`)

The on-call phone rings. The `orders-api` team reports that their service stopped coming back after a routine node maintenance window earlier today.

They insist:

- The application image has **not** changed.
- Nobody touched the Deployment manifest.
- It was working yesterday.

The Deployment exists and asks for two replicas, but the application is not serving traffic.

Your cluster is being prepared in the background. Wait for the terminal message saying the environment is ready, then continue.
