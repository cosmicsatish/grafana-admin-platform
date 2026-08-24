# Grafana Admin Platform

A **declarative, GitOps-driven platform** for managing Grafana Cloud resources — teams, folders, service accounts, datasources, LBAC rules, dashboards, and alert groups — via the [Grafana Operator](https://github.com/grafana/grafana-operator) and [Argo CD](https://argo-cd.readthedocs.io/).

All resources are defined declaratively as YAML in this repository and reconciled continuously to your Grafana Cloud instance.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Quick Start (Bootstrap Installation)](#quick-start-bootstrap-installation)
- [GitOps Deployment with Argo CD](#gitops-deployment-with-argo-cd)
- [Operations Guide](#operations-guide)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Policy Guardrails](#policy-guardrails)
- [Known Limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
GitHub Repository (Source of Truth)
     │
     │  Pull Request / Push to main
     ▼
┌────────────────────────────────────────────────────────┐
│  GitHub Actions CI (validate.yaml)                     │
│  - YAML Syntax & Credential Scanner                    │
│  - OPA / Conftest Policy Guardrails (security.rego)    │
│  - Helm Lint & Template Integrity                      │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│  Argo CD (deploy/argocd/application.yaml)              │
│  - Continuous GitOps sync & auto-pruning               │
│  - Server-Side Apply conflict management               │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│  Kubernetes Cluster (grafana-operator v5.24)           │
│  - Namespace: grafana-operator-configs                 │
│  - Reconciles CRDs against Grafana Cloud REST APIs     │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│  Grafana Cloud (cosmicsatish.grafana.net)              │
│  - Folders & Team ACL Permissions (42+ Folders)        │
│  - Teams with Azure AD Sync & RBAC Roles (39 Teams)    │
│  - Service Accounts with Fine-Grained Roles (19 SAs)   │
│  - Custom Datasources (Loki LBAC Datasource)           │
│  - Dashboards & UI-Editable Alert Rule Groups          │
└────────────────────────────────────────────────────────┘
```

---

## Repository Layout

```
grafana-admin-platform/
├── chart/                          # Helm chart — source of truth for all Kubernetes CRDs
│   ├── Chart.yaml
│   ├── values.yaml                 # Global settings: Grafana URL, secret references, match labels
│   ├── values/                     # Domain-driven values files (edit these for routine ops)
│   │   ├── Team.yaml               # Teams: display names, slugs, RBAC roles, Azure AD groups
│   │   ├── GrafanaFolder.yaml      # Folder tree hierarchy with fine-grained team ACLs
│   │   ├── GrafanaServiceAccount.yaml  # Service accounts with fixedRoles and base role 'None'
│   │   ├── GrafanaDatasource.yaml  # Declarative datasource definitions (e.g. Loki LBAC)
│   │   ├── TeamLBACRule.yaml       # Per-team Loki log stream selectors
│   │   └── ResourcePermission.yaml # Datasource-level team and service account permissions
│   └── templates/                  # Reusable Helm templates (no manual edits needed)
│       ├── _helpers.tpl            # Common labels and instance selector templates
│       ├── Grafana.yaml            # Grafana instance CR connecting to Grafana Cloud
│       ├── GrafanaFolder.yaml      # Generates GrafanaFolder CRs
│       ├── GrafanaServiceAccount.yaml  # Generates GrafanaServiceAccount CRs
│       ├── GrafanaDatasource.yaml  # Generates GrafanaDatasource CRs
│       ├── Team.yaml               # Generates GrafanaManifest/Team CRs
│       ├── TeamLBACRule.yaml       # Generates GrafanaManifest/TeamLBACRule CRs
│       ├── ResourcePermission.yaml # Generates GrafanaManifest/ResourcePermission CRs
│       ├── GrafanaDashboard.yaml   # Auto-discovers dashboards under chart/dashboards/**/*.json
│       └── GrafanaAlertRuleGroup.yaml  # Auto-discovers alert groups under chart/alerts/**/*.yaml
│
├── chart/dashboards/               # (Optional) Drop dashboard JSON files here by folder UID
│   └── <folder-uid>/              # e.g. chart/dashboards/osttra/grafana-operator.json
│
├── chart/alerts/                   # (Optional) Drop alert rule group YAML files here by folder UID
│   └── <folder-uid>/              # e.g. chart/alerts/exported-alerts/linux-nodes.yaml
│
├── deploy/
│   ├── argocd/
│   │   └── application.yaml        # Argo CD Application manifest for continuous GitOps
│   ├── install.sh                  # Bootstrap script for installing operator and chart
│   └── operator-values.yaml        # Official Grafana Operator Helm values
│
├── .github/
│   ├── CODEOWNERS                  # Mandatory platform team reviews
│   ├── dependabot.yml              # Weekly automated dependency and action updates
│   └── workflows/
│       ├── validate.yaml           # CI: YAML lint, credential scan, Conftest OPA, Helm lint
│       ├── onboard.yaml            # Self-service UI for onboarding teams, folders, SAs, rules
│       └── drift-detection.yaml    # Nightly: verifies chart integrity and policy compliance
│
├── policy/
│   └── security.rego               # Open Policy Agent (OPA) security guardrails
│
├── OPERATIONS.md                   # Comprehensive Operations Guide for day-to-day administration
└── Makefile                        # Local commands: make validate, make render, make install
```

---

## How It Works

1. **Values-Driven Architecture**: All organizational resources (teams, folders, service accounts, datasources, permissions) are defined in domain-split YAML files under `chart/values/`.
2. **Zero-Config Asset Auto-Discovery**: Dashboards and alert rule groups dropped into `chart/dashboards/<folder-uid>/` or `chart/alerts/<folder-uid>/` are automatically discovered and provisioned into their target Grafana folders.
3. **Automated CI Validation**: Every pull request and push to `main` is validated with YAML linters, credential leak scanners, OPA policy guardrails, and Helm template rendering.
4. **GitOps with Argo CD**: Argo CD continuously synchronizes the Helm chart into Kubernetes using Server-Side Apply and automated pruning.
5. **Least-Privilege RBAC**: Service accounts use `role: None` with fine-grained `fixedRoles`, eliminating excessive global permissions.

---

## Prerequisites

| Tool / Requirement | Minimum Version | Purpose |
| :--- | :--- | :--- |
| **kubectl** | `v1.28+` | Kubernetes cluster CLI |
| **helm** | `v3.12+` | Helm chart rendering and deployment |
| **Argo CD** | `v2.8+` | Continuous GitOps reconciliation engine |
| **Grafana Cloud Account** | Any | Target Grafana Cloud instance |
| **Grafana Service Account** | `Admin` role | API authentication token for operator sync |

---

## Quick Start (Bootstrap Installation)

### 1. Create the API Token Secret in Kubernetes

Create the Kubernetes Secret containing your Grafana Cloud admin token:

```bash
kubectl create namespace grafana-operator-configs
kubectl -n grafana-operator-configs create secret generic grafanacloud-credentials \
  --from-literal=GRAFANA_API_KEY="<your-grafana-service-account-token>"
```

### 2. Run the Bootstrap Installer

```bash
GRAFANA_URL="https://cosmicsatish.grafana.net" \
GRAFANA_TOKEN="<your-token>" \
./deploy/install.sh
```

This installs the Grafana Operator (`v5.24.0`) in the `grafana-operator` namespace and deploys the platform chart into `grafana-operator-configs`.

---

## GitOps Deployment with Argo CD

Once bootstrapped, connect the repository to Argo CD for automated continuous synchronization:

```bash
kubectl apply -f deploy/argocd/application.yaml
```

The [`deploy/argocd/application.yaml`](deploy/argocd/application.yaml) configuration provides:
- **Automated Sync & Pruning**: Resources removed from Git are automatically deleted from Kubernetes and Grafana Cloud (`prune: true`, `selfHeal: true`).
- **Server-Side Apply**: Conflict-free declarative management (`ServerSideApply=true`).
- **Multi-File Values Loading**: Automatically loads all files from `chart/values/*.yaml`.

---

## Operations Guide

For complete, step-by-step instructions on performing day-to-day administrative tasks, refer to the dedicated **[Operations Guide (OPERATIONS.md)](OPERATIONS.md)**:

- [Managing Teams & Azure AD Groups](OPERATIONS.md#managing-teams)
- [Managing Folders & ACL Permissions](OPERATIONS.md#managing-folders--permissions)
- [Managing Service Accounts & Fixed Roles](OPERATIONS.md#managing-service-accounts)
- [Managing Loki LBAC Rules & Datasource Access](OPERATIONS.md#managing-loki-lbac-rules--permissions)
- [Adding Dashboards with Zero-Config Auto-Discovery](OPERATIONS.md#adding-dashboards)
- [Adding Alert Rule Groups (UI-Editable / Unlocked)](OPERATIONS.md#adding-alert-rule-groups)
- [Removing Resources Safely via GitOps](OPERATIONS.md#removing-resources)
- [Using the Automated Onboarding Workflow](OPERATIONS.md#using-the-automated-onboarding-workflow)

---

## GitHub Actions Workflows

| Workflow | Trigger | Description |
| :--- | :--- | :--- |
| **[`validate.yaml`](.github/workflows/validate.yaml)** | PR & Push to `main` | Validates YAML syntax, scans for plaintext credentials, evaluates OPA security policies, and runs `helm lint`. |
| **[`onboard.yaml`](.github/workflows/onboard.yaml)** | Manual (`workflow_dispatch`) | Interactive web form in GitHub UI to add or remove teams, folders, service accounts, and LBAC rules safely. |
| **[`drift-detection.yaml`](.github/workflows/drift-detection.yaml)** | Nightly (02:00 UTC) & Manual | Validates chart integrity and policy compliance against the live repository, opening an issue upon any failure. |

---

## Policy Guardrails

All pull requests and commits are evaluated against OPA policies defined in [`policy/security.rego`](policy/security.rego):

- **No Global Admin Service Accounts**: SAs cannot be assigned global `role: Admin`.
- **No Global Editor Service Accounts**: SAs cannot be assigned global `role: Editor`.
- **Enforced Token Expiration**: All service account tokens must specify an explicit expiration timestamp (`tokenExpires`).
- **Stable Folder UIDs**: Every folder must specify a human-friendly, stable `uid`.
- **Team Slugs Required**: Every team must specify a URL-safe `slug`.

---

## Known Limitations

### Loki LBAC via `TeamLBACRule` Kubernetes API (Pending GA)
The Grafana Operator manages `TeamLBACRule` resources through the `iam.grafana.app/v0alpha1` API on Grafana Cloud. This endpoint currently returns `HTTP 500 Internal Server Error` as it is a pre-GA experimental API in Grafana Cloud.

- **Current State**: All 25 team LBAC stream selectors and datasource permissions are safely version-controlled in [`chart/values/TeamLBACRule.yaml`](chart/values/TeamLBACRule.yaml) and [`chart/values/ResourcePermission.yaml`](chart/values/ResourcePermission.yaml).
- **Future Resolution**: Once Grafana Cloud promotes the `TeamLBACRule` API to stable, the Operator will automatically reconcile these rules without requiring any configuration changes.

---

## Troubleshooting

### View Resource Synchronization in Kubernetes

```bash
# Check all managed Grafana resources
kubectl get grafana,grafanafolder,grafanaserviceaccount,grafanadatasource,grafanamanifest \
  -n grafana-operator-configs

# Inspect folder synchronization details
kubectl describe grafanafolder <folder-name> -n grafana-operator-configs

# Check Grafana Operator reconciliation logs
kubectl logs -n grafana-operator deploy/grafana-operator --tail=100 -f
```

### Validate and Render Chart Locally

```bash
# Run full local validation (YAML syntax, Helm lint, and OPA policies)
make validate

# Render the complete Helm chart manifests to stdout
make render
```

### Trigger Immediate Argo CD Sync

```bash
kubectl -n argocd annotate application grafana-admin-platform \
  argocd.argoproj.io/refresh=hard --overwrite
```
