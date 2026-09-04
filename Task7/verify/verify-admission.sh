#!/usr/bin/env bash
set -u
NS=audit-zone
cd "$(dirname "$0")/.."

echo "••• 1. Checking PodSecurity on namespace $NS •••"
kubectl get ns "$NS" -o jsonpath='{.metadata.labels}' | tr ',' '\n' | grep pod-security || {
  echo "ERROR: PodSecurity labels not found"; exit 1;
}

echo
echo "••• 2. Rejecting insecure manifests •••"
rc=0
for f in insecure-manifests/*.yaml; do
  err=$(kubectl apply -f "$f" 2>&1)
  if [ $? -ne 0 ]; then
    echo "OK (rejected): $f"
    echo "$err" | head -3 | sed 's/^/    /'
  else
    echo "ERROR: $f is accepted but must be rejected!"; rc=1
  fi
done

echo
echo "••• 3. Safe manifests must be accepted •••"
for f in secure-manifests/*.yaml; do
  if kubectl apply -f "$f" 2>/dev/null; then
    echo "OK (accepted): $f"
  else
    echo "ERROR: safe manifest $f rejected!"; rc=1
  fi
done

echo
kubectl get pods -n "$NS" -o wide 2>/dev/null
echo
[ $rc -eq 0 ] && echo "••• All checks passed •••" || echo "••• There are some errors •••"
exit $rc
