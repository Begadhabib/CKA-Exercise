# 🎗️ Job Complete

Well done — `report-generator` now finishes cleanly every time.

The problem wasn't the actual work — it was the **sidecar pattern**.
A container meant to run "for as long as the Pod is alive" was declared
as an ordinary container, so it ran forever and silently kept the Job
from ever completing. That's a real, easy-to-miss production hazard:
stuck Jobs quietly burning resources (or blocking a CI/CD pipeline)
because of a container nobody remembered was still running.

Native sidecar containers (`restartPolicy: Always` under
`initContainers`, stable since Kubernetes 1.29) exist specifically to
solve this: start early, run throughout, and get cleaned up
automatically once the real work is done.
