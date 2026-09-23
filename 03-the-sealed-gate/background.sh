#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Gate] Preparing incident..."

# --------------------------------------------------
# 1. Create the application namespace
# --------------------------------------------------

kubectl create namespace gate-app --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create a ConfigMap the workload needs to read
#    at startup.
# --------------------------------------------------

kubectl create configmap app-config \
  --from-literal=message="hello from the gate" \
  -n gate-app \
  --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 3. Create a ServiceAccount and a Role that is
#    deliberately missing the "get" verb on
#    configmaps (only "list" is granted).
#    -> the init container below performs a "get",
#       which the Kubernetes API will reject.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: gate-app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cm-reader
  namespace: gate-app
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-cm-reader
  namespace: gate-app
subjects:
  - kind: ServiceAccount
    name: backend-sa
    namespace: gate-app
roleRef:
  kind: Role
  name: cm-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# --------------------------------------------------
# 4. Create the workload. Its init container reads
#    the ConfigMap via the Kubernetes API using the
#    ServiceAccount above -> it will fail with
#    "Forbidden" until the Role is fixed.
#
#    The Pod template label is also deliberately
#    different from what the Service (step 5)
#    selects on.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: gate-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend-app
  template:
    metadata:
      labels:
        app: backend-app
    spec:
      serviceAccountName: backend-sa
      initContainers:
        - name: config-check
          image: bitnami/kubectl:1.28
          command:
            - "sh"
            - "-c"
            - "kubectl get configmap app-config -n gate-app -o jsonpath='{.data.message}'"
      containers:
        - name: backend
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF

# --------------------------------------------------
# 5. Create the Service. Its selector does not match
#    the Pod's actual label ("backend" vs
#    "backend-app") -> Endpoints stay empty even
#    once the Pod is Running.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: gate-app
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 80
EOF

echo "[Gate] Incident planted."

exit 0
