# Grafana Administration Platform

Production-oriented, 100% declarative GitOps platform managing **Teams**, **Azure AD (Entra ID) Group Sync**, **Parent/Child Folders & Permissions**, **Fine-Grained Fixed RBAC Roles**, **Loki Log-Based Access Control (LBAC)**, and **Service Accounts** via **Argo CD**, **Helm**, and the **Grafana Operator** (with zero custom scripts).

---

## 1. Architecture Overview

All Grafana resources are modeled natively in modular Helm value files and rendered into Kubernetes Custom Resources:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MODULAR DECLARATIVE VALUES                         │
│   chart/values/Team.yaml                  chart/values/GrafanaFolder.yaml   │
│   chart/values/TeamLBACRule.yaml          chart/values/GrafanaServiceAccount│
│   chart/values/ResourcePermission.yaml    chart/values.yaml                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Git Commit & Push)
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB GITOPS REPOSITORY                           │
│              https://github.com/cosmicsatish/grafana-admin-platform         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Argo CD Automated Sync)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ARGO CD / KUBERNETES CLUSTER                          │
│          Applies Native Custom Resources via Grafana Operator v5.24.0       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Grafana Instance API)
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GRAFANA CLOUD INSTANCE                              │
│                    https://cosmicsatish.grafana.net                         │
│   - Osttra Root Folder with 41 Nested Child Folders                         │
│   - Dedicated Team Ownership (Permission: 4 / Admin)                        │
│   - Teams Synchronized with Azure AD Group Object IDs                       │
│   - Fine-Grained Fixed RBAC Roles Assigned to Teams & Service Accounts      │
│   - Scoped Loki LBAC Stream Selectors                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Resource Specifications

### 2.1 Folder Hierarchy & Ownership (`chart/values/GrafanaFolder.yaml`)
- **Root Parent Folder**: All team and product folders are organized under the root parent folder **`Osttra`** (`uid: "osttra"`).
- **Nested Child Folders**: All 41 folders (`SRE`, `DBS Leads`, `ElasticSearch`, `TOC`, `Admins`, `fortimail`, `tri*`, `traiana-*`, etc.) declare `parentUid: "osttra"`.
- **Team Admin Ownership**: Each folder grants its designated team **`permission: 4` (Admin / Owner)** and Viewer access to the org.

### 2.2 Teams & Azure AD Group Sync (`chart/values/Team.yaml`)
- **Declarative Teams**: 39+ teams configured with slugs, display names, and contact emails.
- **Azure AD Sync**: Integrated with Azure AD (Entra ID) Object GUIDs via `syncGroups` for automatic user group mapping.
- **Official Fixed Roles**: Teams receive strictly official fine-grained fixed roles (e.g. `fixed:alerting:admin`, `fixed:dashboards:reader`, `fixed:datasources:explorer`, `plugins:k6-app:editor`).

### 2.3 Service Accounts (`chart/values/GrafanaServiceAccount.yaml`)
- **Least Privilege Base Role**: All service accounts declare `role: None` to prevent implicit broad org access.
- **Fixed Role Scopes**: Granular access assigned via explicit `fixedRoles` (e.g. `fixed:folders.permissions:writer`, `fixed:dashboards:writer`, `fixed:alerting:writer`).
- **Automated Token Generation**: Creates Secret-backed API tokens managed in Kubernetes.

### 2.4 Loki Log-Based Access Control (`chart/values/TeamLBACRule.yaml`)
- **Stream Selectors**: Maps 26+ teams to log stream label filter expressions on datasource `loki-lbac` (e.g. `{ business_unit!="reset", business_unit!="trioptima" }`, `{ cluster="observability-prod" }`).

### 2.5 Resource Permissions (`chart/values/ResourcePermission.yaml`)
- **Datasource Permissions**: Scoped query permissions restricted exclusively to the `loki-lbac` datasource.

---

## 3. Directory Layout

```text
.
├── chart/                              # Pure declarative Helm Chart (0 custom scripts)
│   ├── Chart.yaml                      # Chart metadata
│   ├── values.yaml                     # Global instance connection settings
│   ├── values/                         # Modular values named by official Kind
│   │   ├── Team.yaml                   # 39+ teams, Azure AD Object IDs, and roles
│   │   ├── GrafanaFolder.yaml          # Osttra root + 41 nested folders with team ownership
│   │   ├── TeamLBACRule.yaml           # 26+ Loki LBAC log stream selectors
│   │   ├── GrafanaServiceAccount.yaml  # Service accounts with role None & fixedRoles
│   │   └── ResourcePermission.yaml     # Scoped loki-lbac permissions
│   └── templates/                      # Pure native templates
│       ├── _helpers.tpl
│       ├── Grafana.yaml                # External Grafana instance CR
│       ├── GrafanaFolder.yaml          # GrafanaFolder CRs (with parentFolderUID)
│       ├── GrafanaServiceAccount.yaml  # GrafanaServiceAccount CRs
│       ├── Team.yaml                   # GrafanaManifest Team CRs
│       ├── TeamLBACRule.yaml           # GrafanaManifest TeamLBACRule CRs
│       └── ResourcePermission.yaml     # GrafanaManifest ResourcePermission CRs
├── deploy/
│   ├── install.sh                      # One-click local bootstrap script (Kind + Argo CD)
│   ├── operator-values.yaml            # Grafana Operator Helm configuration
│   └── argocd/
│       └── application.yaml            # Argo CD Application manifest
├── .github/
│   └── workflows/
│       ├── validate.yaml               # PR lint and template dry-run
│       └── deploy.yaml                 # GitOps deployment pipeline
├── Makefile                            # make validate, make render, make install
└── README.md                           # Master platform documentation
```

---

## 4. Local Testing & Bootstrap Guide

### 4.1 Prerequisites
- [Docker](https://www.docker.com/)
- [Kind](https://kind.sigs.k8s.io/) (`brew install kind`)
- [Helm](https://helm.sh/) (`brew install helm`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (`brew install kubectl`)

### 4.2 Bootstrap Local Kind Cluster & Argo CD
```bash
./deploy/install.sh
```
This script automatically:
1. Provisions a local Kind cluster named `grafana-admin-gitops`.
2. Installs Argo CD and Grafana Operator `v5.24.0`.
3. Creates the `grafana-admin-token` Secret from your Grafana Cloud token.
4. Deploys the Argo CD Application tracking this repository.

### 4.3 Access Argo CD Dashboard
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- **URL**: [https://localhost:8080](https://localhost:8080)
- **Username**: `admin`
- **Password**: `3OAZNkNMS9vj7D57` (or fetch via `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`)

### 4.4 Local Validation & Rendering
```bash
# Validate YAML syntax and lint Helm chart against all values files:
make validate

# Render final Kubernetes manifests to stdout:
make render
```

### 4.5 Teardown Local Cluster
```bash
kind delete cluster --name grafana-admin-gitops
```

---

## 5. Grafana Cloud & Operator Integration Mechanics

### 5.1 Native Resources vs App Platform
- **`GrafanaFolder`** and **`GrafanaServiceAccount`** are fully supported by native operator controllers.
- The `GrafanaFolder` CR supports nested hierarchies using `spec.parentFolderUID: "osttra"`.

### 5.2 Loki LBAC Architecture in Grafana Cloud
In Grafana Cloud, Log-Based Access Control can be enforced via two models:
1. **Cloud Access Policies (CAPs)**: Configured in the Grafana Cloud Portal with label selectors on tokens (`logs-prod-*.grafana.net`). Each team uses a dedicated `GrafanaDatasource` pointing to Loki with their specific token.
2. **In-Instance Shared Datasource**: Dynamic header injection on a single shared `loki-lbac` datasource mapped to team memberships.
