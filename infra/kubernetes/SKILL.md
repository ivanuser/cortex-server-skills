# Kubernetes — Container Orchestration

> Manage Kubernetes clusters with kubectl — deployments, services, ingress, storage, debugging, Helm, and common troubleshooting patterns.

## Safety Rules

- **Never `kubectl delete namespace` in production without triple-checking** — it deletes everything in it.
- Always use `--dry-run=client -o yaml` to preview before applying destructive changes.
- Set resource requests AND limits on all workloads — unbounded pods get OOM-killed or starve neighbors.
- Use `kubectl diff` before `kubectl apply` to see what will change.
- Never store secrets in plain YAML committed to git — use sealed-secrets, SOPS, or external secret managers.
- Test in a non-production namespace first: `kubectl config set-context --current --namespace=staging`

## Quick Reference

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl version --short
kubectl api-resources                  # All available resource types

# Context management
kubectl config get-contexts
kubectl config use-context my-cluster
kubectl config set-context --current --namespace=myapp

# Core resources
kubectl get pods -A                    # All namespaces
kubectl get pods -n myapp -o wide
kubectl get svc,deploy,ingress -n myapp
kubectl get all -n myapp

# Quick operations
kubectl create namespace myapp
kubectl run debug --image=busybox -it --rm -- sh
kubectl exec -it pod-name -- /bin/bash
kubectl logs pod-name -f --tail=100
kubectl logs pod-name -c container-name  # Multi-container pod
kubectl describe pod pod-name
kubectl port-forward svc/myservice 8080:80

# Apply / delete
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml
kubectl diff -f manifest.yaml          # Preview changes

# Scale
kubectl scale deployment myapp --replicas=3

# Rollout
kubectl rollout status deployment/myapp
kubectl rollout history deployment/myapp
kubectl rollout undo deployment/myapp
kubectl rollout restart deployment/myapp

# Resource usage
kubectl top nodes
kubectl top pods -n myapp
```

## Deployments

### Basic deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
  labels:
    app: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myregistry/myapp:v1.2.3
          ports:
            - containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: myapp-secrets
                  key: database-url
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: myapp-config
                  key: log-level
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
      restartPolicy: Always
```

### Update image

```bash
kubectl set image deployment/myapp myapp=myregistry/myapp:v1.3.0
kubectl rollout status deployment/myapp

# Rollback if broken
kubectl rollout undo deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=2
```

## Services

### ClusterIP (internal)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: myapp
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
```

### NodePort (external via node IP)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-nodeport
spec:
  type: NodePort
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080
```

### LoadBalancer (cloud provider)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-lb
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

## Ingress

### Nginx Ingress Controller

```bash
# Install nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Or via Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

### Ingress resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: myapp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: myapp-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: myapp-api
                port:
                  number: 80
```

## ConfigMaps & Secrets

### ConfigMap

```bash
# From literal values
kubectl create configmap myapp-config \
    --from-literal=log-level=info \
    --from-literal=cache-ttl=300

# From file
kubectl create configmap myapp-config --from-file=config.yaml

# From env file
kubectl create configmap myapp-config --from-env-file=.env
```

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: myapp
data:
  log-level: "info"
  cache-ttl: "300"
  app.conf: |
    server {
      listen 80;
      root /var/www;
    }
```

### Secrets

```bash
# Create secret
kubectl create secret generic myapp-secrets \
    --from-literal=database-url='postgres://user:pass@host:5432/db' \
    --from-literal=api-key='secret123'

# From file (e.g., TLS)
kubectl create secret tls myapp-tls --cert=tls.crt --key=tls.key

# View secret (base64 decoded)
kubectl get secret myapp-secrets -o jsonpath='{.data.database-url}' | base64 -d
```

### Mount as volume or env

```yaml
# As environment variables
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: myapp-secrets
        key: database-url

# As volume mount
volumes:
  - name: config-vol
    configMap:
      name: myapp-config
containers:
  - name: myapp
    volumeMounts:
      - name: config-vol
        mountPath: /etc/myapp
        readOnly: true
```

## Persistent Volumes

### PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
  namespace: myapp
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path          # Or: standard, gp2, longhorn, etc.
  resources:
    requests:
      storage: 10Gi
```

### Use in deployment

```yaml
spec:
  containers:
    - name: myapp
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: myapp-data
```

```bash
# List PVs and PVCs
kubectl get pv
kubectl get pvc -n myapp

# Check PVC status
kubectl describe pvc myapp-data -n myapp
```

## Helm

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable
helm repo update

# Search for charts
helm search repo postgres
helm search hub wordpress

# Install a chart
helm install my-postgres bitnami/postgresql -n myapp --create-namespace \
    --set auth.postgresPassword=mypassword \
    --set primary.persistence.size=20Gi

# Install with values file
helm install myapp ./my-chart -f values-prod.yaml

# List releases
helm list -A

# Upgrade
helm upgrade my-postgres bitnami/postgresql -n myapp --set auth.postgresPassword=newpassword

# Rollback
helm rollback my-postgres 1 -n myapp

# Uninstall
helm uninstall my-postgres -n myapp

# Show chart values
helm show values bitnami/postgresql

# Template (render without installing)
helm template myapp ./my-chart -f values.yaml
```

## Resource Limits & Requests

### LimitRange (namespace defaults)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: myapp
spec:
  limits:
    - default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      type: Container
```

### ResourceQuota (namespace total)

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: myapp
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    persistentvolumeclaims: "10"
```

## Node Management

```bash
# List nodes with status
kubectl get nodes -o wide

# Node details
kubectl describe node node-01

# Labels
kubectl label node node-01 disk=ssd
kubectl label node node-01 disk-                 # Remove label

# Taints (prevent scheduling)
kubectl taint nodes node-01 key=value:NoSchedule
kubectl taint nodes node-01 key-                 # Remove taint

# Drain node for maintenance (evicts pods)
kubectl drain node-01 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon node-01                         # Re-enable scheduling

# Cordon (prevent new scheduling, keep existing pods)
kubectl cordon node-01
kubectl uncordon node-01
```

## Debugging

```bash
# Pod won't start — check events
kubectl describe pod pod-name -n myapp
kubectl get events -n myapp --sort-by='.lastTimestamp' | tail -20

# Container logs
kubectl logs pod-name -n myapp -f --tail=200
kubectl logs pod-name -n myapp -c sidecar-container
kubectl logs pod-name -n myapp --previous         # Crashed container logs

# Exec into a running container
kubectl exec -it pod-name -n myapp -- /bin/bash
kubectl exec -it pod-name -n myapp -c container-name -- sh

# Run a debug pod in the same network
kubectl run debug --image=nicolaka/netshoot -it --rm -n myapp -- bash
# Inside: curl, dig, nslookup, tcpdump, etc.

# DNS debugging
kubectl run dns-test --image=busybox:1.36 -it --rm -- nslookup myapp.myapp.svc.cluster.local

# Check resource usage
kubectl top pods -n myapp --sort-by=memory
kubectl top nodes

# Copy files from/to pod
kubectl cp myapp/pod-name:/path/to/file ./local-file
kubectl cp ./local-file myapp/pod-name:/path/to/file

# Watch pods in real-time
kubectl get pods -n myapp -w

# Get pod YAML (see actual running spec)
kubectl get pod pod-name -n myapp -o yaml
```

## Common Troubleshooting

### Pod stuck in `Pending`

```bash
kubectl describe pod pod-name -n myapp
# Check Events section for:
# - Insufficient cpu/memory → increase node capacity or reduce requests
# - No nodes match selector → check nodeSelector/tolerations
# - PVC not bound → check PV availability / StorageClass
```

### Pod in `CrashLoopBackOff`

```bash
kubectl logs pod-name -n myapp --previous
kubectl describe pod pod-name -n myapp
# Common causes:
# - App exits with error → check logs
# - Liveness probe failing → check probe config
# - OOMKilled → increase memory limit
# - Missing config/secret → check env vars and mounts
```

### Pod in `ImagePullBackOff`

```bash
kubectl describe pod pod-name -n myapp
# Common causes:
# - Wrong image name/tag
# - Private registry without imagePullSecrets
# - Registry auth expired

# Create registry secret
kubectl create secret docker-registry regcred \
    --docker-server=registry.example.com \
    --docker-username=user \
    --docker-password=pass \
    -n myapp
```

### Service not reachable

```bash
# Check endpoints (should list pod IPs)
kubectl get endpoints myapp -n myapp
# Empty? → selector doesn't match pod labels

# Test from inside cluster
kubectl run curl --image=curlimages/curl -it --rm -- curl http://myapp.myapp.svc.cluster.local

# Check service → pod chain
kubectl get svc myapp -n myapp -o wide
kubectl get pods -n myapp -l app=myapp -o wide
```

### Evicted pods

```bash
# Find evicted pods
kubectl get pods -A --field-selector=status.phase=Failed | grep Evicted

# Clean up evicted pods
kubectl get pods -A --field-selector=status.phase=Failed -o json | \
    jq -r '.items[] | select(.status.reason=="Evicted") | "\(.metadata.namespace) \(.metadata.name)"' | \
    while read ns name; do kubectl delete pod "$name" -n "$ns"; done

# Check node pressure
kubectl describe node node-01 | grep -A5 Conditions
# DiskPressure, MemoryPressure, PIDPressure → True means trouble
```

### RBAC permission denied

```bash
# Check if you can do something
kubectl auth can-i create pods -n myapp
kubectl auth can-i '*' '*' --all-namespaces     # Cluster admin check

# Check service account permissions
kubectl auth can-i list pods --as=system:serviceaccount:myapp:default -n myapp
```
