{{/*
Common labels
*/}}
{{- define "grafana-admin-platform.labels" -}}
grafana-admin-platform: managed
dashboards: {{ .Values.grafana.instanceSelectorValue | default "osttra" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
