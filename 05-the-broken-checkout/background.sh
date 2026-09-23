#!/bin/bash

set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[Checkout] Preparing incident..."

# --------------------------------------------------
# 1. Create the application namespace
# --------------------------------------------------

kubectl create namespace shop-app --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 2. Create a Secret the workload depends on.
#    Its real key is API_KEY.
# --------------------------------------------------

kubectl create secret generic checkout-secret \
  --from-literal=API_KEY=s3cr3t-value \
  -n shop-app \
  --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# 3. Create the workload with three separate,
#    deliberate problems:
#
#    a) an image tag that doesn't exist
#       -> ImagePullBackOff
#    b) an env var referencing the wrong Secret key
#       -> CreateContainerConfigError
#    c) a readiness probe pointing at a path that
#       doesn't exist on the container
#       -> Pod stays Running but never Ready
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-service
  namespace: shop-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: checkout-service
  template:
    metadata:
      labels:
        app: checkout-service
    spec:
      containers:
        - name: checkout
          image: nginx:1.27.99
          ports:
            - containerPort: 80
          env:
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: checkout-secret
                  key: APIKEY
          readinessProbe:
            httpGet:
              path: /healthz
              port: 80
            initialDelaySeconds: 3
            periodSeconds: 5
EOF

# --------------------------------------------------
# 4. Create a Service in front of it, so the
#    readiness problem has a visible effect too.
# --------------------------------------------------

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: checkout-svc
  namespace: shop-app
spec:
  selector:
    app: checkout-service
  ports:
    - port: 80
      targetPort: 80
EOF

echo "[Checkout] Incident planted."

exit 0
