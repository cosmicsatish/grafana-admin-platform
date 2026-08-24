# Grafana Admin Platform - Operations Guide

This guide describes how to perform day-to-day administrative operations on Grafana Cloud using GitOps.

All resources are declared under `chart/values/`. When changes are committed and pushed to `main`, **Argo CD** synchronizes the cluster state, and the **Grafana Operator** reconciles the resources directly with Grafana Cloud.

---

## Table of Contents

- [Overview](#overview)
- [Managing Teams](#managing-teams)
- [Managing Folders & Permissions](#managing-folders--permissions)
- [Managing Service Accounts](#managing-service-accounts)
- [Managing Loki LBAC Rules & Permissions](#managing-loki-lbac-rules--permissions)
- [Adding Dashboards](#adding-dashboards)
- [Adding Alert Rule Groups](#adding-alert-rule-groups)
- [Removing Resources](#removing-resources)
- [Using the Automated Onboarding Workflow](#using-the-automated-onboarding-workflow)
- [Local Validation & Testing](#local-validation--testing)
- [Verification & Troubleshooting](#verification--troubleshooting)

---

## Overview

The platform uses a **domain-driven values architecture**:

| Resource Type | Values File | Description |
| :--- | :--- | :--- |
| **Teams** | [`chart/values/Team.yaml`](chart/values/Team.yaml) | Team names, slugs, RBAC roles, Azure AD sync groups |
| **Folders** | [`chart/values/GrafanaFolder.yaml`](chart/values/GrafanaFolder.yaml) | Hierarchical folder tree and ACL permissions |
| **Service Accounts** | [`chart/values/GrafanaServiceAccount.yaml`](chart/values/GrafanaServiceAccount.yaml) | Service accounts with fine-grained fixed roles |
| **Datasources** | [`chart/values/GrafanaDatasource.yaml`](chart/values/GrafanaDatasource.yaml) | Declarative datasource configurations (e.g. Loki LBAC) |
| **LBAC Rules** | [`chart/values/TeamLBACRule.yaml`](chart/values/TeamLBACRule.yaml) | LogQL stream selectors for Loki log security |
| **Permissions** | [`chart/values/ResourcePermission.yaml`](chart/values/ResourcePermission.yaml) | Datasource-level query/admin permissions |

---

## Managing Teams

### 1. Declarative YAML Configuration

Edit [`chart/values/Team.yaml`](chart/values/Team.yaml):

```yaml
teams:
  - name: "Payments Team"           # Display name in Grafana Cloud
    slug: payments                   # Unique identifier (lowercase, hyphens only)
    owner: traiana                   # Owning organization / department
    roles:                           # Optional: Fine-grained Grafana Cloud RBAC roles
      - fixed:dashboards:reader
      - fixed:datasources:explorer
    syncGroups:                      # Optional: Azure AD Group Object IDs for SAML/SSO sync
      - "11111111-2222-3333-4444-555555555555"
```

### 2. Supported Roles
Common Grafana Cloud fixed roles include:
- `fixed:dashboards:reader` — View dashboards across permitted folders
- `fixed:dashboards:writer` — Create and edit dashboards in permitted folders
- `fixed:datasources:explorer` — Query datasources and use Explore mode
- `fixed:alerting:reader` — View alert rules and evaluation state

---

## Managing Folders & Permissions

### 1. Declarative YAML Configuration

Edit [`chart/values/GrafanaFolder.yaml`](chart/values/GrafanaFolder.yaml):

```yaml
folders:
  - title: "Payments Dashboards"
    uid: "folder-payments"           # Human-friendly UID (e.g. folder-payments)
    parentUid: "osttra"              # Parent folder UID (under root Osttra)
    owner: "payments"               # Owning team
    permissions:
      - role: "Viewer"               # Organization viewer permission
        permission: 1                # 1 = View
      - team: "payments"             # Owning team gets Admin permission
        permission: 4                # 4 = Admin (Manage), 2 = Edit, 1 = View
```

### 2. Permission Levels
- `1` = **View** (Read-only access)
- `2` = **Edit** (Can create and edit dashboards inside this folder)
- `4` = **Admin** (Can manage dashboards and folder access permissions)

---

## Managing Service Accounts

### 1. Declarative YAML Configuration

Edit [`chart/values/GrafanaServiceAccount.yaml`](chart/values/GrafanaServiceAccount.yaml):

```yaml
serviceAccounts:
  - name: "payments-ci-reader"
    role: "None"                      # ALWAYS set to "None" for least-privilege security
    owner: "payments"
    fixedRoles:                       # Fine-grained fixed roles
      - fixed:dashboards:reader
      - fixed:datasources:explorer
    secretName: "payments-ci-token"   # Kubernetes Secret where the operator stores the generated token
    tokenName: "payments-ci-token"
    tokenExpires: "2027-12-31T23:59:59Z"  # RFC3339 expiration date (policy enforced)
```

> [!IMPORTANT]
> **Security Policy**: Service accounts MUST NOT have global `Admin` or `Editor` roles. Always set `role: None` and grant scoped access via `fixedRoles`.

---

## Managing Loki LBAC Rules & Permissions

Label-Based Access Control (LBAC) restricts which log streams specific teams can query on the Loki LBAC datasource (`grafanacloud-cosmicsatish-logs-lbac`).

### 1. Define Team LogQL Selector

Edit [`chart/values/TeamLBACRule.yaml`](chart/values/TeamLBACRule.yaml):

```yaml
lbacRules:
  - name: payments
    team: payments
    datasource: grafanacloud-cosmicsatish-logs-lbac
    selector: '{ business_unit="payments", environment="prod" }'
```

### 2. Assign Datasource Query Permission

Edit [`chart/values/ResourcePermission.yaml`](chart/values/ResourcePermission.yaml):

```yaml
datasourcePermissions:
  - name: datasource-permissions-grafanacloud-logs-lbac
    manifestName: loki-lbac-access
    datasource: grafanacloud-cosmicsatish-logs-lbac
    assignments:
      - team: payments
        permission: Query
```

---

## Adding Dashboards

The platform features **zero-configuration auto-discovery** for dashboards:

1. Identify the target folder UID (e.g. `osttra`, `folder-payments`) in [`chart/values/GrafanaFolder.yaml`](chart/values/GrafanaFolder.yaml).
2. Create a folder under `chart/dashboards/` named exactly after the folder UID:
   ```bash
   mkdir -p chart/dashboards/folder-payments
   ```
3. Export your dashboard JSON from Grafana Cloud (**Share → Export → Save to file**) and place it into that directory:
   ```
   chart/dashboards/
   └── folder-payments/
       └── payments-overview.json
   ```
4. Commit and push:
   ```bash
   git add chart/dashboards/
   git commit -m "feat(dashboards): add payments overview dashboard"
   git push origin main
   ```
5. Helm and Argo CD will automatically render a `GrafanaDashboard` custom resource and deploy it into Grafana Cloud.

---

## Adding Alert Rule Groups

The platform features **zero-configuration auto-discovery** for alert rule groups:

1. Identify the target folder UID (e.g. `exported-alerts`, `prometheus-consolidated-alerts`) in [`chart/values/GrafanaFolder.yaml`](chart/values/GrafanaFolder.yaml).
2. Create a directory under `chart/alerts/` matching the folder UID:
   ```bash
   mkdir -p chart/alerts/exported-alerts
   ```
3. Place your alert rule group YAML in that folder:
   ```yaml
   # chart/alerts/exported-alerts/payment-alerts.yaml
   folderUID: exported-alerts
   name: payment-service-alerts
   interval: 1m
   rules:
     - uid: payments-high-latency
       title: PaymentServiceHighLatency
       condition: threshold
       data:
         # Query & condition data
   ```
4. Commit and push. All alert rule groups are provisioned with `editable: true` (unlocked / 100% UI-editable in Grafana Cloud).

---

## Removing Resources

### Safe Removal via GitOps
To delete any resource (folder, team, service account, alert rule, or dashboard):
1. Delete the resource's entry from its respective file under `chart/values/` (or delete the file from `chart/dashboards/` / `chart/alerts/`).
2. Commit and push to `main`.
3. Argo CD's automated pruning (`prune: true`) will safely remove the Custom Resource from Kubernetes and trigger the Grafana Operator to delete the resource from Grafana Cloud.

---

## Using the Automated Onboarding Workflow

If you prefer a UI form instead of editing YAML by hand:

1. Navigate to **GitHub → Actions → Automated Resource Onboarding**.
2. Click **Run workflow**.
3. Select your parameters:
   - **Action**: `add_or_update` or `remove`
   - **Resource Type**: `team`, `folder`, `service_account`, or `lbac_rule`
   - **Name / Title**: Display name (e.g. `Payments Team`)
   - **Identifier / Slug**: Stable UID (e.g. `payments`)
   - **Roles / Sync Groups / Selectors**: As appropriate
4. Click **Run workflow**. The GitHub Action will edit the YAML, run Conftest policy checks, and commit directly to `main`.

---

## Local Validation & Testing

Always validate before pushing:

```bash
# Validate YAML syntax, Helm linting, and OPA security policies
make validate

# Render the complete Kubernetes manifests to stdout for inspection
make render
```

---

## Verification & Troubleshooting

### Check Live Status in Kubernetes

```bash
# List all managed resources
kubectl get grafana,grafanafolder,grafanaserviceaccount,grafanadatasource,grafanamanifest \
  -n grafana-operator-configs

# Check folder synchronization status
kubectl get grafanafolder -n grafana-operator-configs -o wide

# Check service accounts
kubectl get grafanaserviceaccount -n grafana-operator-configs -o wide

# Check operator logs for any reconciliation errors
kubectl logs -n grafana-operator deploy/grafana-operator --tail=100 -f
```

### Check Argo CD Synchronization

```bash
# View Argo CD application status
kubectl get applications.argoproj.io -n argocd

# Trigger immediate refresh
kubectl -n argocd annotate application grafana-admin-platform \
  argocd.argoproj.io/refresh=hard --overwrite
```
