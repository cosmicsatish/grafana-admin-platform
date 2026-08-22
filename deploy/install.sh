#!/usr/bin/env bash
set -euo pipefail

# This script installs/reconciles the official Grafana Operator and
# deploys the declarative Grafana Admin Platform Helm chart.

OPERATOR_VERSION="${GRAFANA_OPERATOR_VERSION:-5.24.0}"
OPERATOR_NAMESPACE="${GRAFANA_OPERATOR_NAMESPACE:-grafana-operator}"
RESOURCE_NAMESPACE="${GRAFANA_RESOURCE_NAMESPACE:-grafana-admin}"
RELEASE_NAME="${GRAFANA_OPERATOR_RELEASE_NAME:-grafana-operator}"
CHART_RELEASE_NAME="${GRAFANA_ADMIN_RELEASE_NAME:-grafana-admin}"
GRAFANA_URL="${GRAFANA_URL:-https://cosmicsatish.grafana.net}"
GRAFANA_SECRET_NAME="${GRAFANA_SECRET_NAME:-grafana-admin-token}"
GRAFANA_TOKEN="${GRAFANA_TOKEN:-}"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required command not found: $1" >&2; exit 1; }
}

need kubectl
need helm

if [[ -z "$GRAFANA_URL" && -t 0 ]]; then
  read -r -p "Grafana URL: " GRAFANA_URL
fi
[[ -n "$GRAFANA_URL" ]] || { echo "ERROR: GRAFANA_URL is required" >&2; exit 1; }

kubectl create namespace "$OPERATOR_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$RESOURCE_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Manage Admin Token Secret
if ! kubectl -n "$RESOURCE_NAMESPACE" get secret "$GRAFANA_SECRET_NAME" >/dev/null 2>&1; then
  if [[ -z "$GRAFANA_TOKEN" && -t 0 ]]; then
    read -r -s -p "Grafana service-account token (input hidden): " GRAFANA_TOKEN
    printf '\n'
  fi
  if [[ -n "$GRAFANA_TOKEN" ]]; then
    kubectl -n "$RESOURCE_NAMESPACE" create secret generic "$GRAFANA_SECRET_NAME" \
      --from-literal=token="$GRAFANA_TOKEN" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi
fi

if ! kubectl -n "$RESOURCE_NAMESPACE" get secret "$GRAFANA_SECRET_NAME" >/dev/null 2>&1; then
  cat >&2 <<MSG
ERROR: Secret $RESOURCE_NAMESPACE/$GRAFANA_SECRET_NAME does not exist.
Create it using your approved secret manager or rerun interactively so the token can be entered securely.
MSG
  exit 1
fi

# 1. Install/upgrade official Grafana Operator
helm upgrade --install "$RELEASE_NAME" \
  "oci://ghcr.io/grafana/helm-charts/grafana-operator" \
  --version "$OPERATOR_VERSION" \
  --namespace "$OPERATOR_NAMESPACE" \
  --create-namespace \
  --values deploy/operator-values.yaml

# 2. Install/upgrade declarative Grafana Admin Platform Chart
helm upgrade --install "$CHART_RELEASE_NAME" chart/ \
  --namespace "$RESOURCE_NAMESPACE" \
  --create-namespace \
  -f chart/values/Team.yaml \
  -f chart/values/GrafanaFolder.yaml \
  -f chart/values/TeamLBACRule.yaml \
  -f chart/values/GrafanaServiceAccount.yaml \
  -f chart/values/ResourcePermission.yaml \
  --set grafana.url="$GRAFANA_URL" \
  --set grafana.secretName="$GRAFANA_SECRET_NAME"

echo
echo "Grafana Administration Platform deployed successfully."
echo "Operator: $RELEASE_NAME in namespace $OPERATOR_NAMESPACE"
echo "Admin Chart: $CHART_RELEASE_NAME in namespace $RESOURCE_NAMESPACE"
echo "All folders, teams, datasources, LBAC rules, and service accounts are now managed declaratively."
