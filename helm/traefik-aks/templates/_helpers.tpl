{{/*
Expand the name of the chart.
*/}}
{{- define "traefik-aks.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "traefik-aks.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "traefik-aks.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "traefik-aks.labels" -}}
helm.sh/chart: {{ include "traefik-aks.chart" . }}
{{ include "traefik-aks.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "traefik-aks.selectorLabels" -}}
app.kubernetes.io/name: {{ include "traefik-aks.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "traefik-aks.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "traefik-aks.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate basic auth string for dashboard
*/}}
{{- define "traefik-aks.dashboardAuth" -}}
{{- if .Values.traefik.dashboard.auth.basic.enabled }}
{{- $username := .Values.traefik.dashboard.auth.basic.username }}
{{- $password := .Values.traefik.dashboard.auth.basic.password }}
{{- printf "%s:%s" $username (htpasswd $password) | b64enc }}
{{- end }}
{{- end }}

{{/*
Generate domain name for dashboard
*/}}
{{- define "traefik-aks.dashboardDomain" -}}
{{- if .Values.traefik.dashboard.domain }}
{{- tpl .Values.traefik.dashboard.domain . }}
{{- else }}
{{- printf "traefik.%s" .Values.global.domainSuffix }}
{{- end }}
{{- end }}
