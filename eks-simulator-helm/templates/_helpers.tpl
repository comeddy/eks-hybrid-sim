{{/*
============================================================
Chart Name & Full Name
============================================================
*/}}
{{- define "simulator-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "simulator-platform.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Values.oemId .Values.userId | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
============================================================
Chart Labels
============================================================
*/}}
{{- define "simulator-platform.labels" -}}
helm.sh/chart: {{ include "simulator-platform.chart" . }}
{{ include "simulator-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
simulator-platform/oem: {{ .Values.oemId }}
simulator-platform/user: {{ .Values.userId }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "simulator-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "simulator-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "simulator-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
============================================================
Component-specific Labels
============================================================
*/}}
{{- define "simulator-platform.componentLabels" -}}
{{ include "simulator-platform.labels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "simulator-platform.componentSelectorLabels" -}}
{{ include "simulator-platform.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
simulator-platform/oem: {{ .Values.oemId }}
simulator-platform/user: {{ .Values.userId }}
{{- end }}

{{/*
============================================================
Service Account Name
============================================================
*/}}
{{- define "simulator-platform.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "simulator-platform.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
============================================================
Image URL Helper
============================================================
*/}}
{{- define "simulator-platform.image" -}}
{{- $registry := .root.Values.imageRegistry -}}
{{- $repository := .image.repository -}}
{{- $tag := .image.tag | default "latest" -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- end }}

{{/*
============================================================
FQDN (Fully Qualified Domain Name)
user-a.hyundai.example.com 형식
============================================================
*/}}
{{- define "simulator-platform.fqdn" -}}
{{- printf "%s.%s.%s" .Values.userId .Values.oemId .Values.ingress.baseDomain -}}
{{- end }}

{{/*
============================================================
ALB Group Name (OEM별 공유)
============================================================
*/}}
{{- define "simulator-platform.albGroupName" -}}
{{- printf "ajt-%s" .Values.oemId -}}
{{- end }}

{{/*
============================================================
Hybrid Node Scheduling
============================================================
*/}}
{{- define "simulator-platform.nodeSelector" -}}
{{- if .Values.hybridNode.enabled }}
{{ toYaml .Values.hybridNode.nodeSelector }}
{{- end }}
{{- end }}

{{- define "simulator-platform.tolerations" -}}
{{- if .Values.hybridNode.enabled }}
{{ toYaml .Values.hybridNode.tolerations }}
{{- end }}
{{- end }}

{{/*
============================================================
Pod Security Context
============================================================
*/}}
{{- define "simulator-platform.podSecurityContext" -}}
{{- with .Values.podSecurityContext }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "simulator-platform.containerSecurityContext" -}}
{{- with .Values.containerSecurityContext }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
============================================================
Component Service Name
============================================================
*/}}
{{- define "simulator-platform.serviceName" -}}
{{- printf "%s-%s-%s" .Values.oemId .Values.userId .component -}}
{{- end }}

{{/*
============================================================
Nginx Upstream Name (Service DNS)
============================================================
*/}}
{{- define "simulator-platform.upstreamName" -}}
{{- printf "%s-%s-%s.%s.svc.cluster.local" .Values.oemId .Values.userId .component .Release.Namespace -}}
{{- end }}
