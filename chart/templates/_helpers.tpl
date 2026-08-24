{{/*
Common metadata labels applied to all resources
*/}}
{{- define "grafana-admin-platform.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
dashboards: {{ .Values.grafana.matchLabels.dashboards | default "osttra" }}
{{- end }}

{{/*
Standard Grafana Instance Selector for all child CRs
*/}}
{{- define "grafana-admin-platform.instanceSelector" -}}
instanceSelector:
  matchLabels:
    dashboards: {{ .Values.grafana.matchLabels.dashboards | default "osttra" }}
{{- end }}
