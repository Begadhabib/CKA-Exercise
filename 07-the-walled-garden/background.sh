#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Walled Garden] Preparing incident..."

# --------------------------------------------------
# 0. Sanity check: NetworkPolicy requires a CNI that
#    actually enforces it (e.g. Calico). Flannel does
#    not. This won't block setup, but warns early if
#    the cluster can't enforce policies at all.
# --------------------------------------------------

if ! kubectl get pods -n kube-system 2>/dev/null | grep -qi calico; then
  echo "[Walled Garden] WARNING: no Calico pods detected in kube-system."
  echo "[Walled Garden] NetworkPolicy will not be enforced unless the cluster's CNI supports it."
fi

# --------------------------------------------------
# 1. Create the application namespace
# --------------------------------------------------

kubectl create namespace netpol-app --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create the three application components plus one
#    unrelated workload. All use busybox's built-in
#    httpd so the whole app stays dependency-free.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: netpol-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
        - name: frontend
          image: busybox:1.36
          command: ["sh", "-c", "sleep infinity"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: netpol-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
        - name: backend
          image: busybox:1.36
          command:
            - "sh"
            - "-c"
            - "mkdir -p /www && echo backend-ok > /www/index.html && httpd -f -v -p 8080 -h /www"
          ports:
            - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: netpol-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
        - name: database
          image: busybox:1.36
          command:
            - "sh"
            - "-c"
            - "mkdir -p /www && echo database-ok > /www/index.html && httpd -f -v -p 5432 -h /www"
          ports:
            - containerPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unrelated
  namespace: netpol-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unrelated
  template:
    metadata:
      labels:
        app: unrelated
        tier: unrelated
    spec:
      containers:
        - name: unrelated
          image: busybox:1.36
          command: ["sh", "-c", "sleep infinity"]
EOF

# --------------------------------------------------
# 3. Create Services for backend and database.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: netpol-app
spec:
  selector:
    app: backend
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: database-svc
  namespace: netpol-app
spec:
  selector:
    app: database
  ports:
    - port: 5432
      targetPort: 5432
EOF

# --------------------------------------------------
# 4. Wait for everything to actually be ready before
#    applying NetworkPolicies, so the failure the
#    participant sees is deterministic.
# --------------------------------------------------

kubectl wait --for=condition=Ready pod -l app=frontend -n netpol-app --timeout=90s
kubectl wait --for=condition=Ready pod -l app=backend -n netpol-app --timeout=90s
kubectl wait --for=condition=Ready pod -l app=database -n netpol-app --timeout=90s
kubectl wait --for=condition=Ready pod -l app=unrelated -n netpol-app --timeout=90s

# --------------------------------------------------
# 5. Plant the incident: a blanket default-deny for
#    all ingress and egress traffic in the namespace,
#    with no allow rules for the application traffic
#    that's actually supposed to work.
#
#    A second policy explicitly keeps DNS working, so
#    the challenge stays focused on application
#    traffic rather than DNS troubleshooting.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: netpol-app
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: netpol-app
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF

echo "[Walled Garden] Incident planted."

exit 0
