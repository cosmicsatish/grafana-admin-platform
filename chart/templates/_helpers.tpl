{{/*
Common labels
*/}}
{{- define "grafana-admin-platform.labels" -}}
grafana-admin-platform: managed
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Grafana Instance Selector MatchLabels
*/}}
{{- define "grafana-admin-platform.matchLabels" -}}
{{- if .Values.grafana.matchLabels }}
{{- toYaml .Values.grafana.matchLabels }}
{{- else }}
dashboards: "osttra"
{{- end }}
{{- end }}
