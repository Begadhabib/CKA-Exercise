# 🗄️ Vault Unlocked

Well done — the storage layer is healthy and the workload is stable.

You found two separate issues stacked on top of each other:

* A **PersistentVolume/PersistentVolumeClaim capacity mismatch** that kept the claim `Pending`.
* A **read-only volume mount** that kept crashing the Pod even after storage was available — something only visible in the container logs, not in `describe` output.

This is a common pattern in real incidents: fixing the first visible symptom doesn't always mean the system is healthy. Always re-check after every fix.
