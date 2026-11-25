# Incident Resolved 🎉

The `backend` rollout is complete and the application talks to `inventory` again.

Key takeaways:

- **Service links** are a legacy discovery mechanism: at Pod start, the kubelet injects `{SVCNAME}_SERVICE_HOST`, `{SVCNAME}_SERVICE_PORT` and related variables for every Service that already exists in the Pod's namespace. `enableServiceLinks: false` turns this off.
- **DNS discovery is independent.** `inventory` and `inventory.<namespace>.svc.cluster.local` keep resolving even when links are disabled.
- Environment variables are fixed when the container starts. A Service created later is never injected into already-running Pods.

## Learning Resources

1. **Service: Environment variables**  
   https://kubernetes.io/docs/concepts/services-networking/service/#environment-variables  
   Learn exactly which variables are injected for a Service, and the ordering rule (the Service must exist before the Pod).

2. **DNS for Services and Pods**  
   https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/  
   Understand Service DNS names and why DNS-based discovery does not depend on Service links.

3. **Configure Pod containers using environment variables**  
   https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/  
   Learn how to define explicit environment variables, the production-friendly replacement for implicit ones.

4. **Pod API Reference**  
   https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/  
   Find the `enableServiceLinks` field in the PodSpec and its default value.

A full walkthrough is available in `solution.md`.
