SHELL := /bin/bash

VALUES_FLAGS := -f chart/values/Team.yaml -f chart/values/GrafanaFolder.yaml -f chart/values/TeamLBACRule.yaml -f chart/values/GrafanaServiceAccount.yaml -f chart/values/ResourcePermission.yaml -f chart/values/GrafanaDatasource.yaml

.PHONY: validate render install

validate:
	@python3 -c 'import pathlib,yaml; [list(yaml.safe_load_all(p.read_text())) for p in pathlib.Path(".").rglob("*.yaml") if ".git" not in p.parts and "templates" not in p.parts]; print("YAML syntax OK")'
	@helm lint chart/ $(VALUES_FLAGS)
	@helm template grafana-admin chart/ $(VALUES_FLAGS) >/dev/null
	@echo "All validations passed successfully."

render:
	@helm template grafana-admin chart/ $(VALUES_FLAGS)

install:
	@./deploy/install.sh
