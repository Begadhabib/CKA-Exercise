#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Sidecar] Preparing incident..."

# --------------------------------------------------
# 1. Create the application namespace
# --------------------------------------------------

kubectl create namespace batch-app --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create a Job with:
#
#    - a genuine init container (fetch-config) that
#      correctly runs and completes before anything
#      else starts.
#
#    - a main container (generator) that does the
#      actual work and exits successfully after a
#      short delay.
#
#    - a "sidecar" (log-shipper) that is meant to
#      keep shipping logs for as long as the Pod is
#      alive. It is deliberately placed as an
#      ordinary container instead of a native
#      sidecar, so it runs forever and never lets
#      the Job complete.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: report-generator
  namespace: batch-app
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      initContainers:
        - name: fetch-config
          image: busybox:1.36
          command:
            - "sh"
            - "-c"
            - "echo fetching report config...; sleep 2; echo config-ready > /shared/config.txt"
          volumeMounts:
            - name: shared
              mountPath: /shared
      containers:
        - name: generator
          image: busybox:1.36
          command:
            - "sh"
            - "-c"
            - "echo starting report generation; cat /shared/config.txt; sleep 20; echo report-complete > /shared/report.txt; echo done generating"
          volumeMounts:
            - name: shared
              mountPath: /shared
        - name: log-shipper
          image: busybox:1.36
          command:
            - "sh"
            - "-c"
            - "while true; do echo shipping logs...; sleep 5; done"
      volumes:
        - name: shared
          emptyDir: {}
EOF

echo "[Sidecar] Incident planted."

exit 0
