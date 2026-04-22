{{/*
============================================================
Release Fullname: {oemId}-{userId}
============================================================
*/}}
{{- define "sim.fullname" -}}
{{- printf "%s-%s" .Values.oemId .Values.userId | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
============================================================
FQDN: {userId}.{oemId}.{baseDomain}
============================================================
*/}}
{{- define "sim.fqdn" -}}
{{- printf "%s.%s.%s" .Values.userId .Values.oemId .Values.ingress.baseDomain -}}
{{- end }}

{{/*
============================================================
ALB Group Name: ajt-{oemId}
============================================================
*/}}
{{- define "sim.albGroupName" -}}
{{- printf "ajt-%s" .Values.oemId -}}
{{- end }}

{{/*
============================================================
Chart Label
============================================================
*/}}
{{- define "sim.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
============================================================
Common Labels
============================================================
*/}}
{{- define "sim.labels" -}}
helm.sh/chart: {{ include "sim.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
simulator-platform/oem: {{ .Values.oemId }}
simulator-platform/user: {{ .Values.userId }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
============================================================
Component Labels (call with dict "ctx" . "component" "xxx")
============================================================
*/}}
{{- define "sim.componentLabels" -}}
{{ include "sim.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "sim.componentSelector" -}}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
simulator-platform/oem: {{ .ctx.Values.oemId }}
simulator-platform/user: {{ .ctx.Values.userId }}
{{- end }}

{{/*
============================================================
Image URL: {registry}/{repository}:{tag}
============================================================
*/}}
{{- define "sim.image" -}}
{{- printf "%s/%s:%s" .registry .repository .tag -}}
{{- end }}

{{/*
============================================================
Service Account Name
============================================================
*/}}
{{- define "sim.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sim.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
============================================================
Hybrid Node nodeSelector / tolerations
============================================================
*/}}
{{- define "sim.nodeSelector" -}}
{{- if .Values.hybridNode.enabled }}
nodeSelector:
  {{- toYaml .Values.hybridNode.nodeSelector | nindent 2 }}
{{- end }}
{{- end }}

{{- define "sim.tolerations" -}}
{{- if .Values.hybridNode.enabled }}
tolerations:
  {{- toYaml .Values.hybridNode.tolerations | nindent 2 }}
{{- end }}
{{- end }}
