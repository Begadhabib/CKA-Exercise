# 12 - The Unexpected Environment

**Difficulty:** Intermediate to Advanced

## Incident Report

**Severity:** SEV-3  
**Service:** `backend` (namespace `unexpected-env`)

The `backend` team shipped a "small hardening change" to their Deployment this morning. Since then the new rollout is stuck: the new Pods fail during initialization, while the old ones keep running.

The team tells you:

- The application code and image are unchanged.
- The `inventory` Service it depends on is up and healthy.
- The application expects its configuration to be in its environment, and it is not there.

Your cluster is being prepared in the background. Wait for the terminal message saying the environment is ready, then continue.
