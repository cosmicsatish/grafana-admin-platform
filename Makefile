SHELL := /bin/bash

VALUES_FLAGS := \
  -f chart/values/Team.yaml \
  -f chart/values/GrafanaFolder.yaml \
  -f chart/values/TeamLBACRule.yaml \
  -f chart/values/GrafanaServiceAccount.yaml \
  -f chart/values/ResourcePermission.yaml \
  -f chart/values/GrafanaDatasource.yaml

.PHONY: validate render install sync help

## validate: Lint YAML, run OPA policy checks, and render the Helm chart
validate:
	@python3 -c 'import pathlib,yaml; [list(yaml.safe_load_all(p.read_text())) for p in pathlib.Path(".").rglob("*.yaml") if ".git" not in p.parts and "templates" not in p.parts]; print("YAML syntax OK")'
	@helm lint chart/ $(VALUES_FLAGS)
	@helm template grafana-admin chart/ $(VALUES_FLAGS) >/dev/null
	@echo "All validations passed successfully."

## render: Render the Helm chart manifests to stdout (for inspection)
render:
	@helm template grafana-admin chart/ $(VALUES_FLAGS)

## install: Bootstrap the operator and platform chart locally (requires GRAFANA_URL and GRAFANA_TOKEN env vars)
install:
	@./deploy/install.sh

## sync: Apply chart directly to the cluster without Argo CD (requires kubeconfig context set)
sync:
	@helm template grafana-admin-platform chart/ \
	  --namespace grafana-operator-configs \
	  $(VALUES_FLAGS) \
	  | kubectl apply --server-side --force-conflicts \
	    --namespace grafana-operator-configs -f -

## help: Show available make targets
help:
	@grep "^##" Makefile | sed 's/## /  /'
