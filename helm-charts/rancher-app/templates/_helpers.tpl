{{/*
Expand the name of the chart.
*/}}
{{- define "rancher-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "rancher-app.fullname" -}}
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
{{- define "rancher-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rancher-app.labels" -}}
helm.sh/chart: {{ include "rancher-app.chart" . }}
{{ include "rancher-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rancher-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rancher-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "rancher-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "rancher-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a default image name
*/}}
{{- define "rancher-app.image" -}}
{{- if .Values.global.imageRegistry }}
{{- printf "%s/%s:%s" .Values.global.imageRegistry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "rancher-app.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create the database URL
*/}}
{{- define "rancher-app.databaseUrl" -}}
{{- if .Values.database.enabled }}
{{- if eq .Values.database.type "postgresql" }}
{{- printf "postgresql://%s:%s@%s:%d/%s" .Values.database.username .Values.database.password .Values.database.host (.Values.database.port | int) .Values.database.name }}
{{- else if eq .Values.database.type "mysql" }}
{{- printf "mysql://%s:%s@%s:%d/%s" .Values.database.username .Values.database.password .Values.database.host (.Values.database.port | int) .Values.database.name }}
{{- end }}
{{- else }}
{{- "sqlite:///app/data/app.db" }}
{{- end }}
{{- end }}

{{/*
Create Redis URL
*/}}
{{- define "rancher-app.redisUrl" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.password }}
{{- printf "redis://:%s@%s:%d/%d" .Values.redis.password .Values.redis.host (.Values.redis.port | int) (.Values.redis.database | int) }}
{{- else }}
{{- printf "redis://%s:%d/%d" .Values.redis.host (.Values.redis.port | int) (.Values.redis.database | int) }}
{{- end }}
{{- else }}
{{- "redis://redis:6379/0" }}
{{- end }}
{{- end }}

{{/*
Create pod security context
*/}}
{{- define "rancher-app.podSecurityContext" -}}
{{- if .Values.podSecurityContext }}
{{- toYaml .Values.podSecurityContext }}
{{- end }}
{{- end }}

{{/*
Create container security context
*/}}
{{- define "rancher-app.securityContext" -}}
{{- if .Values.securityContext }}
{{- toYaml .Values.securityContext }}
{{- end }}
{{- end }}

{{/*
Create resource limits and requests
*/}}
{{- define "rancher-app.resources" -}}
{{- if .Values.resources }}
{{- toYaml .Values.resources }}
{{- end }}
{{- end }}

{{/*
Create node selector
*/}}
{{- define "rancher-app.nodeSelector" -}}
{{- if .Values.nodeSelector }}
{{- toYaml .Values.nodeSelector }}
{{- end }}
{{- end }}

{{/*
Create affinity
*/}}
{{- define "rancher-app.affinity" -}}
{{- if .Values.affinity }}
{{- toYaml .Values.affinity }}
{{- end }}
{{- end }}

{{/*
Create tolerations
*/}}
{{- define "rancher-app.tolerations" -}}
{{- if .Values.tolerations }}
{{- toYaml .Values.tolerations }}
{{- end }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "rancher-app.validateValues" -}}
{{- if and .Values.database.enabled (not .Values.database.host) }}
{{- fail "database.host is required when database.enabled is true" }}
{{- end }}
{{- if and .Values.redis.enabled (not .Values.redis.host) }}
{{- fail "redis.host is required when redis.enabled is true" }}
{{- end }}
{{- end }}
