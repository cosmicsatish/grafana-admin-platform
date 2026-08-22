# Grafana Administration Platform

Production-oriented, GitOps-friendly Grafana administration using clean, human-readable values files rendered via a **native Helm chart** and reconciled by the **official Grafana Operator**.

---

## 1. Design Principles

- **Pure GitOps**: Git is the desired state; Kubernetes + the official Grafana Operator reconcile it.
- **Zero Custom Scripts**: Standard, cloud-native Helm templating (`helm template` / `helm upgrade`) renders all Kubernetes manifests natively.
- **Concise Values-Based Management**: Maintain clean 5-line declarative YAML entries per resource instead of writing verbose 30-line Kubernetes manifests.
- **Official Kind Naming**: Templates and modular values files are named after their official CRD Kind names (`GrafanaFolder.yaml`, `GrafanaServiceAccount.yaml`, `Team.yaml`, `TeamLBACRule.yaml`, `ResourcePermission.yaml`, `Grafana.yaml`) for clarity.
- **Folder Permissions**: Managed declaratively through `chart/values/GrafanaFolder.yaml` supporting Roles, Teams, and Service Accounts.
- **Teams & Azure AD Group Sync**: Managed declaratively in `chart/values/Team.yaml` with Azure AD (Entra ID) Group Object UIDs (`syncGroups`).
- **Fixed Team Roles & RBAC**: Managed via role lists in `chart/values/Team.yaml` (`fixed:alerting:admin`, `fixed:dashboards:reader`, etc.).
- **Datasource Permissions & LBAC**: Scoped log query stream selectors on `loki-lbac` defined in `chart/values/TeamLBACRule.yaml`.
- **Service Accounts & Token Secrets**: Managed in `chart/values/GrafanaServiceAccount.yaml` with automatic token secrets.
- **Secret Safety**: Secrets never belong in Git. Tokens are securely stored in Kubernetes Secrets or external secret stores.

---

## 2. Architecture & Domain Mapping

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                             HUMAN-MAINTAINED VALUES                         │
│   chart/values/Team.yaml                 chart/values/GrafanaFolder.yaml    │
│   chart/values/TeamLBACRule.yaml         chart/values/GrafanaServiceAccount │
│   chart/values/ResourcePermission.yaml   chart/values.yaml                  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Native Helm Engine: helm template)
┌─────────────────────────────────────────────────────────────────────────────┐
│                          OFFICIAL KUBERNETES MANIFESTS                      │
│   GrafanaFolder                      GrafanaServiceAccount                  │
│   GrafanaManifest (Team)             GrafanaManifest (TeamLBACRule)         │
│   GrafanaManifest (ResourcePerm)     Grafana (External Instance)            │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼ (Reconciliation)
┌─────────────────────────────────────────────────────────────────────────────┐
│                           OFFICIAL GRAFANA OPERATOR                         │
│                    Reconciles Live State in Grafana Cloud                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Repository Structure

```text
.
├── chart/                              # Official Helm Chart (zero custom scripts)
│   ├── Chart.yaml                      # Chart metadata
│   ├── values.yaml                     # Consolidated values & Grafana connection settings
│   ├── values/                         # Modular values files named by official Kind
│   │   ├── Team.yaml                   # 28+ teams, Azure AD Object IDs, and roles
│   │   ├── GrafanaFolder.yaml          # 30+ team & product folders with permissions
│   │   ├── TeamLBACRule.yaml           # 26+ Loki LBAC log stream selectors
│   │   ├── GrafanaServiceAccount.yaml  # 19 managed & personal service accounts
│   │   └── ResourcePermission.yaml     # Datasource query/admin permissions
│   └── templates/                      # Helm templates named by official Kind
│       ├── _helpers.tpl
│       ├── Grafana.yaml                # External Grafana instance CR
│       ├── Team.yaml                   # Generates GrafanaManifest (iam.grafana.app/v0alpha1 Team)
│       ├── GrafanaFolder.yaml          # Generates GrafanaFolder
│       ├── TeamLBACRule.yaml           # Generates GrafanaManifest (iam.grafana.app/v0alpha1 TeamLBACRule)
│       ├── GrafanaServiceAccount.yaml  # Generates GrafanaServiceAccount
│       └── ResourcePermission.yaml     # Generates GrafanaManifest (iam.grafana.app/v0alpha1 ResourcePermission)
├── deploy/
│   ├── install.sh                      # Bootstrap script
│   ├── operator-values.yaml            # Grafana Operator Helm values (pinned v5.24.0)
│   └── argocd/
│       └── application.yaml            # Argo CD Application manifest
├── .github/
│   └── workflows/
│       ├── validate.yaml               # PR validation (Helm lint, schema dry-run)
│       └── deploy.yaml                 # Merge-to-main deployment
├── Makefile                            # Automation commands (make validate, make render)
└── README.md                           # Master platform documentation
```

---

## 4. How the Grafana Team Manages Resources

All changes are managed by editing clean values in `chart/values/` and opening a Pull Request:

### A. Teams & Azure AD Group Sync (`chart/values/Team.yaml`)
```yaml
teams:
  - name: SRE
    slug: sre
    syncGroups:
      - "a77663ba-4475-4750-84a1-030a5f8ee0aa" # APP-GrafanaCloud-SRE (Azure AD Object ID)
    roles:
      - fixed:alerting:admin
      - fixed:dashboards:reader
      - fixed:datasources:explorer
```

### B. Folders & Permissions (`chart/values/GrafanaFolder.yaml`)
```yaml
folders:
  - title: "SRE"
    uid: "folder-sre"
    owner: "sre"
    permissions:
      - role: "Viewer"
        permission: 1
      - team: "sre"
        permission: 2
```
*Permissions: `1` = View, `2` = Edit, `4` = Admin.*

### C. Loki LBAC Rules (`chart/values/TeamLBACRule.yaml`)
```yaml
lbacRules:
  - name: sre
    team: sre
    datasource: loki-lbac
    selector: '{ business_unit!="reset", business_unit!="trioptima", business_unit!="osttra" }'
```

### D. Service Accounts (`chart/values/GrafanaServiceAccount.yaml`)
```yaml
serviceAccounts:
  - name: config-reconciler
    role: Editor
    secretName: config-reconciler-token
```

### E. Datasource Permissions (`chart/values/ResourcePermission.yaml`)
```yaml
datasourcePermissions:
  - name: datasource-permissions-loki-lbac
    manifestName: loki-lbac-access
    datasource: loki-lbac
    assignments:
      - team: sre
        permission: Query
      - team: admins
        permission: Admin
      - serviceAccount: platform-automation
        permission: Query
```

---

## 5. Local Commands & Validation

### Validate All Manifests & Chart
```bash
make validate
```
This runs:
1. Python YAML syntax validation.
2. `helm lint chart/` to ensure chart integrity.
3. `helm template grafana-admin chart/` dry-run.

### Render All Kubernetes Manifests
```bash
make render
```

### Bootstrap / Install
```bash
./deploy/install.sh
```

---

## 6. GitOps Deployment

### Argo CD Setup
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana-admin-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR-ORG/grafana-admin-platform.git
    targetRevision: main
    path: chart
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: grafana-admin
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
