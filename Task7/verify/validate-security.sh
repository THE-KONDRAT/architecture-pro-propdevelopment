#!/usr/bin/env bash
set -u
NS=audit-zone

echo "1. Check Gatekeeper pods"
kubectl get pods -n gatekeeper-system 2>/dev/null | grep -E 'gatekeeper-controller|gatekeeper-audit' || {
  echo "ERROR: Gatekeeper pods not found."
  echo "Install: kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml"
  exit 1
}

echo
echo "2. Check ConstraintTemplates are created"
kubectl get constrainttemplates | grep -E 'k8spsp(privileged|hostfilesystem|runasnonroot|readonly)' || {
  echo "ERROR: constraint templates not found"; exit 1
}

echo
echo "3. Constraints are applied"
kubectl get constraints 2>/dev/null | grep -E 'no-privileged|no-hostpath|require-runasnonroot|require-readonly' || {
  echo "ERROR: constraints not found"; exit 1
}

echo
echo "4. Gatekeeper still rejects a privileged pod"
tmp=$(mktemp)
cat > "$tmp" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-check-pod
  namespace: $NS
spec:
  containers:
    - name: nginx
      image: nginx
      securityContext:
        privileged: true
EOF
err=$(kubectl apply -f "$tmp" 2>&1)
if [ $? -ne 0 ]; then
  echo "OK: Gatekeeper rejected the privileged pod"
  echo "$err" | grep -io 'denied.*' | head -1 | sed 's/^/    /'
else
  echo "FAIL: Gatekeeper did NOT reject the privileged pod!"; rm -f "$tmp"; exit 1
fi
rm -f "$tmp"

echo
echo "••• All checks passed •••"