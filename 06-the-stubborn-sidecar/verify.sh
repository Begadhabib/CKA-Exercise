#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

NAMESPACE="batch-app"
JOB="report-generator"

# 1. The log-shipper must now be a native sidecar: an init container
#    with restartPolicy: Always. This forces the real fix rather than
#    a workaround (like making log-shipper exit on its own).
SIDECAR_POLICY=$(kubectl get job "$JOB" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="log-shipper")].restartPolicy}' 2>/dev/null)

if [ "$SIDECAR_POLICY" != "Always" ]; then
  echo "log-shipper is not configured as a native sidecar (restartPolicy: Always) under initContainers"
  exit 1
fi

# 2. The Job must actually reach Complete
for i in $(seq 1 12); do
  SUCCEEDED=$(kubectl get job "$JOB" -n "$NAMESPACE" -o jsonpath='{.status.succeeded}' 2>/dev/null)
  if [ "$SUCCEEDED" == "1" ]; then
    break
  fi
  sleep 10
done

SUCCEEDED=$(kubectl get job "$JOB" -n "$NAMESPACE" -o jsonpath='{.status.succeeded}' 2>/dev/null)
if [ "$SUCCEEDED" != "1" ]; then
  echo "Job $JOB has not reached Complete (succeeded: $SUCCEEDED)"
  exit 1
fi

COMPLETION_TIME=$(kubectl get job "$JOB" -n "$NAMESPACE" -o jsonpath='{.status.completionTime}' 2>/dev/null)
if [ -z "$COMPLETION_TIME" ]; then
  echo "Job $JOB has no completionTime set"
  exit 1
fi

echo "Job completed successfully. The sidecar started early, did its job, and stepped aside."
exit 0
