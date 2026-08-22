{{/*
Common labels
*/}}
{{- define "grafana-admin-platform.labels" -}}
grafana-admin-platform: managed
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
