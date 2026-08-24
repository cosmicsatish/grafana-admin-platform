# Grafana Admin Platform

A **declarative, GitOps-driven platform** for managing Grafana Cloud resources — teams, folders, service accounts, datasources, LBAC rules, dashboards, and alert groups — via the [Grafana Operator](https://github.com/grafana/grafana-operator).

All resources are defined as YAML in this repository and reconciled automatically to your Grafana Cloud instance. No manual clicking in the Grafana UI required.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Quick Start (First-Time Setup)](#quick-start-first-time-setup)
- [GitOps Delivery Options](#gitops-delivery-options)
  - [Option A — Argo CD (Recommended)](#option-a--argo-cd-recommended)
  - [Option B — GitHub Actions (Argo CD Free)](#option-b--github-actions-argo-cd-free)
- [Operations Guide](#operations-guide)
  - [Add a Team](#add-a-team)
  - [Add a Folder](#add-a-folder)
  - [Add a Service Account](#add-a-service-account)
  - [Add a Loki LBAC Rule](#add-a-loki-lbac-rule)
  - [Add a Dashboard](#add-a-dashboard)
  - [Add Alert Rule Groups](#add-alert-rule-groups)
  - [Remove a Resource](#remove-a-resource)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Policy Guardrails](#policy-guardrails)
- [Known Limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
GitHub (source of truth)
     │
     │  push / PR
     ▼
┌─────────────────────┐
│  GitHub Actions CI  │  validate → credential scan → OPA policy → Helm lint + template
└─────────┬───────────┘
          │ (choose one delivery path)
          │
    ┌─────┴──────┐
    │            │
    ▼            ▼
 Argo CD    GitHub Actions Sync
 (Option A)  (Option B, Argo CD Free)
    │            │
    └─────┬──────┘
          │  helm template | kubectl apply --server-side
          ▼
  Kubernetes Cluster
  (Grafana Operator v5.24)
          │
          │  Reconciles CRDs to Grafana Cloud REST API
          ▼
  Grafana Cloud (your-stack.grafana.net)
  Teams / Folders / Datasources / Service Accounts /
  Alert Groups / Dashboards
```

---

## Repository Layout

```
grafana-admin-platform/
├── chart/                          # Helm chart — source of truth for all CRDs
│   ├── Chart.yaml
│   ├── values.yaml                 # Global config: Grafana URL, secret name, match labels
│   ├── values/                     # Domain-split values files (edit these for day-to-day ops)
│   │   ├── Team.yaml               # Teams: name, slug, RBAC roles, Azure AD sync groups
│   │   ├── GrafanaFolder.yaml      # Folder hierarchy with team ownership ACLs
│   │   ├── GrafanaServiceAccount.yaml  # Service accounts with fine-grained fixed roles
│   │   ├── GrafanaDatasource.yaml  # Datasource definitions (e.g. Loki LBAC datasource)
│   │   ├── TeamLBACRule.yaml       # Per-team Loki log stream selectors (stored, pending API support)
│   │   └── ResourcePermission.yaml # Datasource-level team/SA access assignments
│   └── templates/                  # Generic Helm templates — no changes needed for normal ops
│       ├── _helpers.tpl            # Shared labels and instanceSelector helpers
│       ├── Grafana.yaml            # Grafana CR pointing to external Grafana Cloud instance
│       ├── GrafanaFolder.yaml      # Iterates values/GrafanaFolder.yaml → GrafanaFolder CRs
│       ├── GrafanaServiceAccount.yaml  # Iterates values/GrafanaServiceAccount.yaml
│       ├── GrafanaDatasource.yaml  # Iterates values/GrafanaDatasource.yaml
│       ├── Team.yaml               # Iterates values/Team.yaml → GrafanaManifest/Team CRs
│       ├── TeamLBACRule.yaml       # Iterates values/TeamLBACRule.yaml → GrafanaManifest/TeamLBACRule CRs
│       ├── ResourcePermission.yaml # Iterates values/ResourcePermission.yaml
│       ├── GrafanaDashboard.yaml   # Auto-discovers chart/dashboards/**/*.json
│       └── GrafanaAlertRuleGroup.yaml  # Auto-discovers chart/alerts/**/*.yaml
│
├── chart/dashboards/               # (Optional) Place dashboard JSON files here to auto-provision
│   └── <folder-uid>/              # Directory name must match a folder UID in GrafanaFolder.yaml
│       └── my-dashboard.json
│
├── chart/alerts/                   # (Optional) Place alert rule group YAML files here
│   └── <folder-uid>/              # Directory name must match a folder UID in GrafanaFolder.yaml
│       └── my-alerts.yaml
│
├── deploy/
│   ├── argocd/
│   │   └── application.yaml        # Argo CD Application CR (Option A delivery)
│   ├── install.sh                  # One-shot bootstrap: installs operator + platform chart
│   └── operator-values.yaml        # Grafana Operator Helm values (log level, resync, etc.)
│
├── .github/
│   ├── CODEOWNERS                  # Require review from platform team on all changes
│   ├── dependabot.yml              # Auto-bump GitHub Actions versions
│   └── workflows/
│       ├── validate.yaml           # PR + push: YAML lint, credential scan, OPA policy, Helm lint
│       ├── onboard.yaml            # Manual: form-driven add/remove of teams, folders, SAs, LBAC rules
│       ├── sync.yaml               # Push to main: Argo CD-free direct cluster apply
│       └── drift-detection.yaml    # Nightly: chart integrity + policy check, opens Issue on failure
│
├── policy/
│   └── security.rego               # Conftest/OPA guardrails enforced in all CI workflows
│
└── Makefile                        # Local developer shortcuts: validate, render, install, sync, help
```

---

## How It Works

1. **Values-driven, not template-driven.** Day-to-day operations mean editing YAML files under `chart/values/`. The Helm templates in `chart/templates/` are generic and intentionally never need changing.

2. **Dashboards and alert groups are auto-discovered.** Drop a `.json` file under `chart/dashboards/<folder-uid>/` or a `.yaml` file under `chart/alerts/<folder-uid>/` and it is provisioned automatically with zero template changes.

3. **CI validates every change.** On every PR and push, GitHub Actions runs YAML linting, a hardcoded credential scanner, Helm lint + template render, and OPA policy checks via Conftest.

4. **Two delivery paths.** Choose Argo CD for full GitOps continuous reconciliation, or use the GitHub Actions `sync.yaml` workflow for a zero-dependency cluster apply.

5. **Human-friendly names everywhere.** All resource UIDs, folder names, team slugs, and service account names are readable strings — no random suffixes.

---

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| `kubectl` | 1.28 | Cluster management |
| `helm` | 3.12 | Chart rendering and install |
| Kubernetes cluster | any | Runs the Grafana Operator |
| Grafana Cloud stack | any | Target Grafana instance |
| Grafana Service Account Token | `Admin` role | Operator authentication |

---

## Quick Start (First-Time Setup)

### 1. Create the Grafana API token secret

```bash
kubectl create namespace grafana-operator-configs
kubectl -n grafana-operator-configs create secret generic grafanacloud-credentials \
  --from-literal=GRAFANA_API_KEY="<your-service-account-token>"
```

> **Important:** The token must belong to a service account with `Admin` role on your Grafana Cloud stack. Keep this secret out of Git — use your approved secrets manager (External Secrets Operator, Vault, etc.).

### 2. Run the bootstrap installer

```bash
GRAFANA_URL="https://your-stack.grafana.net" \
GRAFANA_TOKEN="glsa_..." \
./deploy/install.sh
```

This installs the Grafana Operator via Helm and deploys the platform chart in one idempotent step.

### 3. Verify

```bash
kubectl get grafana,grafanafolder,grafanaserviceaccount,grafanadatasource,grafanamanifest \
  -n grafana-operator-configs
```

---

## GitOps Delivery Options

### Option A — Argo CD (Recommended)

Argo CD continuously watches the repository and reconciles every push automatically.

**Install:**

```bash
kubectl apply -f deploy/argocd/application.yaml
```

**Configuration:** [`deploy/argocd/application.yaml`](deploy/argocd/application.yaml) uses:
- `syncPolicy.automated` with `prune: true` and `selfHeal: true`
- `syncOptions: [ServerSideApply=true]` for clean field-manager conflict resolution
- All values files are listed under `helm.valueFiles`

**Required cluster secrets:**
- `grafana-operator-configs/grafanacloud-credentials` — Grafana Admin API token

---

### Option B — GitHub Actions (Argo CD Free)

No external CD tool required. The `sync.yaml` workflow renders the Helm chart and applies manifests to your cluster via `kubectl` on every push to `main` that touches chart files.

**Setup — add these to your GitHub repository:**

| Name | Location | Value |
|------|----------|-------|
| `KUBECONFIG` | Secret | `base64 < ~/.kube/config` |
| `GRAFANA_API_KEY` | Secret | Grafana Cloud Admin service account token |
| `GRAFANA_URL` | Variable | `https://your-stack.grafana.net` |

**Steps:**
1. Encode your kubeconfig: `base64 < ~/.kube/config | pbcopy`
2. Add `KUBECONFIG` and `GRAFANA_API_KEY` under **Settings → Secrets and variables → Actions → Secrets**
3. Add `GRAFANA_URL` under **Settings → Secrets and variables → Actions → Variables**
4. Optionally create a GitHub Actions **environment** named `production` for approval gates
5. Push any change under `chart/` — `sync.yaml` fires automatically

**What the workflow does:**
1. Installs/upgrades the Grafana Operator via Helm (`--wait`)
2. Renders the full chart with `helm template`
3. Applies all manifests with `kubectl apply --server-side --force-conflicts`
4. Prunes resources no longer in Git with `--prune`
5. Prints a summary of all CRs in the namespace

---

## Operations Guide

All changes are made by editing values files under `chart/values/`. Commit and push to trigger CI validation and deployment.

For common operations you can also use the **Automated Resource Onboarding** GitHub Actions workflow (`onboard.yaml`) — a form-driven interface in the GitHub UI that edits the values files and opens a commit for you.

---

### Add a Team

**Edit [`chart/values/Team.yaml`](chart/values/Team.yaml):**

```yaml
teams:
  - name: "Payments Team"           # Display name in Grafana
    slug: payments                   # Unique identifier — no spaces, used in all references
    owner: traiana                   # Label for ownership tracking
    roles:                           # Optional: fine-grained RBAC roles
      - fixed:dashboards:reader
      - fixed:datasources:explorer
    syncGroups:                      # Optional: Azure AD Group Object IDs for SSO sync
      - "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**Via GitHub Actions form:**
Go to **Actions → Automated Resource Onboarding → Run workflow**, set `resource_type: team`, fill in `name`, `slug`, and optionally `roles` / `sync_groups`.

---

### Add a Folder

**Edit [`chart/values/GrafanaFolder.yaml`](chart/values/GrafanaFolder.yaml):**

```yaml
folders:
  - title: "Payments Dashboards"
    uid: "folder-payments"           # Stable, human-readable UID (used in dashboard/alert auto-discovery)
    parentUid: "osttra"              # Parent folder UID (omit for top-level)
    owner: "payments"
    permissions:
      - role: "Viewer"
        permission: 1               # 1=View, 2=Edit, 4=Admin
      - team: "payments"
        permission: 4               # Owner team gets Admin
```

**Via GitHub Actions form:**
Set `resource_type: folder`, `name: Payments Dashboards`, `slug: folder-payments`, `owner: payments`.

---

### Add a Service Account

**Edit [`chart/values/GrafanaServiceAccount.yaml`](chart/values/GrafanaServiceAccount.yaml):**

```yaml
serviceAccounts:
  - name: "payments-reader"
    role: "None"                      # Always None — use fixedRoles for least-privilege access
    owner: "payments"
    fixedRoles:
      - fixed:dashboards:reader
      - fixed:datasources:explorer
    secretName: "payments-reader-token"   # Kubernetes secret where the token is stored
```

**Via GitHub Actions form:**
Set `resource_type: service_account`, `name: payments-reader`, `slug: payments-reader`, optionally `roles: fixed:dashboards:reader`.

---

### Add a Loki LBAC Rule

Loki LBAC (Label-Based Access Control) restricts which log streams a team can query. The rules are declared in `TeamLBACRule.yaml` and will be applied automatically once the Grafana Operator's `TeamLBACRule` Kubernetes API path reaches general availability on Grafana Cloud.

> **Current status:** The `iam.grafana.app/v0alpha1` `TeamLBACRule` API endpoint returns HTTP 500 from Grafana Cloud (an upstream pre-GA limitation). The CRs are stored in the cluster and will reconcile correctly once the API reaches stable. Track progress: [grafana-operator GitHub](https://github.com/grafana/grafana-operator).

**Step 1 — Edit [`chart/values/TeamLBACRule.yaml`](chart/values/TeamLBACRule.yaml):**

```yaml
lbacRules:
  - name: payments
    team: payments                              # Must match team slug
    datasource: grafanacloud-cosmicsatish-logs-lbac
    selector: '{ business_unit="payments" }'   # LogQL stream selector
```

**Step 2 — Grant query permission in [`chart/values/ResourcePermission.yaml`](chart/values/ResourcePermission.yaml):**

```yaml
datasourcePermissions:
  - name: datasource-permissions-grafanacloud-logs-lbac
    assignments:
      - team: payments
        permission: Query
```

---

### Add a Dashboard

1. Ensure the target folder exists in `chart/values/GrafanaFolder.yaml`.
2. Export the dashboard JSON from Grafana UI (**Share → Export → Save to file**).
3. Place the JSON under `chart/dashboards/<folder-uid>/my-dashboard.json`.
4. Push — the `GrafanaDashboard.yaml` template auto-discovers and provisions it.

```
chart/dashboards/
└── folder-payments/          # Must match a folder UID in GrafanaFolder.yaml
    └── payments-overview.json
```

Dashboards are provisioned with `editable: true` — teams can refine them in the UI.

---

### Add Alert Rule Groups

1. Ensure the target folder exists in `chart/values/GrafanaFolder.yaml`.
2. Place the alert rule YAML under `chart/alerts/<folder-uid>/my-alerts.yaml`.
3. The file must declare the `folderUID` matching the parent directory name.
4. Push — the `GrafanaAlertRuleGroup.yaml` template auto-discovers and provisions it.

```yaml
# chart/alerts/folder-payments/critical.yaml
folderUID: folder-payments
name: payments-critical
interval: 1m
rules:
  - uid: some-stable-uid
    title: PaymentServiceDown
    condition: threshold
    data: [...]
```

Alert groups are provisioned with `editable: true` — no provenance lock.

---

### Remove a Resource

**Via GitHub Actions form:**
1. Go to **Actions → Automated Resource Onboarding → Run workflow**
2. Set `action: remove` and fill in `slug`/`name`
3. Type `DELETE` in the `confirm_delete` safety field

**Manually:** Delete the entry from the relevant values file, commit, and push. Argo CD (with `prune: true`) or the `sync.yaml` workflow (with `--prune`) will remove the Kubernetes CR and Grafana Cloud resource automatically.

---

## GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| [`validate.yaml`](.github/workflows/validate.yaml) | PR + push to `main` | YAML lint, credential scan, OPA policy, Helm lint + template render |
| [`onboard.yaml`](.github/workflows/onboard.yaml) | Manual (`workflow_dispatch`) | Form-driven add/remove for teams, folders, service accounts, LBAC rules |
| [`sync.yaml`](.github/workflows/sync.yaml) | Push to `main` (chart changes) + manual | Argo CD-free: render chart, apply to cluster via `kubectl` |
| [`drift-detection.yaml`](.github/workflows/drift-detection.yaml) | Nightly 02:00 UTC + manual | Full chart render + policy check; opens GitHub Issue on failure |

### Secrets and Variables required for `sync.yaml`

| Name | Type | Description |
|------|------|-------------|
| `KUBECONFIG` | Secret | Base64-encoded kubeconfig for cluster access |
| `GRAFANA_API_KEY` | Secret | Grafana Cloud Admin service account token |
| `GRAFANA_URL` | Variable | `https://your-stack.grafana.net` |

---

## Policy Guardrails

All CI runs execute Conftest against `policy/security.rego`. Current rules:

| Rule | What it enforces |
|------|-----------------|
| No `Admin` base role on service accounts | Must use `role: None` + `fixedRoles` |
| No `Editor` base role on service accounts | Must use `role: None` + `fixedRoles` |
| Token expiry required | Every service account must specify `tokenExpires` |
| Folder UID required | Every folder must have a stable `uid` field |
| Team slug required | Every team must have a `slug` identifier |

Violations block the PR. To add a new policy, edit [`policy/security.rego`](policy/security.rego).

---

## Known Limitations

### Loki LBAC via `TeamLBACRule` Kubernetes API (pending GA)

The Grafana Operator syncs `TeamLBACRule` resources through the `iam.grafana.app/v0alpha1` Kubernetes-style API on Grafana Cloud. This endpoint currently returns `HTTP 500 Internal Server Error` — it is a pre-GA API. The CRs apply cleanly to the cluster and will automatically reconcile to Grafana Cloud once Grafana promotes this API to stable.

LBAC rules are intentionally stored in `chart/values/TeamLBACRule.yaml` now so that the configuration is ready and version-controlled. No action needed beyond keeping the values file up to date.

### `ResourcePermission` and `TeamLBACRule` GrafanaManifest errors in operator logs

For the same reason, `GrafanaManifest` resources of kind `ResourcePermission` also report `applying resource: fetching existing resource: unknown` in operator logs. This is expected and non-breaking — all other resource types (folders, teams, service accounts, datasources, dashboards, alert groups) reconcile correctly.

---

## Troubleshooting

### Check operator logs

```bash
kubectl logs -n grafana-operator deploy/grafana-operator --tail=100 -f
```

### Check resource sync status

```bash
# All resources at a glance
kubectl get grafana,grafanadatasource,grafanafolder,grafanaserviceaccount,grafanamanifest \
  -n grafana-operator-configs

# Describe a specific resource for events and status conditions
kubectl describe grafanafolder <folder-name> -n grafana-operator-configs
kubectl describe grafanamanifest <team-name>-team -n grafana-operator-configs
```

### Check alert group sync status

```bash
kubectl get grafanaalertrulegroup -n grafana-operator-configs
kubectl describe grafanaalertrulegroup <name> -n grafana-operator-configs
```

### Validate chart locally

```bash
make validate    # YAML lint + Helm lint + template render
make render      # Print full rendered manifest to stdout
make help        # List all available make targets
```

### Force Argo CD resync

```bash
kubectl -n argocd annotate application grafana-admin-platform \
  argocd.argoproj.io/refresh=hard --overwrite
```

### Force GitHub Actions sync

Run the **GitOps Sync (Argo CD Free)** workflow manually from the **Actions** tab.

### Secret not found in operator logs

Ensure the secret is in the **same namespace as the `Grafana` CR**:

```bash
kubectl get secret grafanacloud-credentials -n grafana-operator-configs
# If missing:
kubectl -n grafana-operator-configs create secret generic grafanacloud-credentials \
  --from-literal=GRAFANA_API_KEY="<your-token>"
```

### Stale `Grafana` CR in wrong namespace

If the operator logs show authentication errors from a different namespace, check for stale CRs:

```bash
kubectl get grafana -A
# Delete any stale instances in the wrong namespace
kubectl delete grafana grafanacloud-osttra -n default
```
