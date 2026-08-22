# Grafana Administration Platform

Production-oriented, GitOps-driven Grafana administration platform managing **Teams**, **Azure AD Group Sync**, **Parent/Child Folders & Permissions**, **Fine-Grained Fixed RBAC Roles**, **Datasource Access / LBAC**, and **Service Accounts** via **Argo CD**, **Helm**, and the **Grafana Operator**.

---

## 1. Core Platform Capabilities

- **Pure GitOps with Argo CD**: Argo CD continuously syncs and reconciles your repository with zero manual intervention.
- **Root `Osttra` Hierarchy**: All 41+ product and team folders are organized as child folders nested under the root **`Osttra`** parent folder.
- **Automated Team Ownership**: Every folder has its dedicated team automatically assigned **`permission: 4` (Admin / Owner)**.
- **Teams & Azure AD (Entra ID) Group Sync**: All 39+ teams are created and synchronized with Azure AD Object GUIDs (`syncGroups`).
- **Fine-Grained Fixed Roles (RBAC)**: Teams and service accounts are assigned their granular fixed roles (`fixed:alerting:admin`, `fixed:dashboards:writer`, `plugins:k6-app:editor`, etc.).
- **Datasource Query & LBAC Permissions**: Automatic creation and assignment of scoped query roles (`datasources:query` on `loki-lbac`, `prom`, `infinity`) for all teams.
- **Service Accounts & Token Secrets**: Managed service accounts with base roles and token generation.

---

## 2. Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                             HUMAN-MAINTAINED VALUES                         │
│   chart/values/Team.yaml                 chart/values/GrafanaFolder.yaml    │
│   chart/values/TeamLBACRule.yaml         chart/values/GrafanaServiceAccount │
│   chart/values/ResourcePermission.yaml   chart/values.yaml                  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Git Commit & Push)
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB GITOPS REPOSITORY                           │
│              https://github.com/cosmicsatish/grafana-admin-platform         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Argo CD Synchronization)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ARGO CD (Application: Synced & Healthy)              │
│                 Reconciles K8s Manifests + Native GitOps Reconciler         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (REST API & Operator Reconciliation)
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GRAFANA CLOUD INSTANCE                              │
│                    https://cosmicsatish.grafana.net                         │
│   - Osttra Root Folder & 41 Nested Child Folders (Team Admin Ownership)     │
│   - 40 Teams with Azure AD Sync & Granular Fixed RBAC Roles                 │
│   - Scoped Datasource Access (loki-lbac, prom, infinity)                    │
│   - Service Accounts with Roles & Token Management                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Repository Structure

```text
.
├── chart/                              # Native Helm Chart (zero custom scripts)
│   ├── Chart.yaml                      # Chart metadata
│   ├── values.yaml                     # Global Grafana connection settings
│   ├── values/                         # Modular values files named by Kind
│   │   ├── Team.yaml                   # 39+ teams, Azure AD Object IDs, and roles
│   │   ├── GrafanaFolder.yaml          # Osttra root + 41 nested folders with team ownership
│   │   ├── TeamLBACRule.yaml           # 26+ Loki LBAC log stream selectors
│   │   ├── GrafanaServiceAccount.yaml  # 19 service accounts with fixedRoles
│   │   └── ResourcePermission.yaml     # Datasource query/admin permissions
│   └── templates/                      # Helm templates
│       ├── _helpers.tpl
│       ├── Grafana.yaml                # External Grafana instance CR
│       ├── GrafanaFolder.yaml          # Generates GrafanaFolder CRs
│       ├── GrafanaServiceAccount.yaml  # Generates GrafanaServiceAccount CRs
│       ├── reconciler.yaml             # Native GitOps Reconciler (Folders, Teams, Roles, LBAC)
│       ├── Team.yaml                   # Generates GrafanaManifest Team CRs
│       ├── TeamLBACRule.yaml           # Generates GrafanaManifest TeamLBACRule CRs
│       └── ResourcePermission.yaml     # Generates GrafanaManifest ResourcePermission CRs
├── deploy/
│   ├── install.sh                      # Bootstrap script
│   ├── operator-values.yaml            # Grafana Operator Helm values
│   └── argocd/
│       └── application.yaml            # Argo CD Application manifest
├── .github/
│   └── workflows/
│       ├── validate.yaml               # PR validation (Helm lint, template dry-run)
│       └── deploy.yaml                 # Deployment workflow
├── Makefile                            # make validate, make render, make install
└── README.md                           # Master platform documentation
```

---

## 4. How to Inspect Live Environment

### Argo CD Dashboard
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- **URL**: [https://localhost:8080](https://localhost:8080)
- **Username**: `admin`
- **Password**: `3OAZNkNMS9vj7D57`

### Check Kubernetes Status
```bash
# Check Argo CD Application:
kubectl get application -n argocd grafana-admin-platform

# Check cluster resources:
kubectl get grafanas,grafanafolders,grafanaserviceaccounts -n grafana-admin
```

### Check Live Grafana Cloud
Visit **[https://cosmicsatish.grafana.net](https://cosmicsatish.grafana.net)** to view:
- Folders organized under parent **`Osttra`**
- Teams, Azure AD sync, and assigned fixed roles
- Service accounts and tokens
- Scoped datasource query access
