# Incident Resolved 🎉

`orders-api` is serving traffic again, with the original Deployment intact.

You separated two very different failure families:

- **Configuration errors** (`CreateContainerConfigError`): the kubelet cannot build the container spec, so the container process is never started.
- **Runtime errors** (`CrashLoopBackOff`, `Error`): the container was created and started, then the process failed.

Remember: a Pod stuck on a missing Secret or ConfigMap heals by itself once the object exists. No restart required.

## Learning Resources

1. **ConfigMaps**  
   https://kubernetes.io/docs/concepts/configuration/configmap/  
   Understand how ConfigMaps are consumed by Pods, and what happens when a referenced ConfigMap or key is missing (and when `optional` applies).

2. **Secrets**  
   https://kubernetes.io/docs/concepts/configuration/secret/  
   Understand how Secrets are referenced by Pods, why they are namespaced objects, and what production practices protect them.

3. **Configure Pod containers using environment variables**  
   https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/  
   Learn the `env`, `valueFrom`, `secretKeyRef` and `configMapKeyRef` syntax used by the Deployment in this lab.

4. **Pod API Reference**  
   https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/  
   Look at `EnvVarSource`, `SecretKeySelector` and `ConfigMapKeySelector`, including the `optional` field.

A full walkthrough is available in `solution.md`.
