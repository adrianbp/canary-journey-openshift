{{- define "canary-addon.labels" -}}
app.kubernetes.io/name: {{ .Values.app.name | quote }}
app.kubernetes.io/managed-by: "Helm"
{{- range $k, $v := .Values.app.labels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}
