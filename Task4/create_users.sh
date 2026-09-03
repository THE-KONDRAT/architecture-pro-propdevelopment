#!/bin/bash
# Users:
#   ivan    -> security    (secret-manager)
#   mike    -> devops      (cluster-manager, secret-viewer)
#   david   -> developers  (developer)
#   phillip -> analysts    (cluster-viewer)
#   olga    -> sre         (prod-viewer,prod-manager)

set -euo pipefail

MINIKUBE_CA_CERT="${HOME}/.minikube/ca.crt"
MINIKUBE_CA_KEY="${HOME}/.minikube/ca.key"
OUT_DIR="./certs"
KUBECONFIG_DIR="./kubeconfigs"

if [[ ! -f "$MINIKUBE_CA_CERT" || ! -f "$MINIKUBE_CA_KEY" ]]; then
  echo "ERROR: Minikube CA not found at ${HOME}/.minikube/"
  echo "Start Minikube: minikube start"
  exit 1
fi

mkdir -p "$OUT_DIR" "$KUBECONFIG_DIR"

declare -a USERS=(
  "ivan:security:PropDevelopment"
  "mike:devops:PropDevelopment"
  "david:developers:PropDevelopment"
  "phillip:analysts:PropDevelopment"
  "olga:sre:PropDevelopment"
)

API_SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="minikube")].cluster.server}')
[[ -z "$API_SERVER" ]] && API_SERVER="https://$(minikube ip):8443"

for entry in "${USERS[@]}"; do
  IFS=: read -r USERNAME GROUP ORG <<< "$entry"
  echo "Creating user: $USERNAME (OU=$GROUP, O=$ORG)"

# Make cert

  openssl genrsa -out "${OUT_DIR}/${USERNAME}.key" 2048 2>/dev/null
  openssl req -new -key "${OUT_DIR}/${USERNAME}.key" -out "${OUT_DIR}/${USERNAME}.csr" -subj "/CN=${USERNAME}/O=${ORG}/OU=${GROUP}"
  openssl x509 -req -in "${OUT_DIR}/${USERNAME}.csr" -CA "$MINIKUBE_CA_CERT" -CAkey "$MINIKUBE_CA_KEY" -CAcreateserial -out "${OUT_DIR}/${USERNAME}.crt" -days 365 2>/dev/null

# make kubeconfig
  local_config="${KUBECONFIG_DIR}/${USERNAME}.kubeconfig"
  kubectl config set-cluster minikube --certificate-authority="$MINIKUBE_CA_CERT" --server="$API_SERVER" --kubeconfig="$local_config" >/dev/null
  kubectl config set-credentials "$USERNAME" --client-certificate="${OUT_DIR}/${USERNAME}.crt" --client-key="${OUT_DIR}/${USERNAME}.key" --embed-certs=true --kubeconfig="$local_config" >/dev/null
  kubectl config set-context minikube --cluster=minikube --user="$USERNAME" --namespace=default --kubeconfig="$local_config" >/dev/null
  echo "... kubeconfig: ${local_config}"
done

echo ""
echo "Done."